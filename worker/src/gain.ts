/**
 * Recomputes `gain` for every reading of one meter: the difference from the
 * previous reading by logged time, NULL for the first. Called after every
 * insert, value edit and delete so out-of-order syncs and corrections never
 * leave a stale gain behind. One statement per meter.
 */
export async function recomputeGains(db: D1Database, meterId: string): Promise<void> {
  await db
    .prepare(
      `UPDATE readings SET gain = g.gain
       FROM (
         SELECT id, value - LAG(value) OVER (ORDER BY logged_at, id) AS gain
         FROM readings WHERE meter_id = ?
       ) AS g
       WHERE readings.id = g.id`
    )
    .bind(meterId)
    .run();
}
