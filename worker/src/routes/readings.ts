import { Hono } from "hono";
import type { Context } from "hono";
import type { Env } from "../types";
import { READINGS_ADMIN_ROLES } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth } from "../middleware";
import { recomputeGains } from "../gain";

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

  const result = await c.env.DB.prepare(
    `INSERT INTO readings (id, meter_id, value, photo_key, logged_by, logged_at, synced_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO NOTHING`
  )
    .bind(id, meterId, value, photoKey, user.id, loggedAt, now, now)
    .run();
  if (result.meta.changes) await recomputeGains(c.env.DB, meterId);

  const row = await c.env.DB.prepare("SELECT synced_at FROM readings WHERE id = ?")
    .bind(id)
    .first<{ synced_at: string }>();

  return c.json({ id, syncedAt: row?.synced_at ?? now });
});

const DEFAULT_PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 200;

// A sort is a list of keys; the cursor carries one value per key and the
// keyset condition is the lexicographic tuple comparison. `dir` flips only
// the keys marked `follows` (the primary sort); fixed-direction keys keep
// their own order, e.g. "default" = export order asc, then newest first.
interface SortKey {
  expr: string;
  nocase?: boolean;
  desc?: boolean; // fixed direction (ignores `dir`)
  follows?: boolean; // direction follows `dir`
}
const ORDER_LAST = 2147483647;
const SORTS: Record<string, SortKey[]> = {
  default: [
    { expr: `COALESCE(m.export_order, ${ORDER_LAST})`, follows: true },
    { expr: "r.logged_at", desc: true },
  ],
  logged_at: [{ expr: "r.logged_at", follows: true }],
  value: [{ expr: "r.value", follows: true }],
  meter_name: [{ expr: "m.name", nocase: true, follows: true }],
  meter_type: [{ expr: "m.type", follows: true }, { expr: "r.logged_at", desc: true }],
  technician: [{ expr: "u.full_name", nocase: true, follows: true }, { expr: "r.logged_at", desc: true }],
};

type CursorValue = string | number;

function encodeCursor(values: CursorValue[], id: string): string {
  const raw = JSON.stringify([...values, id]);
  return btoa(unescape(encodeURIComponent(raw))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decodeCursor(cursor: string, arity: number): { values: CursorValue[]; id: string } | null {
  try {
    const padded = cursor.replace(/-/g, "+").replace(/_/g, "/");
    const raw = decodeURIComponent(escape(atob(padded + "=".repeat((4 - (padded.length % 4)) % 4))));
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed) || parsed.length !== arity + 1) return null;
    const id = parsed[parsed.length - 1];
    if (typeof id !== "string") return null;
    const values = parsed.slice(0, -1);
    if (!values.every((v) => typeof v === "string" || typeof v === "number")) return null;
    return { values, id };
  } catch {
    return null;
  }
}

