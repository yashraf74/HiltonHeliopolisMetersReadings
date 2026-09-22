import { Hono } from "hono";
import type { Env, Language } from "../types";
import { defaultLanguage } from "../types";
import type { AuthedVars } from "../middleware";
import { verifyPassword, signJwt } from "../auth";
import { MAINTENANCE_MESSAGE } from "../settings";

interface UserRow {
  id: string;
  username: string;
  password_hash: string;
  full_name: string;
  email: string;
  language: Language | null;
  role: "moderator" | "engineer" | "technician";
}

export const authRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

authRoutes.post("/login", async (c) => {
  const body = await c.req.json().catch(() => null);
  const username = typeof body?.username === "string" ? body.username.trim() : "";
  const password = typeof body?.password === "string" ? body.password : "";

  if (!username || !password) {
    return c.json({ error: "username and password are required" }, 400);
  }

  const user = await c.env.DB.prepare(
    "SELECT id, username, password_hash, full_name, email, language, role FROM users WHERE username = ? AND is_active = 1"
  )
    .bind(username)
    .first<UserRow>();

  if (!user || !(await verifyPassword(password, user.password_hash))) {
    return c.json({ error: "Invalid username or password" }, 401);
  }
  if (c.get("settings").maintenanceMode && user.role !== "moderator") {
    return c.json({ error: MAINTENANCE_MESSAGE, code: "maintenance" }, 503);
  }

  const token = await signJwt(
    { sub: user.id, username: user.username, fullName: user.full_name, role: user.role },
    c.env.JWT_SECRET,
    c.get("settings").tokenLifetimeDays
  );

  return c.json({
    token,
    user: {
      id: user.id,
      username: user.username,
      fullName: user.full_name,
      email: user.email,
      role: user.role,
      language: user.language ?? defaultLanguage(user.role),
    },
  });
});
