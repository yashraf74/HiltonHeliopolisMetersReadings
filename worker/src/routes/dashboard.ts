import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";

export const dashboardRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

dashboardRoutes.use("*", requireAuth, requireRole("moderator", "engineer"));

const TYPES = ["electricity", "water", "gas"] as const;
type MeterType = (typeof TYPES)[number];

const DAY_MS = 86_400_000;
/** Earlier readings of a meter within this window form its "usual" daily use. */
const BASELINE_DAYS = 60;
/** A daily use above this multiple of the meter's usual is flagged. */
const HIGH_FACTOR = 2.5;
/** A meter needs this many earlier gains before it has a usual. */
const MIN_BASELINE = 3;
/** A reading this long after the range can still spread its gain back into it. */
const LOOKAHEAD_DAYS = 31;
/** Extra history before the window so the first readings still know their previous one. */
const LOOKBEHIND_DAYS = 45;
/** A gain is never spread over more days than this. */
const MAX_SPREAD_DAYS = 60;
const MAX_UNUSUAL = 30;
const MAX_RANGE_DAYS = 1200;

type Row = {
  id: string;
  meter_id: string;
  type: MeterType;
  name: string;
  area: string;
  photo_key: string | null;
  value: number;
  gain: number | null;
  logged_at: string;
  prev_at: string | null;
  reading_photo_key: string | null;
  logged_by: string;
  logged_by_name: string;
};

type MeterRow = {
  id: string;
  name: string;
  type: MeterType;
  area: string;
  photo_key: string | null;
  readings: number;
  last_logged_at: string | null;
};

const iso = (ms: number) => new Date(ms).toISOString();
const addDays = (day: string, n: number) => new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY_MS).toISOString().slice(0, 10);

/** Whole days a gain covers: time since the meter's previous reading, at least 1. */
function spreadDays(row: Row): number {
  if (!row.prev_at) return 1;
  const days = Math.round((Date.parse(row.logged_at) - Date.parse(row.prev_at)) / DAY_MS);
  return Math.min(MAX_SPREAD_DAYS, Math.max(1, days));
}

function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

