import { Hono } from "hono";
import type { Context } from "hono";
import type { Env } from "../types";
import { READINGS_ADMIN_ROLES } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth } from "../middleware";

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
    `INSERT INTO readings (id, meter_id, value, photo_key, logged_by, logged_at, synced_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO NOTHING`
  )
    .bind(id, meterId, value, photoKey, user.id, loggedAt, now, now)
    .run();

  const row = await c.env.DB.prepare("SELECT synced_at FROM readings WHERE id = ?")
    .bind(id)
    .first<{ synced_at: string }>();

  return c.json({ id, syncedAt: row?.synced_at ?? now });
});

const DEFAULT_PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 200;

// Sortable columns. `nocase` columns compare case-insensitively, and the
// cursor comparison must use the same collation as the ORDER BY.
const SORTS: Record<string, { expr: string; nocase: boolean }> = {
  logged_at: { expr: "r.logged_at", nocase: false },
  value: { expr: "r.value", nocase: false },
  meter_name: { expr: "m.name", nocase: true },
  floor: { expr: "m.floor_number", nocase: false },
  technician: { expr: "u.full_name", nocase: true },
};

type CursorValue = string | number;

// Cursor = base64url(JSON [sortValue, id]) of the last row of the previous
// page. Keyset pagination stays correct as new readings arrive, unlike
// OFFSET which would shift every page.
function encodeCursor(value: CursorValue, id: string): string {
  const raw = JSON.stringify([value, id]);
  return btoa(unescape(encodeURIComponent(raw))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decodeCursor(cursor: string): { value: CursorValue; id: string } | null {
  try {
    const padded = cursor.replace(/-/g, "+").replace(/_/g, "/");
    const raw = decodeURIComponent(escape(atob(padded + "=".repeat((4 - (padded.length % 4)) % 4))));
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed) || parsed.length !== 2 || typeof parsed[1] !== "string") return null;
    if (typeof parsed[0] !== "string" && typeof parsed[0] !== "number") return null;
    return { value: parsed[0], id: parsed[1] };
  } catch {
    return null;
  }
}

// Technicians only ever see (and touch) their own readings.
readingRoutes.get("/", async (c) => {
  const user = c.get("user");
  const type = c.req.query("type");
  const floor = c.req.query("floor");
  const technician = c.req.query("technician");
  const dateFrom = c.req.query("dateFrom");
  const dateTo = c.req.query("dateTo");
  const search = c.req.query("search");
  const cursor = c.req.query("cursor");
  const limitParam = Number(c.req.query("limit") ?? DEFAULT_PAGE_SIZE);
  const limit = Number.isInteger(limitParam) ? Math.min(Math.max(limitParam, 1), MAX_PAGE_SIZE) : DEFAULT_PAGE_SIZE;
  const sortKey = c.req.query("sort") ?? "logged_at";
  const sort = SORTS[sortKey];
  if (!sort) return c.json({ error: `sort must be one of: ${Object.keys(SORTS).join(", ")}` }, 400);
  const desc = (c.req.query("dir") ?? "desc") !== "asc";
  const collate = sort.nocase ? " COLLATE NOCASE" : "";

  const conditions: string[] = [];
  const params: unknown[] = [];

  if (!READINGS_ADMIN_ROLES.includes(user.role)) {
    conditions.push("r.logged_by = ?");
    params.push(user.id);
  }
  if (type) {
    conditions.push("m.type = ?");
    params.push(type);
  }
  if (floor) {
    conditions.push("m.floor_number = ?");
    params.push(Number(floor));
  }
  if (technician) {
    conditions.push("u.full_name LIKE ?");
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
    conditions.push("(m.name LIKE ? OR m.area LIKE ? OR m.number LIKE ? OR m.location LIKE ? OR m.description LIKE ? OR u.full_name LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (cursor) {
    const decoded = decodeCursor(cursor);
    if (!decoded) return c.json({ error: "Invalid cursor" }, 400);
    const op = desc ? "<" : ">";
    conditions.push(
      `(${sort.expr} ${op} ?${collate} OR (${sort.expr} = ?${collate} AND r.id ${op} ?))`
    );
    params.push(decoded.value, decoded.value, decoded.id);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const dir = desc ? "DESC" : "ASC";

  const { results } = await c.env.DB.prepare(
    `SELECT r.id, r.value, r.photo_key, r.logged_by, r.logged_at, r.synced_at,
            u.full_name as logged_by_name, u.username as logged_by_username,
            m.id as meter_id, m.name as meter_name, m.type as meter_type, m.location as meter_location,
            m.area as meter_area, m.number as meter_number,
            m.floor_number as meter_floor, m.description as meter_description,
            ${sort.expr} as sort_value
     FROM readings r
     JOIN meters m ON m.id = r.meter_id
     JOIN users u ON u.id = r.logged_by
     ${where}
     ORDER BY ${sort.expr}${collate} ${dir}, r.id ${dir}
     LIMIT ?`
  )
    .bind(...params, limit + 1)
    .all<{ id: string; sort_value: CursorValue }>();

  const hasMore = results.length > limit;
  const page = hasMore ? results.slice(0, limit) : results;
  const last = page[page.length - 1];
  const nextCursor = hasMore && last ? encodeCursor(last.sort_value, last.id) : null;
  for (const row of page) delete (row as Record<string, unknown>).sort_value;

  return c.json({ readings: page, nextCursor });
});

type ReadingContext = Context<{ Bindings: Env; Variables: AuthedVars }, string>;

async function loadOwned(c: ReadingContext, id: string) {
  const user = c.get("user");
  const row = await c.env.DB.prepare("SELECT id, photo_key, logged_by FROM readings WHERE id = ?")
    .bind(id)
    .first<{ id: string; photo_key: string | null; logged_by: string }>();
  if (!row) return { error: c.json({ error: "Reading not found" }, 404) };
  if (!READINGS_ADMIN_ROLES.includes(user.role) && row.logged_by !== user.id) {
    return { error: c.json({ error: "Forbidden" }, 403) };
  }
  return { row };
}

// Edit the value only.
readingRoutes.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);
  const value = body?.value;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return c.json({ error: "value must be a number" }, 400);
  }
  const { error } = await loadOwned(c, id);
  if (error) return error;

  await c.env.DB.prepare("UPDATE readings SET value = ? WHERE id = ?").bind(value, id).run();
  return c.json({ ok: true });
});

// Hard delete; the photo is removed from R2 best-effort.
readingRoutes.delete("/:id", async (c) => {
  const id = c.req.param("id");
  const { error, row } = await loadOwned(c, id);
  if (error) return error;

  await c.env.DB.prepare("DELETE FROM readings WHERE id = ?").bind(id).run();
  if (row!.photo_key) {
    try {
      await c.env.PHOTOS.delete(row!.photo_key);
    } catch (err) {
      console.error("photo delete failed", row!.photo_key, err);
    }
  }
  return c.json({ ok: true });
});
