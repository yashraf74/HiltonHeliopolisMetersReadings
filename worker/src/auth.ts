// Password hashing and JWTs implemented directly on Web Crypto (available in the
// Workers runtime) instead of a library, since native bindings like bcrypt don't
// run inside a Workers isolate.

const PBKDF2_ITERATIONS = 100_000;

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

function fromBase64(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function toBase64Url(bytes: Uint8Array): string {
  return toBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(b64url: string): Uint8Array {
  const padded = b64url.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  return fromBase64(padded + pad);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return result === 0;
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: PBKDF2_ITERATIONS, hash: "SHA-256" },
    keyMaterial,
    256
  );
  return `pbkdf2$${PBKDF2_ITERATIONS}$${toBase64(salt)}$${toBase64(new Uint8Array(bits))}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split("$");
  if (parts.length !== 4 || parts[0] !== "pbkdf2") return false;
  const [, iterStr, saltB64, hashB64] = parts;
  const iterations = Number(iterStr);
  const salt = fromBase64(saltB64);

  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
    keyMaterial,
    256
  );
  return timingSafeEqual(toBase64(new Uint8Array(bits)), hashB64);
}

// Bumped when the meaning of a claim changes (e.g. the role rename); tokens
// issued with an older version are rejected so every client signs in again.
export const TOKEN_VERSION = 2;

export interface JwtPayload {
  sub: string;
  username: string;
  fullName: string;
  role: "moderator" | "engineer" | "technician";
  ver?: number;
  iat?: number;
  exp?: number;
}

/** [lifetimeDays] comes from the tokenLifetimeDays setting (default 7). */
export async function signJwt(
  payload: Omit<JwtPayload, "iat" | "exp" | "ver">,
  secret: string,
  lifetimeDays: number
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const fullPayload: JwtPayload = { ...payload, ver: TOKEN_VERSION, iat: now, exp: now + lifetimeDays * 86_400 };

  const encHeader = toBase64Url(new TextEncoder().encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const encPayload = toBase64Url(new TextEncoder().encode(JSON.stringify(fullPayload)));
  const data = `${encHeader}.${encPayload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));

  return `${data}.${toBase64Url(new Uint8Array(signature))}`;
}

export async function verifyJwt(token: string, secret: string): Promise<JwtPayload | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [encHeader, encPayload, encSignature] = parts;
  const data = `${encHeader}.${encPayload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    fromBase64Url(encSignature),
    new TextEncoder().encode(data)
  );
  if (!valid) return null;

  const payload = JSON.parse(new TextDecoder().decode(fromBase64Url(encPayload))) as JwtPayload;
  if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
  if (payload.ver !== TOKEN_VERSION) return null;
  return payload;
}
