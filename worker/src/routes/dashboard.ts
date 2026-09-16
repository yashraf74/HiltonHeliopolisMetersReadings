import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

export const dashboardRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

dashboardRoutes.use("*", requireAuth, requireRole("moderator", "engineer"));

// GET /api/dashboard?from=ISO&to=ISO&tz=<minutes east of UTC>
// Days are bucketed in the caller's local time via the tz offset.
dashboardRoutes.get("/", async (c) => {
  const from = c.req.query("from");
  const to = c.req.query("to");
  if (!from || !to || Number.isNaN(Date.parse(from)) || Number.isNaN(Date.parse(to))) {
    return c.json({ error: "from and to (ISO timestamps) are required" }, 400);
  }
  const tz = Number(c.req.query("tz") ?? "0");
  const tzMod = `${Number.isInteger(tz) ? tz : 0} minutes`;
  const db = c.env.DB;

  const [counts, daily, totals, perMeter] = await Promise.all([
    db
      .prepare("SELECT COUNT(*) AS readings, COUNT(DISTINCT meter_id) AS meters FROM readings WHERE logged_at >= ? AND logged_at <= ?")
      .bind(from, to)
      .first<{ readings: number; meters: number }>(),
    db
      .prepare(
        `SELECT date(r.logged_at, ?) AS day, m.type AS type, SUM(r.gain) AS gain, COUNT(*) AS readings
         FROM readings r JOIN meters m ON m.id = r.meter_id
         WHERE r.logged_at >= ? AND r.logged_at <= ?
         GROUP BY day, m.type ORDER BY day`
      )
      .bind(tzMod, from, to)
      .all<{ day: string; type: string; gain: number | null; readings: number }>(),
    db
      .prepare(
        `SELECT m.type AS type, SUM(r.gain) AS gain, COUNT(r.gain) AS gains, COUNT(*) AS readings
         FROM readings r JOIN meters m ON m.id = r.meter_id
         WHERE r.logged_at >= ? AND r.logged_at <= ?
         GROUP BY m.type`
      )
      .bind(from, to)
      .all<{ type: string; gain: number | null; gains: number; readings: number }>(),
    // Every active meter with its reading count in range (zero included),
    // so "least" can surface meters nobody read.
    db
      .prepare(
        `SELECT m.id, m.name, m.type, m.area, COUNT(r.id) AS readings
         FROM meters m
         LEFT JOIN readings r ON r.meter_id = m.id AND r.logged_at >= ? AND r.logged_at <= ?
         WHERE m.is_active = 1
         GROUP BY m.id
         ORDER BY readings DESC, m.name COLLATE NOCASE`
      )
      .bind(from, to)
      .all<{ id: string; name: string; type: string; area: string; readings: number }>(),
  ]);

  const meters = perMeter.results;
  const most = meters.length ? meters[0] : null;
  const least = meters.length ? meters[meters.length - 1] : null;

  return c.json({
    from,
    to,
    readings: counts?.readings ?? 0,
    metersRead: counts?.meters ?? 0,
    activeMeters: meters.length,
    most,
    least,
    daily: daily.results,
    totals: totals.results,
  });
});
