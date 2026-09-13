import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth } from "../middleware";

const EXT_BY_CONTENT_TYPE: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

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

  const key = `readings/${crypto.randomUUID()}.${ext}`;
  await c.env.PHOTOS.put(key, c.req.raw.body, { httpMetadata: { contentType } });

  return c.json({ photoKey: key }, 201);
});

photoRoutes.get("/", async (c) => {
  const key = c.req.query("key");
  if (!key) return c.json({ error: "key query param is required" }, 400);

  const object = await c.env.PHOTOS.get(key);
  if (!object) return c.json({ error: "Photo not found" }, 404);

  return new Response(object.body, {
    headers: { "Content-Type": object.httpMetadata?.contentType ?? "application/octet-stream" },
  });
});
