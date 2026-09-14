import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth } from "../middleware";

const EXT_BY_CONTENT_TYPE: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

const MAX_PHOTO_BYTES = 3 * 1024 * 1024;

export const photoRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

photoRoutes.use("*", requireAuth);

// The app uploads the raw photo bytes here; the server picks the storage key
// so a client can never overwrite another photo by guessing/reusing a key.
photoRoutes.post("/", async (c) => {
  const contentType = c.req.header("Content-Type") ?? "";
  const ext = EXT_BY_CONTENT_TYPE[contentType];
  if (!ext) {
    return c.json({ error: "Content-Type must be image/jpeg, image/png or image/webp" }, 400);
  }
  if (!c.req.raw.body) return c.json({ error: "Missing photo body" }, 400);

  const declared = Number(c.req.header("Content-Length") ?? "0");
  if (declared > MAX_PHOTO_BYTES) {
    return c.json({ error: `Photo exceeds the ${MAX_PHOTO_BYTES / 1024 / 1024} MB limit` }, 413);
  }
  // Buffer rather than stream so the limit holds even without a
  // Content-Length header; 3 MB is well within a Worker's memory budget.
  const bytes = await c.req.raw.arrayBuffer();
  if (bytes.byteLength === 0) return c.json({ error: "Missing photo body" }, 400);
  if (bytes.byteLength > MAX_PHOTO_BYTES) {
    return c.json({ error: `Photo exceeds the ${MAX_PHOTO_BYTES / 1024 / 1024} MB limit` }, 413);
  }

  const kind = c.req.query("kind") === "meter" ? "meters" : "readings";
  if (kind === "meters" && c.get("user").role !== "engineer") {
    return c.json({ error: "Forbidden" }, 403);
  }
  const key = `${kind}/${crypto.randomUUID()}.${ext}`;
  await c.env.PHOTOS.put(key, bytes, { httpMetadata: { contentType } });

  return c.json({ photoKey: key }, 201);
});

photoRoutes.get("/", async (c) => {
  const key = c.req.query("key");
  if (!key) return c.json({ error: "key query param is required" }, 400);
  if (key.startsWith("meters/") && c.get("user").role !== "engineer") {
    return c.json({ error: "Forbidden" }, 403);
  }

  const object = await c.env.PHOTOS.get(key);
  if (!object) return c.json({ error: "Photo not found" }, 404);

  return new Response(object.body, {
    headers: { "Content-Type": object.httpMetadata?.contentType ?? "application/octet-stream" },
  });
});
