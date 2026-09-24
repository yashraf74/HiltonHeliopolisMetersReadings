import { Hono } from "hono";
import type { Env, Language, Role } from "../types";
import { defaultLanguage } from "../types";
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
/** Egyptian mobile: 01xxxxxxxxx or +201xxxxxxxxx. */
const PHONE_RE = /^(01\d{9}|\+20\d{10})$/;
const PHONE_ERROR = "phone must look like 01xxxxxxxxx or +20xxxxxxxxxx";
const LANGUAGES: Language[] = ["ar", "en"];

/**
 * Optional field from a request body: undefined when absent (leave as is),
 * null to clear, the value otherwise; "invalid" when it fails [valid].
 */
function optionalField(body: Record<string, unknown> | null, key: string, valid: (v: string) => boolean) {
  if (!body || !(key in body)) return undefined;
  const raw = body[key];
  if (raw === null || raw === "") return null;
  if (typeof raw !== "string") return "invalid" as const;
  const v = raw.trim();
  return v === "" ? null : valid(v) ? v : ("invalid" as const);
}

interface UserRow {
  id: string;
  username: string;
  full_name: string;
  email: string;
  phone: string | null;
  photo_key: string | null;
  language: Language | null;
  role: Role;
  is_active: number;
  created_at: string;
}

const USER_COLUMNS = "id, username, full_name, email, phone, photo_key, language, role, is_active, created_at";

function publicUser(u: UserRow) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.full_name,
    email: u.email,
    phone: u.phone,
    photoKey: u.photo_key,
    language: u.language ?? defaultLanguage(u.role),
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

// Any signed-in user edits their own photo, email and mobile number, while
// the moderator's profileEditingEnabled switch allows it. Roles, usernames
// and passwords stay with moderators.
userRoutes.put("/me/profile", async (c) => {
  if (!c.get("settings").profileEditingEnabled) {
    return c.json({ error: "Editing your profile is disabled", code: "profile_editing_disabled" }, 403);
  }
  const body = await c.req.json().catch(() => null);
  const email = body?.email === undefined ? null : normalizeEmail(body.email);
  if (body?.email !== undefined && !email) return c.json({ error: EMAIL_ERROR }, 400);
  const phone = optionalField(body, "phone", (v) => PHONE_RE.test(v));
  if (phone === "invalid") return c.json({ error: PHONE_ERROR }, 400);
  const photoKey = optionalField(body, "photoKey", (v) => v.startsWith("users/"));
  if (photoKey === "invalid") return c.json({ error: "photoKey must be an uploaded user photo" }, 400);

  await c.env.DB.prepare(
    `UPDATE users SET
       email = COALESCE(?, email),
       phone = CASE WHEN ? THEN ? ELSE phone END,
       photo_key = CASE WHEN ? THEN ? ELSE photo_key END
     WHERE id = ?`
  )
    .bind(email, phone !== undefined ? 1 : 0, phone ?? null, photoKey !== undefined ? 1 : 0, photoKey ?? null, c.get("user").id)
    .run();

  const user = await c.env.DB.prepare(`SELECT ${USER_COLUMNS} FROM users WHERE id = ?`)
    .bind(c.get("user").id)
    .first<UserRow>();
  return c.json({ user: publicUser(user!) });
});

// Any signed-in user saves their own app language.
userRoutes.put("/me/language", async (c) => {
  const body = await c.req.json().catch(() => null);
  const language = body?.language;
  if (!LANGUAGES.includes(language)) return c.json({ error: "language must be ar or en" }, 400);
  await c.env.DB.prepare("UPDATE users SET language = ? WHERE id = ?").bind(language, c.get("user").id).run();
  return c.json({ language });
});

// The signed-in user's own record: the profile page and the account menu
// read it, so a moderator's edits show up without signing in again.
userRoutes.get("/me", async (c) => {
  const user = await c.env.DB.prepare(`SELECT ${USER_COLUMNS} FROM users WHERE id = ?`)
    .bind(c.get("user").id)
    .first<UserRow>();
  if (!user) return c.json({ error: "User not found" }, 404);
  return c.json({ user: publicUser(user) });
});

