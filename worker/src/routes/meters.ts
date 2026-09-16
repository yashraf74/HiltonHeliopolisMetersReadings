import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

const METER_TYPES = ["electricity", "water", "gas"] as const;
const MAX_TEXT_LENGTH = 80;

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Error && /UNIQUE constraint failed/i.test(err.message);
}
const DUPLICATE_METER = "A meter with the same name, number and area already exists";

const METER_COLUMNS =
  "m.id, m.name, m.type, m.location, m.area, m.number, m.description, m.is_active, m.photo_key, m.todo_order, m.export_order, m.created_by, m.created_at, m.updated_at";

export const meterRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

meterRoutes.use("*", requireAuth);

// Every role reads meters (the reading flow needs them). `last_logged_at`
// lets the app show which meters already have a reading today. Order is
// the to-do order (unset last), then name.
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
     ORDER BY m.todo_order IS NULL, m.todo_order, m.name COLLATE NOCASE`
  ).all();
  return c.json({ meters: results });
});

function text(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

/** null = absent, or a non-negative integer; NaN signals an invalid value. */
function order(v: unknown): number | null {
  if (v === undefined || v === null || v === "") return null;
  return Number.isInteger(v) && (v as number) >= 0 ? (v as number) : NaN;
}

meterRoutes.post("/", requireRole("moderator"), async (c) => {
  const body = await c.req.json().catch(() => null);
  const type = body?.type;
  const name = text(body?.name);
  const area = text(body?.area);
  const number = text(body?.number) || null;
  const location = text(body?.location);
  const description = typeof body?.description === "string" ? body.description : null;
  const photoKey = typeof body?.photoKey === "string" && body.photoKey.startsWith("meters/") ? body.photoKey : null;
  const todoOrder = order(body?.todoOrder);
  const exportOrder = order(body?.exportOrder);

  if (!METER_TYPES.includes(type)) {
    return c.json({ error: "type must be one of: electricity, water, gas" }, 400);
  }
  if (!name || name.length > MAX_TEXT_LENGTH) return c.json({ error: "name is required (max 80 chars)" }, 400);
  if (!area || area.length > MAX_TEXT_LENGTH) return c.json({ error: "area is required (max 80 chars)" }, 400);
  if (number && number.length > MAX_TEXT_LENGTH) return c.json({ error: "number is too long (max 80 chars)" }, 400);
  if (!location) return c.json({ error: "location is required" }, 400);
  if (Number.isNaN(todoOrder) || Number.isNaN(exportOrder)) {
    return c.json({ error: "todoOrder and exportOrder must be non-negative integers" }, 400);
  }

  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  try {
    await c.env.DB.prepare(
      `INSERT INTO meters (id, name, type, location, area, number, description, photo_key, todo_order, export_order, is_active, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)`
    )
      .bind(id, name, type, location, area, number, description, photoKey, todoOrder, exportOrder, c.get("user").id, now, now)
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
  // number / todoOrder / exportOrder: present (possibly empty/null) sets or
  // clears, absent leaves unchanged.
  const has = (k: string) => body !== null && Object.prototype.hasOwnProperty.call(body, k);
  const number = has("number") ? text(body.number) || null : null;
  if (number && number.length > MAX_TEXT_LENGTH) return c.json({ error: "number is too long (max 80 chars)" }, 400);
  const todoOrder = has("todoOrder") ? order(body.todoOrder) : null;
  const exportOrder = has("exportOrder") ? order(body.exportOrder) : null;
  if (Number.isNaN(todoOrder) || Number.isNaN(exportOrder)) {
    return c.json({ error: "todoOrder and exportOrder must be non-negative integers" }, 400);
  }
  const location = typeof body?.location === "string" ? text(body.location) : null;
  const description = typeof body?.description === "string" ? body.description : null;
  const photoKey = has("photoKey") && typeof body.photoKey === "string" && body.photoKey.startsWith("meters/") ? body.photoKey : null;
  const now = new Date().toISOString();

  try {
    await c.env.DB.prepare(
      `UPDATE meters SET
         type = COALESCE(?, type),
         name = COALESCE(?, name),
         area = COALESCE(?, area),
         number = CASE WHEN ? THEN ? ELSE number END,
         location = COALESCE(?, location),
         description = COALESCE(?, description),
         photo_key = CASE WHEN ? THEN ? ELSE photo_key END,
         todo_order = CASE WHEN ? THEN ? ELSE todo_order END,
         export_order = CASE WHEN ? THEN ? ELSE export_order END,
         updated_at = ?
       WHERE id = ?`
    )
      .bind(
        type, name, area,
        has("number") ? 1 : 0, number,
        location, description,
        has("photoKey") ? 1 : 0, photoKey,
        has("todoOrder") ? 1 : 0, todoOrder,
        has("exportOrder") ? 1 : 0, exportOrder,
        now, id
      )
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
