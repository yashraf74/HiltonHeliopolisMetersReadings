import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

export const readingRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

readingRoutes.use("*", requireAuth);

// Idempotent by `id`, which the app generates on-device at the moment of
// logging — a retried sync for an already-received reading is a no-op, not a
// duplicate.
readingRoutes.post("/", async (c) => {
  const body = await c.req.json().catch(() => null);
  const id = body?.id;
  const meterId = body?.meterId;
  const value = body?.value;
  const photoKey = body?.photoKey;
  const loggedAt = body?.loggedAt;

  if (
    typeof id !== "string" ||
    typeof meterId !== "string" ||
    typeof value !== "number" ||
    typeof photoKey !== "string" ||
    typeof loggedAt !== "string"
  ) {
    return c.json({ error: "id, meterId, value, photoKey and loggedAt are required" }, 400);
  }

  const meter = await c.env.DB.prepare("SELECT id FROM meters WHERE id = ?").bind(meterId).first();
  if (!meter) return c.json({ error: "Unknown meterId" }, 400);

  const user = c.get("user");
  const now = new Date().toISOString();

  await c.env.DB.prepare(
    `INSERT INTO readings (id, meter_id, value, photo_key, logged_by, logged_by_name, logged_at, synced_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO NOTHING`
  )
    .bind(id, meterId, value, photoKey, user.id, user.fullName, loggedAt, now, now)
    .run();

  const row = await c.env.DB.prepare("SELECT synced_at FROM readings WHERE id = ?")
    .bind(id)
    .first<{ synced_at: string }>();

  return c.json({ id, syncedAt: row?.synced_at ?? now });
});

const DEFAULT_PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 200;

// Cursor = base64url("<logged_at>|<id>") of the last row of the previous
// page. Keyset pagination stays correct as new readings arrive, unlike
// OFFSET which would shift every page.
function encodeCursor(loggedAt: string, id: string): string {
  return btoa(`${loggedAt}|${id}`).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decodeCursor(cursor: string): { loggedAt: string; id: string } | null {
  try {
    const padded = cursor.replace(/-/g, "+").replace(/_/g, "/");
    const raw = atob(padded + "=".repeat((4 - (padded.length % 4)) % 4));
    const sep = raw.lastIndexOf("|");
    if (sep <= 0) return null;
    return { loggedAt: raw.slice(0, sep), id: raw.slice(sep + 1) };
  } catch {
    return null;
  }
}

readingRoutes.get("/", requireRole("engineer"), async (c) => {
  const type = c.req.query("type");
  const floor = c.req.query("floor");
  const technician = c.req.query("technician");
  const dateFrom = c.req.query("dateFrom");
  const dateTo = c.req.query("dateTo");
  const search = c.req.query("search");
  const cursor = c.req.query("cursor");
  const limitParam = Number(c.req.query("limit") ?? DEFAULT_PAGE_SIZE);
  const limit = Number.isInteger(limitParam) ? Math.min(Math.max(limitParam, 1), MAX_PAGE_SIZE) : DEFAULT_PAGE_SIZE;

  const conditions: string[] = [];
  const params: unknown[] = [];

  if (type) {
    conditions.push("m.type = ?");
    params.push(type);
  }
  if (floor) {
    conditions.push("m.floor_number = ?");
    params.push(Number(floor));
  }
  if (technician) {
    conditions.push("r.logged_by_name LIKE ?");
    params.push(`%${technician}%`);
  }
  if (dateFrom) {
    conditions.push("r.logged_at >= ?");
    params.push(dateFrom);
  }
  if (dateTo) {
    conditions.push("r.logged_at <= ?");
    params.push(dateTo);
  }
  if (search) {
    conditions.push("(m.location LIKE ? OR m.description LIKE ? OR r.logged_by_name LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (cursor) {
    const decoded = decodeCursor(cursor);
    if (!decoded) return c.json({ error: "Invalid cursor" }, 400);
    conditions.push("(r.logged_at < ? OR (r.logged_at = ? AND r.id < ?))");
    params.push(decoded.loggedAt, decoded.loggedAt, decoded.id);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

  const { results } = await c.env.DB.prepare(
    `SELECT r.id, r.value, r.photo_key, r.logged_by, r.logged_by_name, r.logged_at, r.synced_at,
            m.id as meter_id, m.type as meter_type, m.location as meter_location,
            m.floor_number as meter_floor, m.description as meter_description
     FROM readings r
     JOIN meters m ON m.id = r.meter_id
     ${where}
     ORDER BY r.logged_at DESC, r.id DESC
     LIMIT ?`
  )
    .bind(...params, limit + 1)
    .all<{ id: string; logged_at: string }>();

  const hasMore = results.length > limit;
  const page = hasMore ? results.slice(0, limit) : results;
  const last = page[page.length - 1];
  const nextCursor = hasMore && last ? encodeCursor(last.logged_at, last.id) : null;

  return c.json({ readings: page, nextCursor });
});
