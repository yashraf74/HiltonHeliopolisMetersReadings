import type { Env } from "./types";
import { loadSettings } from "./settings";

const BATCH = 500;

/**
 * Deletes reading photos older than the retention period (a moderator
 * setting, default 90 days) from R2 and nulls
 * their `photo_key`, so the app shows an "expired" placeholder instead.
 * Meter reference photos are never purged. Runs from the cron trigger.
 */
export async function purgeExpiredPhotos(env: Env): Promise<{ purged: number }> {
  const { photoRetentionDays } = await loadSettings(env);
  const cutoff = new Date(Date.now() - photoRetentionDays * 24 * 60 * 60 * 1000).toISOString();
  let purged = 0;

  for (;;) {
    const { results } = await env.DB.prepare(
      "SELECT id, photo_key FROM readings WHERE photo_key IS NOT NULL AND logged_at < ? LIMIT ?"
    )
      .bind(cutoff, BATCH)
      .all<{ id: string; photo_key: string }>();
    if (results.length === 0) break;

    await env.PHOTOS.delete(results.map((r) => r.photo_key));
    await env.DB.batch(
      results.map((r) => env.DB.prepare("UPDATE readings SET photo_key = NULL WHERE id = ?").bind(r.id))
    );
    purged += results.length;
    if (results.length < BATCH) break;
  }

  console.log(`photo purge: ${purged} photo(s) older than ${cutoff} removed`);
  return { purged };
}
