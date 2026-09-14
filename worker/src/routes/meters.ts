import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

const METER_TYPES = ["electricity", "water", "gas"] as const;
const MAX_NAME_LENGTH = 80;

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Error && /UNIQUE constraint failed/i.test(err.message);
}
const NAME_TAKEN = "A meter with this name already exists on this floor";

export const meterRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

meterRoutes.use("*", requireAuth);

meterRoutes.get("/", async (c) => {
  const isEngineer = c.get("user").role === "engineer";
  const includeInactive = c.req.query("includeInactive") === "1" && isEngineer;
  // The meter photo is shown as the thumbnail in the meter picker for every
  // role; only uploading/replacing it is engineer-only.
  const columns =
    "id, name, type, location, floor_number, description, is_active, photo_key, created_by, created_at, updated_at";
  const query = includeInactive
    ? `SELECT ${columns} FROM meters ORDER BY floor_number, name COLLATE NOCASE`
    : `SELECT ${columns} FROM meters WHERE is_active = 1 ORDER BY floor_number, name COLLATE NOCASE`;
  const { results } = await c.env.DB.prepare(query).all();
  return c.json({ meters: results });
});

meterRoutes.post("/", requireRole("engineer"), async (c) => {
  const body = await c.req.json().catch(() => null);
  const type = body?.type;
  const name = typeof body?.name === "string" ? body.name.trim() : "";
  const location = typeof body?.location === "string" ? body.location.trim() : "";
  const floorNumber = body?.floorNumber;
  const description = typeof body?.description === "string" ? body.description : null;
  const photoKey = typeof body?.photoKey === "string" && body.photoKey.startsWith("meters/") ? body.photoKey : null;

  if (!METER_TYPES.includes(type)) {
    return c.json({ error: "type must be one of: electricity, water, gas" }, 400);
  }
  if (!name || name.length > MAX_NAME_LENGTH) return c.json({ error: "name is required (max 80 chars)" }, 400);
  if (!location) return c.json({ error: "location is required" }, 400);
  if (!Number.isInteger(floorNumber)) return c.json({ error: "floorNumber must be an integer" }, 400);

  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  try {
    await c.env.DB.prepare(
      `INSERT INTO meters (id, name, type, location, floor_number, description, photo_key, is_active, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)`
    )
      .bind(id, name, type, location, floorNumber, description, photoKey, c.get("user").id, now, now)
      .run();
  } catch (err) {
    if (isUniqueViolation(err)) return c.json({ error: NAME_TAKEN }, 409);
    throw err;
  }

  return c.json({ id }, 201);
});

meterRoutes.put("/:id", requireRole("engineer"), async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);

  const existing = await c.env.DB.prepare("SELECT id FROM meters WHERE id = ?").bind(id).first();
  if (!existing) return c.json({ error: "Meter not found" }, 404);

  const type = body?.type ?? null;
  if (type !== null && !METER_TYPES.includes(type)) {
    return c.json({ error: "type must be one of: electricity, water, gas" }, 400);
  }
  const name = typeof body?.name === "string" ? body.name.trim() : null;
  if (name !== null && (!name || name.length > MAX_NAME_LENGTH)) {
    return c.json({ error: "name is required (max 80 chars)" }, 400);
  }
  const location = typeof body?.location === "string" ? body.location.trim() : null;
  const floorNumber = Number.isInteger(body?.floorNumber) ? body.floorNumber : null;
  const description = typeof body?.description === "string" ? body.description : null;
  // photoKey: string sets, null clears, absent leaves unchanged.
  const hasPhotoKey = body !== null && Object.prototype.hasOwnProperty.call(body, "photoKey");
  const photoKey = hasPhotoKey && typeof body.photoKey === "string" && body.photoKey.startsWith("meters/") ? body.photoKey : null;
  const now = new Date().toISOString();

  try {
    await c.env.DB.prepare(
    `UPDATE meters SET
       type = COALESCE(?, type),
       name = COALESCE(?, name),
       location = COALESCE(?, location),
       floor_number = COALESCE(?, floor_number),
       description = COALESCE(?, description),
       photo_key = CASE WHEN ? THEN ? ELSE photo_key END,
       updated_at = ?
     WHERE id = ?`
  )
    .bind(type, name, location, floorNumber, description, hasPhotoKey ? 1 : 0, photoKey, now, id)
    .run();
  } catch (err) {
    if (isUniqueViolation(err)) return c.json({ error: NAME_TAKEN }, 409);
    throw err;
  }

  return c.json({ ok: true });
});

meterRoutes.delete("/:id", requireRole("engineer"), async (c) => {
  const id = c.req.param("id");
  const now = new Date().toISOString();
  const result = await c.env.DB.prepare("UPDATE meters SET is_active = 0, updated_at = ? WHERE id = ?")
    .bind(now, id)
    .run();

  if (!result.meta.changes) return c.json({ error: "Meter not found" }, 404);
  return c.json({ ok: true });
});
