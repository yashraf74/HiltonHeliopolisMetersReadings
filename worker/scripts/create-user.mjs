#!/usr/bin/env node
// Prints an INSERT statement for a new user, hashed the same way src/auth.ts
// verifies it (PBKDF2-SHA256, 100k iterations). Run the printed statement
// against D1 with `wrangler d1 execute`.
import { randomUUID } from "node:crypto";
import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PBKDF2_ITERATIONS = 100_000;

async function hashPassword(password) {
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
  const toB64 = (bytes) => Buffer.from(bytes).toString("base64");
  return `pbkdf2$${PBKDF2_ITERATIONS}$${toB64(salt)}$${toB64(new Uint8Array(bits))}`;
}

const [, , username, password, fullName, role] = process.argv;

if (!username || !password || !fullName || !role) {
  console.error('Usage: npm run create-user -- <username> <password> "<full name>" <engineer|technician>');
  process.exit(1);
}
if (!["engineer", "technician"].includes(role)) {
  console.error('role must be "engineer" or "technician"');
  process.exit(1);
}

const id = randomUUID();
const hash = await hashPassword(password);
const now = new Date().toISOString();
const esc = (s) => s.replace(/'/g, "''");

const sql = `INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at) VALUES ('${id}', '${esc(username)}', '${hash}', '${esc(fullName)}', '${role}', 1, '${now}');`;

// Written to a file rather than printed as a --command argument: the hash
// contains `$`, which a shell would expand inside double quotes and silently
// corrupt the stored password.
const outPath = join(tmpdir(), `create-user-${username}.sql`);
writeFileSync(outPath, sql + "\n");

console.log(sql);
console.log("\nRun it against the live database with:");
console.log(`  npx wrangler d1 execute DB --remote --file "${outPath}"`);
