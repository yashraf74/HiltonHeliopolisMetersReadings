import { Hono } from "hono";
import type { Env, Settings } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";
import { saveSettings } from "../settings";

export const settingsRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

// Public: what any client needs before/after login.
settingsRoutes.get("/config", (c) => {
  const s = c.get("settings");
  return c.json({
    minAppVersion: s.minAppVersion,
    maintenanceMode: s.maintenanceMode,
    readingDeleteEnabled: s.readingDeleteEnabled,
    exportEnabled: s.exportEnabled,
  });
});

const LATEST_RELEASE_URL = "https://api.github.com/repos/yashraf74/HiltonHeliopolisMetersReadings/releases/latest";
const LATEST_CACHE_SECONDS = 600;

/**
 * Version of the newest published GitHub release ("v2.2.0" → "2.2.0"), or
 * null when GitHub can't be reached. Cached at the edge for 10 minutes to
 * stay well inside GitHub's unauthenticated rate limit.
 */
async function latestAppVersion(): Promise<string | null> {
  const cache = caches.default;
  const key = new Request(LATEST_RELEASE_URL);
  let res = await cache.match(key);
  if (!res) {
    try {
      const gh = await fetch(LATEST_RELEASE_URL, {
        headers: { "User-Agent": "hilton-heliopolis-meters-api", Accept: "application/vnd.github+json" },
      });
      if (!gh.ok) return null;
      const tag = ((await gh.json()) as { tag_name?: string }).tag_name ?? "";
      res = new Response(JSON.stringify({ tag }), {
        headers: { "Content-Type": "application/json", "Cache-Control": `max-age=${LATEST_CACHE_SECONDS}` },
      });
      await cache.put(key, res.clone());
    } catch {
      return null;
    }
  }
  const { tag } = (await res.json()) as { tag: string };
  const version = tag.replace(/^v/, "");
  return /^\d+(\.\d+){0,2}$/.test(version) ? version : null;
}

// Shown on the moderator-only About page; edited in KV only, not in the app:
// `developer_title`, and `developer_username` (the account whose photo is
// shown as the developer's).
const DEFAULT_DEVELOPER_TITLE = "Senior Shift Engineer";
const DEFAULT_DEVELOPER_USERNAME = "khalidabdoo";

settingsRoutes.get("/about", requireAuth, requireRole("moderator"), async (c) => {
  const [title, username] = await Promise.all([
    c.env.SETTINGS.get("developer_title"),
    c.env.SETTINGS.get("developer_username"),
  ]);
  const developer = await c.env.DB.prepare("SELECT photo_key FROM users WHERE username = ?")
    .bind(username?.trim() || DEFAULT_DEVELOPER_USERNAME)
    .first<{ photo_key: string | null }>();
  return c.json({
    developerTitle: title?.trim() || DEFAULT_DEVELOPER_TITLE,
    developerPhotoKey: developer?.photo_key ?? null,
  });
});

settingsRoutes.get("/settings", requireAuth, requireRole("moderator"), async (c) =>
  c.json({ ...c.get("settings"), latestAppVersion: await latestAppVersion() })
);

settingsRoutes.put("/settings", requireAuth, requireRole("moderator"), async (c) => {
  const body = await c.req.json().catch(() => null);
  const current = c.get("settings");
  const next: Settings = { ...current };

  if (body?.minAppVersion !== undefined) {
    const v = String(body.minAppVersion).trim();
    if (!/^\d+(\.\d+){0,2}$/.test(v)) return c.json({ error: "minAppVersion must look like 2.0.0" }, 400);
    next.minAppVersion = v;
  }
  for (const key of ["maintenanceMode", "readingDeleteEnabled", "exportEnabled"] as const) {
    if (body?.[key] !== undefined) {
      if (typeof body[key] !== "boolean") return c.json({ error: `${key} must be a boolean` }, 400);
      next[key] = body[key];
    }
  }
  if (body?.photoRetentionDays !== undefined) {
    const n = Number(body.photoRetentionDays);
    if (!Number.isInteger(n) || n < 7 || n > 3650) {
      return c.json({ error: "photoRetentionDays must be an integer between 7 and 3650" }, 400);
    }
    next.photoRetentionDays = n;
  }
  if (body?.tokenLifetimeDays !== undefined) {
    const n = Number(body.tokenLifetimeDays);
    if (!Number.isInteger(n) || n < 1 || n > 365) {
      return c.json({ error: "tokenLifetimeDays must be an integer between 1 and 365" }, 400);
    }
    next.tokenLifetimeDays = n;
  }
  if (body?.prices !== undefined) {
    const prices = { ...current.prices };
    for (const type of ["electricity", "water", "gas"] as const) {
      if (body.prices?.[type] === undefined) continue;
      const n = Number(body.prices[type]);
      if (!Number.isFinite(n) || n < 0 || n > 100000) {
        return c.json({ error: "prices must be numbers between 0 and 100000" }, 400);
      }
      prices[type] = n;
    }
    next.prices = prices;
  }

  await saveSettings(c.env, next);
  return c.json(next);
});
