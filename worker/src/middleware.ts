import type { Context, Next } from "hono";
import type { Env, AuthUser, Role, Settings } from "./types";
import { verifyJwt } from "./auth";
import { compareVersions, loadSettings, MAINTENANCE_MESSAGE, UPGRADE_REQUIRED_MESSAGE } from "./settings";

export interface AuthedVars {
  user: AuthUser;
  settings: Settings;
}

type AppContext = Context<{ Bindings: Env; Variables: AuthedVars }>;

/**
 * Runs on every /api route: loads the runtime settings and rejects clients
 * below the minimum app version (426). The app sends `X-App-Version`; a
 * missing header means a build that predates the gate, which is also too old.
 */
export async function appGate(c: AppContext, next: Next) {
  const settings = await loadSettings(c.env);
  c.set("settings", settings);
  const version = c.req.header("X-App-Version") ?? "0.0.0";
  if (compareVersions(version, settings.minAppVersion) < 0) {
    return c.json({ error: UPGRADE_REQUIRED_MESSAGE, code: "upgrade_required" }, 426);
  }
  await next();
}

export async function requireAuth(c: AppContext, next: Next) {
  const authHeader = c.req.header("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return c.json({ error: "Missing bearer token" }, 401);

  const payload = await verifyJwt(token, c.env.JWT_SECRET);
  if (!payload) return c.json({ error: "Invalid or expired token" }, 401);

  const user: AuthUser = {
    id: payload.sub,
    username: payload.username,
    fullName: payload.fullName,
    role: payload.role,
  };
  if (c.get("settings").maintenanceMode && user.role !== "moderator") {
    return c.json({ error: MAINTENANCE_MESSAGE, code: "maintenance" }, 503);
  }
  c.set("user", user);
  await next();
}

/** Allows any of the given roles. */
export function requireRole(...roles: Role[]) {
  return async (c: AppContext, next: Next) => {
    const user = c.get("user");
    if (!user || !roles.includes(user.role)) return c.json({ error: "Forbidden" }, 403);
    await next();
  };
}
