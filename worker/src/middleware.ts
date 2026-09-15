import type { Context, Next } from "hono";
import type { Env, AuthUser, Role } from "./types";
import { verifyJwt } from "./auth";

export interface AuthedVars {
  user: AuthUser;
}

type AuthedContext = Context<{ Bindings: Env; Variables: AuthedVars }>;

export async function requireAuth(c: AuthedContext, next: Next) {
  const authHeader = c.req.header("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
  if (!token) return c.json({ error: "Missing bearer token" }, 401);

  const payload = await verifyJwt(token, c.env.JWT_SECRET);
  if (!payload) return c.json({ error: "Invalid or expired token" }, 401);

  c.set("user", {
    id: payload.sub,
    username: payload.username,
    fullName: payload.fullName,
    role: payload.role,
  });
  await next();
}

/** Allows any of the given roles. */
export function requireRole(...roles: Role[]) {
  return async (c: AuthedContext, next: Next) => {
    const user = c.get("user");
    if (!user || !roles.includes(user.role)) return c.json({ error: "Forbidden" }, 403);
    await next();
  };
}
