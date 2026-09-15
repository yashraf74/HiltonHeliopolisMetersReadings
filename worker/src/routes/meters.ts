import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

const METER_TYPES = ["electricity", "water", "gas"] as const;
const MAX_TEXT_LENGTH = 80;

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Error && /UNIQUE constraint failed/i.test(err.message);
}
const DUPLICATE_METER = "A meter with the same name, floor, number and area already exists";

const METER_COLUMNS =
  "m.id, m.name, m.type, m.location, m.area, m.number, m.floor_number, m.description, m.is_active, m.photo_key, m.created_by, m.created_at, m.updated_at";

export const meterRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

meterRoutes.use("*", requireAuth);

// Every role reads meters (the reading flow needs them). `last_logged_at`
// lets the app show which meters already have a reading today.
meterRoutes.get("/", async (c) => {
  const isModerator = c.get("user").role === "moderator";
  const includeInactive = c.req.query("includeInactive") === "1" && isModerator;
  const where = includeInactive ? "" : "WHERE m.is_active = 1";
  const { results } = await c.env.DB.prepare(
    `SELECT ${METER_COLUMNS}, l.last_logged_at
     FROM meters m
     LEFT JOIN (SELECT meter_id, MAX(logged_at) AS last_logged_at FROM readings GROUP BY meter_id) l
       ON l.meter_id = m.id
     ${where}
     ORDER BY m.floor_number, m.name COLLATE NOCASE`
  ).all();
  return c.json({ meters: results });
});

function text(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

meterRoutes.post("/", requireRole("moderator"), async (c) => {
  const body = await c.req.json().catch(() => null);
  const type = body?.type;
  const name = text(body?.name);
  const area = text(body?.area);
  const number = text(body?.number) || null;
  const location = text(body?.location);
  const floorNumber = body?.floorNumber;
  const description = typeof body?.description === "string" ? body.description : null;
  const photoKey = typeof body?.photoKey === "string" && body.photoKey.startsWith("meters/") ? body.photoKey : null;

  if (!METER_TYPES.includes(type)) {
    return c.json({ error: "type must be one of: electricity, water, gas" }, 400);
  }
  if (!name || name.length > MAX_TEXT_LENGTH) return c.json({ error: "name is required (max 80 chars)" }, 400);
  if (!area || area.length > MAX_TEXT_LENGTH) return c.json({ error: "area is required (max 80 chars)" }, 400);
  if (number && number.length > MAX_TEXT_LENGTH) return c.json({ error: "number is too long (max 80 chars)" }, 400);
  if (!location) return c.json({ error: "location is required" }, 400);
  if (!Number.isInteger(floorNumber)) return c.json({ error: "floorNumber must be an integer" }, 400);

  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  try {
    await c.env.DB.prepare(
      `INSERT INTO meters (id, name, type, location, area, number, floor_number, description, photo_key, is_active, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)`
    )
      .bind(id, name, type, location, area, number, floorNumber, description, photoKey, c.get("user").id, now, now)
      .run();
  } catch (err) {
    if (isUniqueViolation(err)) return c.json({ error: DUPLICATE_METER }, 409);
    throw err;
  }

  return c.json({ id }, 201);
});

meterRoutes.put("/:id", requireRole("moderator"), async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);

  const existing = await c.env.DB.prepare("SELECT id FROM meters WHERE id = ?").bind(id).first();
  if (!existing) return c.json({ error: "Meter not found" }, 404);

  const type = body?.type ?? null;
  if (type !== null && !METER_TYPES.includes(type)) {
    return c.json({ error: "type must be one of: electricity, water, gas" }, 400);
  }
  const name = typeof body?.name === "string" ? text(body.name) : null;
  if (name !== null && (!name || name.length > MAX_TEXT_LENGTH)) {
    return c.json({ error: "name is required (max 80 chars)" }, 400);
  }
  const area = typeof body?.area === "string" ? text(body.area) : null;
  if (area !== null && (!area || area.length > MAX_TEXT_LENGTH)) {
    return c.json({ error: "area is required (max 80 chars)" }, 400);
  }
  // number: string sets (empty clears), absent leaves unchanged.
  const hasNumber = body !== null && typeof body.number === "string";
  const number = hasNumber ? text(body.number) || null : null;
  if (number && number.length > MAX_TEXT_LENGTH) return c.json({ error: "number is too long (max 80 chars)" }, 400);
  const location = typeof body?.location === "string" ? text(body.location) : null;
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
         area = COALESCE(?, area),
         number = CASE WHEN ? THEN ? ELSE number END,
         location = COALESCE(?, location),
         floor_number = COALESCE(?, floor_number),
         description = COALESCE(?, description),
         photo_key = CASE WHEN ? THEN ? ELSE photo_key END,
         updated_at = ?
       WHERE id = ?`
    )
      .bind(type, name, area, hasNumber ? 1 : 0, number, location, floorNumber, description, hasPhotoKey ? 1 : 0, photoKey, now, id)
      .run();
  } catch (err) {
    if (isUniqueViolation(err)) return c.json({ error: DUPLICATE_METER }, 409);
    throw err;
  }

  return c.json({ ok: true });
});

meterRoutes.delete("/:id", requireRole("moderator"), async (c) => {
  const id = c.req.param("id");
  const now = new Date().toISOString();
  const result = await c.env.DB.prepare("UPDATE meters SET is_active = 0, updated_at = ? WHERE id = ?")
    .bind(now, id)
    .run();

  if (!result.meta.changes) return c.json({ error: "Meter not found" }, 404);
  return c.json({ ok: true });
});