// One user's card (name, role, email, phone, photo) for the user popup.
// Technicians never see other users' details.
userRoutes.get("/:id", requireRole("moderator", "engineer"), async (c) => {
  const user = await c.env.DB.prepare(`SELECT ${USER_COLUMNS} FROM users WHERE id = ?`)
    .bind(c.req.param("id"))
    .first<UserRow>();
  if (!user) return c.json({ error: "User not found" }, 404);
  return c.json({ user: publicUser(user) });
});

userRoutes.use("*", requireRole("moderator"));

userRoutes.get("/", async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT ${USER_COLUMNS} FROM users WHERE is_active = 1
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
  const phone = optionalField(body, "phone", (v) => PHONE_RE.test(v));
  const photoKey = optionalField(body, "photoKey", (v) => v.startsWith("users/"));
  const role = body?.role;

  if (!USERNAME_RE.test(username)) {
    return c.json({ error: "username must be 3-32 chars: lowercase letters, digits, _ or ." }, 400);
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    return c.json({ error: `password must be at least ${MIN_PASSWORD_LENGTH} characters` }, 400);
  }
  if (!fullName) return c.json({ error: "fullName is required" }, 400);
  if (!email) return c.json({ error: EMAIL_ERROR }, 400);
  if (phone === "invalid") return c.json({ error: PHONE_ERROR }, 400);
  if (photoKey === "invalid") return c.json({ error: "photoKey must be an uploaded user photo" }, 400);
  if (!ROLES.includes(role)) return c.json({ error: "role must be engineer or technician" }, 400);

  const existing = await c.env.DB.prepare("SELECT id, is_active FROM users WHERE username = ?")
    .bind(username)
    .first<{ id: string; is_active: number }>();
  if (existing?.is_active) return c.json({ error: "username already exists" }, 409);
  if (existing) {
    // A deleted account being re-created: revive it under the same id so
    // its historical readings keep pointing at it.
    await c.env.DB.prepare(
      "UPDATE users SET password_hash = ?, full_name = ?, email = ?, phone = ?, photo_key = ?, role = ?, is_active = 1 WHERE id = ?"
    )
      .bind(await hashPassword(password), fullName, email, phone ?? null, photoKey ?? null, role, existing.id)
      .run();
    return c.json({ id: existing.id }, 201);
  }

  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  await c.env.DB.prepare(
    "INSERT INTO users (id, username, password_hash, full_name, email, phone, photo_key, role, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)"
  )
    .bind(id, username, await hashPassword(password), fullName, email, phone ?? null, photoKey ?? null, role, now)
    .run();

  return c.json({ id }, 201);
});

// Edits name / email / phone / photo / role / active flag, and optionally
// resets the password. phone / photoKey: absent = unchanged, null = clear.
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
  const phone = optionalField(body, "phone", (v) => PHONE_RE.test(v));
  if (phone === "invalid") return c.json({ error: PHONE_ERROR }, 400);
  const photoKey = optionalField(body, "photoKey", (v) => v.startsWith("users/"));
  if (photoKey === "invalid") return c.json({ error: "photoKey must be an uploaded user photo" }, 400);
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
       phone = CASE WHEN ? THEN ? ELSE phone END,
       photo_key = CASE WHEN ? THEN ? ELSE photo_key END,
       role = COALESCE(?, role),
       is_active = COALESCE(?, is_active),
       password_hash = COALESCE(?, password_hash)
     WHERE id = ?`
  )
    .bind(
      fullName,
      email,
      phone !== undefined ? 1 : 0,
      phone ?? null,
      photoKey !== undefined ? 1 : 0,
      photoKey ?? null,
      role,
      isActive,
      passwordHash,
      id
    )
    .run();

  return c.json({ ok: true });
});