// Technicians only ever see (and touch) their own readings.
readingRoutes.get("/", async (c) => {
  const user = c.get("user");
  const settings = c.get("settings");
  const typeParam = c.req.query("type");
  const number = c.req.query("number");
  const userId = c.req.query("userId");
  const dateFrom = c.req.query("dateFrom");
  const dateTo = c.req.query("dateTo");
  const search = c.req.query("search");
  const cursor = c.req.query("cursor");
  const forExport = c.req.query("export") === "1";
  const limitParam = Number(c.req.query("limit") ?? DEFAULT_PAGE_SIZE);
  const limit = Number.isInteger(limitParam) ? Math.min(Math.max(limitParam, 1), MAX_PAGE_SIZE) : DEFAULT_PAGE_SIZE;
  const sortKey = c.req.query("sort") ?? "default";
  const sort = SORTS[sortKey];
  if (!sort) return c.json({ error: `sort must be one of: ${Object.keys(SORTS).join(", ")}` }, 400);
  const dirDesc = (c.req.query("dir") ?? (sortKey === "default" ? "asc" : "desc")) !== "asc";
  if (forExport && !settings.exportEnabled) return c.json({ error: "Export is disabled", code: "export_disabled" }, 403);

  const keys = sort.map((k) => ({
    expr: k.expr,
    collate: k.nocase ? " COLLATE NOCASE" : "",
    desc: k.follows ? dirDesc : !!k.desc,
  }));
  // Tie-break on id in the direction of the last key.
  const idDesc = keys[keys.length - 1].desc;

  const conditions: string[] = [];
  const params: unknown[] = [];

  if (!READINGS_ADMIN_ROLES.includes(user.role)) {
    conditions.push("r.logged_by = ?");
    params.push(user.id);
  }
  if (typeParam) {
    const types = typeParam.split(",").map((t) => t.trim()).filter(Boolean);
    if (types.length) {
      conditions.push(`m.type IN (${types.map(() => "?").join(", ")})`);
      params.push(...types);
    }
  }
  if (number) {
    conditions.push("m.number LIKE ?");
    params.push(`%${number}%`);
  }
  if (userId) {
    conditions.push("r.logged_by = ?");
    params.push(userId);
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
    const decoded = decodeCursor(cursor, keys.length);
    if (!decoded) return c.json({ error: "Invalid cursor" }, 400);
    // (k1 op v1) OR (k1 = v1 AND k2 op v2) OR ... OR (all equal AND id op vid)
    const parts: string[] = [];
    for (let i = 0; i <= keys.length; i++) {
      const eq: string[] = [];
      for (let j = 0; j < i; j++) {
        eq.push(`${keys[j].expr} = ?${keys[j].collate}`);
        params.push(decoded.values[j]);
      }
      if (i < keys.length) {
        eq.push(`${keys[i].expr} ${keys[i].desc ? "<" : ">"} ?${keys[i].collate}`);
        params.push(decoded.values[i]);
      } else {
        eq.push(`r.id ${idDesc ? "<" : ">"} ?`);
        params.push(decoded.id);
      }
      parts.push(`(${eq.join(" AND ")})`);
    }
    conditions.push(`(${parts.join(" OR ")})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const orderBy = [
    ...keys.map((k) => `${k.expr}${k.collate} ${k.desc ? "DESC" : "ASC"}`),
    `r.id ${idDesc ? "DESC" : "ASC"}`,
  ].join(", ");
  const sortSelects = keys.map((k, i) => `${k.expr} AS sort_${i}`).join(", ");

  const { results } = await c.env.DB.prepare(
    `SELECT r.id, r.value, r.gain, r.photo_key, r.logged_by, r.logged_at, r.synced_at,
            u.full_name as logged_by_name, u.username as logged_by_username,
            m.id as meter_id, m.name as meter_name, m.type as meter_type, m.location as meter_location,
            m.area as meter_area, m.number as meter_number, m.description as meter_description,
            m.export_order as meter_export_order,
            ${sortSelects}
     FROM readings r
     JOIN meters m ON m.id = r.meter_id
     JOIN users u ON u.id = r.logged_by
     ${where}
     ORDER BY ${orderBy}
     LIMIT ?`
  )
    .bind(...params, limit + 1)
    .all<Record<string, unknown> & { id: string }>();

  const hasMore = results.length > limit;
  const page = hasMore ? results.slice(0, limit) : results;
  const last = page[page.length - 1];
  const nextCursor =
    hasMore && last ? encodeCursor(keys.map((_, i) => last[`sort_${i}`] as CursorValue), last.id) : null;
  for (const row of page) for (let i = 0; i < keys.length; i++) delete row[`sort_${i}`];

  return c.json({ readings: page, nextCursor });
});

type ReadingContext = Context<{ Bindings: Env; Variables: AuthedVars }, string>;

async function loadOwned(c: ReadingContext, id: string) {
  const user = c.get("user");
  const row = await c.env.DB.prepare("SELECT id, meter_id, photo_key, logged_by FROM readings WHERE id = ?")
    .bind(id)
    .first<{ id: string; meter_id: string; photo_key: string | null; logged_by: string }>();
  if (!row) return { error: c.json({ error: "Reading not found" }, 404) };
  if (!READINGS_ADMIN_ROLES.includes(user.role) && row.logged_by !== user.id) {
    return { error: c.json({ error: "Forbidden" }, 403) };
  }
  return { row };
}

// Edit the value only; gains for that meter are recomputed.
readingRoutes.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);
  const value = body?.value;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return c.json({ error: "value must be a number" }, 400);
  }
  const { error, row } = await loadOwned(c, id);
  if (error) return error;

  await c.env.DB.prepare("UPDATE readings SET value = ? WHERE id = ?").bind(value, id).run();
  await recomputeGains(c.env.DB, row!.meter_id);
  return c.json({ ok: true });
});

// Hard delete (when enabled in settings); the photo is removed best-effort.
readingRoutes.delete("/:id", async (c) => {
  if (!c.get("settings").readingDeleteEnabled) {
    return c.json({ error: "Deleting readings is disabled", code: "delete_disabled" }, 403);
  }
  const id = c.req.param("id");
  const { error, row } = await loadOwned(c, id);
  if (error) return error;

  await c.env.DB.prepare("DELETE FROM readings WHERE id = ?").bind(id).run();
  await recomputeGains(c.env.DB, row!.meter_id);
  if (row!.photo_key) {
    try {
      await c.env.PHOTOS.delete(row!.photo_key);
    } catch (err) {
      console.error("photo delete failed", row!.photo_key, err);
    }
  }
  return c.json({ ok: true });
});
