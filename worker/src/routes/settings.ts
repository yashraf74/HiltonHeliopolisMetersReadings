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

settingsRoutes.get("/settings", requireAuth, requireRole("moderator"), (c) => c.json(c.get("settings")));

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

  await saveSettings(c.env, next);
  return c.json(next);
});
