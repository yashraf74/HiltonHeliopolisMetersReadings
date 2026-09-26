import type { D1Database } from "@cloudflare/workers-types";

/** Earlier readings of a meter within this window form its "usual" daily use. */
const BASELINE_DAYS = 60;
/** A daily use above this multiple of the meter's usual is flagged. */
const HIGH_FACTOR = 2.5;
/** A meter needs this many earlier gains before it has a usual. */
const MIN_BASELINE = 3;
/** A gain is never spread over more days than this. */
const MAX_SPREAD_DAYS = 60;

const DAY_MS = 86_400_000;

export interface UnusualRow {
  id: string;
  meter_id: string;
  type: string;
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
  normal_at: string | null;
}

/** Whole days a gain covers: time since the meter's previous reading, at least 1. */
export function spreadDays(row: { logged_at: string; prev_at: string | null }): number {
  if (!row.prev_at) return 1;
  const days = Math.round((Date.parse(row.logged_at) - Date.parse(row.prev_at)) / DAY_MS);
  return Math.min(MAX_SPREAD_DAYS, Math.max(1, days));
}

function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/**
 * Readings in [from, to] whose gain is negative (a typo or a replaced meter)
 * or far above that meter's usual daily use. Readings a moderator marked as
 * normal are never flagged; they still count towards every total, including
 * the baselines here.
 */
export function findUnusual(rows: UnusualRow[], from: string, to: string) {
  const baselineFrom = new Date(Date.parse(to) - BASELINE_DAYS * DAY_MS).toISOString();
  const rates = new Map<string, { id: string; rate: number }[]>();
  for (const r of rows) {
    if (r.gain === null || r.gain < 0 || r.logged_at < baselineFrom || r.logged_at > to) continue;
    const list = rates.get(r.meter_id) ?? [];
    list.push({ id: r.id, rate: r.gain / spreadDays(r) });
    rates.set(r.meter_id, list);
  }

  const unusual = [];
  for (const r of rows) {
    if (r.gain === null || r.normal_at !== null) continue;
    if (r.logged_at < from || r.logged_at > to) continue;
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
  return unusual;
}

/** Readings (with each one's previous reading time) for the unusual check. */
export function loadRowsForUnusual(db: D1Database, innerFrom: string, to: string, outerFrom: string) {
  return db
    .prepare(
      `SELECT * FROM (
         SELECT r.id, r.meter_id, m.type, m.name, m.area, m.photo_key, r.value, r.gain, r.logged_at,
                r.photo_key AS reading_photo_key, r.logged_by, r.normal_at, u.full_name AS logged_by_name,
                LAG(r.logged_at) OVER (PARTITION BY r.meter_id ORDER BY r.logged_at, r.id) AS prev_at
         FROM readings r JOIN meters m ON m.id = r.meter_id JOIN users u ON u.id = r.logged_by
         WHERE r.logged_at >= ? AND r.logged_at <= ?
       ) WHERE logged_at >= ?
       ORDER BY logged_at, id`
    )
    .bind(innerFrom, to, outerFrom)
    .all<UnusualRow>();
}
