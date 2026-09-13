import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

const METER_TYPES = ["electricity", "water", "gas"] as const;

export const meterRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

meterRoutes.use("*", requireAuth);

meterRoutes.get("/", async (c) => {
  const includeInactive = c.req.query("includeInactive") === "1" && c.get("user").role === "engineer";
  const query = includeInactive
    ? "SELECT * FROM meters ORDER BY floor_number, location"
    : "SELECT * FROM meters WHERE is_active = 1 ORDER BY floor_number, location";
  const { results } = await c.env.DB.prepare(query).all();
  return c.json({ meters: results });
});

meterRoutes.post("/", requireRole("engineer"), async (c) => {
  const body = await c.req.json().catch(() => null);
  const type = body?.type;
  const location = typeof body?.location === "string" ? body.location.trim() : "";
  const floorNumber = body?.floorNumber;
  const description = typeof body?.description === "string" ? body.description : null;

  if (!METER_TYPES.includes(type)) {
    return c.json({ error: "type must be one of: electricity, water, gas" }, 400);
  }
  if (!location) return c.json({ error: "location is required" }, 400);
  if (!Number.isInteger(floorNumber)) return c.json({ error: "floorNumber must be an integer" }, 400);

  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await c.env.DB.prepare(
    `INSERT INTO meters (id, type, location, floor_number, description, is_active, created_by, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)`
  )
    .bind(id, type, location, floorNumber, description, c.get("user").id, now, now)
    .run();

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
  const location = typeof body?.location === "string" ? body.location.trim() : null;
  const floorNumber = Number.isInteger(body?.floorNumber) ? body.floorNumber : null;
  const description = typeof body?.description === "string" ? body.description : null;
  const now = new Date().toISOString();

  await c.env.DB.prepare(
    `UPDATE meters SET
       type = COALESCE(?, type),
       location = COALESCE(?, location),
       floor_number = COALESCE(?, floor_number),
       description = COALESCE(?, description),
       updated_at = ?
     WHERE id = ?`
  )
    .bind(type, location, floorNumber, description, now, id)
    .run();

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
