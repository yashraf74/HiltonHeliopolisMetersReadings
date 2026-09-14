import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";
import { hashPassword } from "../auth";

const ROLES = ["engineer", "technician"] as const;
const USERNAME_RE = /^[a-z0-9_.]{3,32}$/;
const MIN_PASSWORD_LENGTH = 6;

interface UserRow {
  id: string;
  username: string;
  full_name: string;
  role: "engineer" | "technician";
  is_active: number;
  created_at: string;
}

function publicUser(u: UserRow) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.full_name,
    role: u.role,
    isActive: u.is_active === 1,
    createdAt: u.created_at,
  };
}

export const userRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

userRoutes.use("*", requireAuth, requireRole("engineer"));

userRoutes.get("/", async (c) => {
  const { results } = await c.env.DB.prepare(
    "SELECT id, username, full_name, role, is_active, created_at FROM users ORDER BY is_active DESC, role, full_name"
  ).all<UserRow>();
  return c.json({ users: results.map(publicUser) });
});

userRoutes.post("/", async (c) => {
  const body = await c.req.json().catch(() => null);
  const username = typeof body?.username === "string" ? body.username.trim().toLowerCase() : "";
  const password = typeof body?.password === "string" ? body.password : "";
  const fullName = typeof body?.fullName === "string" ? body.fullName.trim() : "";
  const role = body?.role;

  if (!USERNAME_RE.test(username)) {
    return c.json({ error: "username must be 3-32 chars: lowercase letters, digits, _ or ." }, 400);
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    return c.json({ error: `password must be at least ${MIN_PASSWORD_LENGTH} characters` }, 400);
  }
  if (!fullName) return c.json({ error: "fullName is required" }, 400);
  if (!ROLES.includes(role)) return c.json({ error: "role must be engineer or technician" }, 400);

  const existing = await c.env.DB.prepare("SELECT id FROM users WHERE username = ?").bind(username).first();
  if (existing) return c.json({ error: "username already exists" }, 409);

  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  await c.env.DB.prepare(
    "INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at) VALUES (?, ?, ?, ?, ?, 1, ?)"
  )
    .bind(id, username, await hashPassword(password), fullName, role, now)
    .run();

  return c.json({ id }, 201);
});

// Edits name / role / active flag, and optionally resets the password.
userRoutes.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);
  const me = c.get("user");

  const target = await c.env.DB.prepare("SELECT id, role, is_active FROM users WHERE id = ?")
    .bind(id)
    .first<Pick<UserRow, "id" | "role" | "is_active">>();
  if (!target) return c.json({ error: "User not found" }, 404);

  const fullName = typeof body?.fullName === "string" && body.fullName.trim() ? body.fullName.trim() : null;
  const role = body?.role ?? null;
  const isActive = typeof body?.isActive === "boolean" ? (body.isActive ? 1 : 0) : null;
  const password = typeof body?.password === "string" ? body.password : null;

  if (role !== null && !ROLES.includes(role)) {
    return c.json({ error: "role must be engineer or technician" }, 400);
  }
  if (password !== null && password.length < MIN_PASSWORD_LENGTH) {
    return c.json({ error: `password must be at least ${MIN_PASSWORD_LENGTH} characters` }, 400);
  }
  // An engineer can't lock themselves out or demote themselves.
  if (id === me.id && (isActive === 0 || (role !== null && role !== "engineer"))) {
    return c.json({ error: "You cannot deactivate or demote your own account" }, 400);
  }

  const passwordHash = password !== null ? await hashPassword(password) : null;
  await c.env.DB.prepare(
    `UPDATE users SET
       full_name = COALESCE(?, full_name),
       role = COALESCE(?, role),
       is_active = COALESCE(?, is_active),
       password_hash = COALESCE(?, password_hash)
     WHERE id = ?`
  )
    .bind(fullName, role, isActive, passwordHash, id)
    .run();

  return c.json({ ok: true });
});
