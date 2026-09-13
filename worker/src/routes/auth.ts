import { Hono } from "hono";
import type { Env } from "../types";
import { verifyPassword, signJwt } from "../auth";

interface UserRow {
  id: string;
  username: string;
  password_hash: string;
  full_name: string;
  role: "engineer" | "technician";
}

export const authRoutes = new Hono<{ Bindings: Env }>();

authRoutes.post("/login", async (c) => {
  const body = await c.req.json().catch(() => null);
  const username = typeof body?.username === "string" ? body.username.trim() : "";
  const password = typeof body?.password === "string" ? body.password : "";

  if (!username || !password) {
    return c.json({ error: "username and password are required" }, 400);
  }

  const user = await c.env.DB.prepare(
    "SELECT id, username, password_hash, full_name, role FROM users WHERE username = ? AND is_active = 1"
  )
    .bind(username)
    .first<UserRow>();

  if (!user || !(await verifyPassword(password, user.password_hash))) {
    return c.json({ error: "Invalid username or password" }, 401);
  }

  const token = await signJwt(
    { sub: user.id, username: user.username, fullName: user.full_name, role: user.role },
    c.env.JWT_SECRET
  );

  return c.json({
    token,
    user: { id: user.id, username: user.username, fullName: user.full_name, role: user.role },
  });
});
