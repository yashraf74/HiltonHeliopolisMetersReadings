import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth, requireRole } from "../middleware";
import { hashPassword } from "../auth";

const ROLES = ["moderator", "engineer", "technician"] as const;
const USERNAME_RE = /^[a-z0-9_.]{3,32}$/;
const MIN_PASSWORD_LENGTH = 6;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_EMAIL_LENGTH = 254;
/** Given to users created before emails existed; treated as "no email". */
export const PLACEHOLDER_EMAIL = "null@hilton.com";

/** Trimmed, lower-cased email, or null when it isn't a valid address. */
function normalizeEmail(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const email = v.trim().toLowerCase();
  return email.length <= MAX_EMAIL_LENGTH && EMAIL_RE.test(email) ? email : null;
}
const EMAIL_ERROR = "email must be a valid address like name@example.com";

interface UserRow {
  id: string;
  username: string;
  full_name: string;
  email: string;
  role: "moderator" | "engineer" | "technician";
  is_active: number;
  created_at: string;
}

function publicUser(u: UserRow) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.full_name,
    email: u.email,
    role: u.role,
    isActive: u.is_active === 1,
    createdAt: u.created_at,
  };
}

export const userRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

userRoutes.use("*", requireAuth);

// Names only, for the readings "by user" filter (engineers too).
userRoutes.get("/names", requireRole("moderator", "engineer"), async (c) => {
  const { results } = await c.env.DB.prepare(
    "SELECT id, full_name FROM users WHERE is_active = 1 ORDER BY full_name"
  ).all<{ id: string; full_name: string }>();
  return c.json({ users: results.map((u) => ({ id: u.id, fullName: u.full_name })) });
});

userRoutes.use("*", requireRole("moderator"));

userRoutes.get("/", async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT id, username, full_name, email, role, is_active, created_at FROM users WHERE is_active = 1
     ORDER BY CASE role WHEN 'moderator' THEN 0 WHEN 'engineer' THEN 1 ELSE 2 END, full_name COLLATE NOCASE`
  ).all<UserRow>();
  return c.json({ users: results.map(publicUser) });
});

userRoutes.post("/", async (c) => {
  const body = await c.req.json().catch(() => null);
  const username = typeof body?.username === "string" ? body.username.trim().toLowerCase() : "";
  const password = typeof body?.password === "string" ? body.password : "";
  const fullName = typeof body?.fullName === "string" ? body.fullName.trim() : "";
  const email = normalizeEmail(body?.email);
  const role = body?.role;

  if (!USERNAME_RE.test(username)) {
    return c.json({ error: "username must be 3-32 chars: lowercase letters, digits, _ or ." }, 400);
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    return c.json({ error: `password must be at least ${MIN_PASSWORD_LENGTH} characters` }, 400);
  }
  if (!fullName) return c.json({ error: "fullName is required" }, 400);
  if (!email) return c.json({ error: EMAIL_ERROR }, 400);
  if (!ROLES.includes(role)) return c.json({ error: "role must be engineer or technician" }, 400);

  const existing = await c.env.DB.prepare("SELECT id, is_active FROM users WHERE username = ?")
    .bind(username)
    .first<{ id: string; is_active: number }>();
  if (existing?.is_active) return c.json({ error: "username already exists" }, 409);
  if (existing) {
    // A deleted account being re-created: revive it under the same id so
    // its historical readings keep pointing at it.
    await c.env.DB.prepare(
      "UPDATE users SET password_hash = ?, full_name = ?, email = ?, role = ?, is_active = 1 WHERE id = ?"
    )
      .bind(await hashPassword(password), fullName, email, role, existing.id)
      .run();
    return c.json({ id: existing.id }, 201);
  }

  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  await c.env.DB.prepare(
    "INSERT INTO users (id, username, password_hash, full_name, email, role, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, ?)"
  )
    .bind(id, username, await hashPassword(password), fullName, email, role, now)
    .run();

  return c.json({ id }, 201);
});

// Edits name / email / role / active flag, and optionally resets the password.
userRoutes.put("/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);
  const me = c.get("user");

  const target = await c.env.DB.prepare("SELECT id, role, is_active FROM users WHERE id = ?")
    .bind(id)
    .first<Pick<UserRow, "id" | "role" | "is_active">>();
  if (!target) return c.json({ error: "User not found" }, 404);

  const fullName = typeof body?.fullName === "string" && body.fullName.trim() ? body.fullName.trim() : null;
  const email = body?.email === undefined ? null : normalizeEmail(body.email);
  if (body?.email !== undefined && !email) return c.json({ error: EMAIL_ERROR }, 400);
  const role = body?.role ?? null;
  const isActive = typeof body?.isActive === "boolean" ? (body.isActive ? 1 : 0) : null;
  const password = typeof body?.password === "string" ? body.password : null;

  if (role !== null && !ROLES.includes(role)) {
    return c.json({ error: "role must be engineer or technician" }, 400);
  }
  if (password !== null && password.length < MIN_PASSWORD_LENGTH) {
    return c.json({ error: `password must be at least ${MIN_PASSWORD_LENGTH} characters` }, 400);
  }
  // A moderator can't delete or demote their own account.
  if (id === me.id && (isActive === 0 || (role !== null && role !== "moderator"))) {
    return c.json({ error: "You cannot deactivate or demote your own account" }, 400);
  }

  const passwordHash = password !== null ? await hashPassword(password) : null;
  await c.env.DB.prepare(
    `UPDATE users SET
       full_name = COALESCE(?, full_name),
       email = COALESCE(?, email),
       role = COALESCE(?, role),
       is_active = COALESCE(?, is_active),
       password_hash = COALESCE(?, password_hash)
     WHERE id = ?`
  )
    .bind(fullName, email, role, isActive, passwordHash, id)
    .run();

  return c.json({ ok: true });
});