// GET /api/dashboard?from=ISO&to=ISO&tz=<minutes east of UTC>
// Days are the caller's local days (via tz). A reading's gain is spread
// evenly over the days since the meter's previous reading, ending on the
// reading's own day, so a missed day doesn't show as zero then a spike.
dashboardRoutes.get("/", async (c) => {
  const from = c.req.query("from");
  const to = c.req.query("to");
  if (!from || !to || Number.isNaN(Date.parse(from)) || Number.isNaN(Date.parse(to))) {
    return c.json({ error: "from and to (ISO timestamps) are required" }, 400);
  }
  const tzRaw = Number(c.req.query("tz") ?? "0");
  const tz = Number.isInteger(tzRaw) ? tzRaw : 0;
  const localDay = (ms: number) => new Date(ms + tz * 60_000).toISOString().slice(0, 10);

  const fromMs = Date.parse(from);
  const toMs = Date.parse(to);
  const windowStart = Math.min(fromMs, toMs - BASELINE_DAYS * DAY_MS);
  const db = c.env.DB;

  const [rowsResult, metersResult] = await Promise.all([
    db
      .prepare(
        `SELECT * FROM (
           SELECT r.id, r.meter_id, m.type, m.name, m.area, m.photo_key, r.value, r.gain, r.logged_at,
                  r.photo_key AS reading_photo_key, r.logged_by, u.full_name AS logged_by_name,
                  LAG(r.logged_at) OVER (PARTITION BY r.meter_id ORDER BY r.logged_at, r.id) AS prev_at
           FROM readings r JOIN meters m ON m.id = r.meter_id JOIN users u ON u.id = r.logged_by
           WHERE r.logged_at >= ? AND r.logged_at <= ?
         ) WHERE logged_at >= ?
         ORDER BY logged_at, id`
      )
      .bind(iso(windowStart - LOOKBEHIND_DAYS * DAY_MS), iso(toMs + LOOKAHEAD_DAYS * DAY_MS), iso(windowStart))
      .all<Row>(),
    db
      .prepare(
        `SELECT m.id, m.name, m.type, m.area, m.photo_key,
                (SELECT COUNT(*) FROM readings r WHERE r.meter_id = m.id AND r.logged_at >= ? AND r.logged_at <= ?) AS readings,
                (SELECT MAX(r.logged_at) FROM readings r WHERE r.meter_id = m.id) AS last_logged_at
         FROM meters m
         WHERE m.is_active = 1
         ORDER BY readings DESC, m.name COLLATE NOCASE`
      )
      .bind(from, to)
      .all<MeterRow>(),
  ]);
  const rows = rowsResult.results;
  const meters = metersResult.results;

  const days: string[] = [];
  for (let d = localDay(fromMs); d <= localDay(toMs) && days.length < MAX_RANGE_DAYS; d = addDays(d, 1)) days.push(d);
  const dayIndex = new Map(days.map((d, i) => [d, i]));

  // Per-type daily consumption; null where no reading covers the day.
  const consumption = Object.fromEntries(TYPES.map((t) => [t, days.map((): number | null => null)])) as Record<
    MeterType,
    (number | null)[]
  >;
  const perMeter = new Map<string, number>();
  const readDay = days.map(() => new Set<string>());
  const inRange = (r: Row) => r.logged_at >= from && r.logged_at <= to;
  let readingCount = 0;
  const metersRead = new Set<string>();

  // For 2.0.x apps: gain summed by the reading's own day, and per type.
  const legacyDaily = new Map<string, { day: string; type: MeterType; gain: number | null; readings: number }>();
  const legacyTotals = new Map<MeterType, { type: MeterType; gain: number | null; gains: number; readings: number }>();

  for (const r of rows) {
    const day = localDay(Date.parse(r.logged_at));
    if (inRange(r)) {
      readingCount++;
      metersRead.add(r.meter_id);
      const i = dayIndex.get(day);
      if (i !== undefined) readDay[i].add(r.meter_id);

      const key = `${day}|${r.type}`;
      const ld = legacyDaily.get(key) ?? { day, type: r.type, gain: null, readings: 0 };
      ld.readings++;
      const lt = legacyTotals.get(r.type) ?? { type: r.type, gain: null, gains: 0, readings: 0 };
      lt.readings++;
      if (r.gain !== null) {
        ld.gain = (ld.gain ?? 0) + r.gain;
        lt.gain = (lt.gain ?? 0) + r.gain;
        lt.gains++;
      }
      legacyDaily.set(key, ld);
      legacyTotals.set(r.type, lt);
    }
    if (r.gain === null) continue;
    const n = spreadDays(r);
    const share = r.gain / n;
    for (let k = 0; k < n; k++) {
      const i = dayIndex.get(addDays(day, -k));
      if (i === undefined) continue;
      consumption[r.type][i] = (consumption[r.type][i] ?? 0) + share;
      perMeter.set(r.meter_id, (perMeter.get(r.meter_id) ?? 0) + share);
    }
  }

  const activeMeters = meters.length;
  const completion = readDay.map((s) => (activeMeters ? Math.min(100, (s.size / activeMeters) * 100) : 0));

  const meterInfo = new Map<string, Pick<Row, "name" | "type" | "area" | "photo_key">>();
  for (const r of rows) meterInfo.set(r.meter_id, { name: r.name, type: r.type, area: r.area, photo_key: r.photo_key });
  const consumers = [...perMeter.entries()]
    .filter(([, amount]) => amount !== 0)
    .map(([id, amount]) => ({ id, ...meterInfo.get(id)!, amount }))
    .sort((a, b) => b.amount - a.amount);

  // Unusual: a negative gain (almost always a typo or a replaced meter), or a
  // daily use well above the meter's usual (median of its other recent ones).
  const baselineFrom = iso(toMs - BASELINE_DAYS * DAY_MS);
  const rates = new Map<string, { id: string; rate: number }[]>();
  for (const r of rows) {
    if (r.gain === null || r.gain < 0 || r.logged_at < baselineFrom || r.logged_at > to) continue;
    const list = rates.get(r.meter_id) ?? [];
    list.push({ id: r.id, rate: r.gain / spreadDays(r) });
    rates.set(r.meter_id, list);
  }
  const unusual = [];
  for (const r of rows) {
    if (r.gain === null || !inRange(r)) continue;
    const rate = r.gain / spreadDays(r);
    const others = (rates.get(r.meter_id) ?? []).filter((x) => x.id !== r.id).map((x) => x.rate);
    const usual = others.length >= MIN_BASELINE ? median(others) : null;
    const kind = r.gain < 0 ? "negative" : usual !== null && usual > 0 && rate > HIGH_FACTOR * usual ? "high" : null;
    if (!kind) continue;
    unusual.push({
      id: r.id,
      kind,
      meter_id: r.meter_id,
      name: r.name,
      type: r.type,
      area: r.area,
      photo_key: r.photo_key,
      value: r.value,
      gain: r.gain,
      daily: rate,
      usual,
      logged_at: r.logged_at,
      reading_photo_key: r.reading_photo_key,
      logged_by: r.logged_by,
      logged_by_name: r.logged_by_name,
    });
  }
  unusual.sort((a, b) => (a.logged_at < b.logged_at ? 1 : -1));

  // Overdue: active meters not read yesterday or today (local), oldest first.
  const now = Date.now();
  const yesterdayStart = Date.parse(`${addDays(localDay(now), -1)}T00:00:00Z`) - tz * 60_000;
  const overdue = meters
    .filter((m) => !m.last_logged_at || Date.parse(m.last_logged_at) < yesterdayStart)
    .map((m) => ({
      id: m.id,
      name: m.name,
      type: m.type,
      area: m.area,
      photo_key: m.photo_key,
      last_logged_at: m.last_logged_at,
      days: m.last_logged_at ? Math.floor((now - Date.parse(m.last_logged_at)) / DAY_MS) : null,
    }))
    .sort((a, b) => (a.last_logged_at ?? "").localeCompare(b.last_logged_at ?? ""));

  const highlight = (m: MeterRow | undefined) =>
    m ? { id: m.id, name: m.name, type: m.type, area: m.area, photo_key: m.photo_key, readings: m.readings } : null;

  return c.json({
    from,
    to,
    days,
    prices: c.get("settings").prices,
    readings: readingCount,
    metersRead: metersRead.size,
    activeMeters,
    most: highlight(meters[0]),
    least: highlight(meters[meters.length - 1]),
    consumption,
    completion,
    consumers,
    unusual: unusual.slice(0, MAX_UNUSUAL),
    overdue,
    daily: [...legacyDaily.values()].sort((a, b) => a.day.localeCompare(b.day)),
    totals: [...legacyTotals.values()],
  });
});
