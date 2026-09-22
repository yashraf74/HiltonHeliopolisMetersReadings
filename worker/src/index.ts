import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Env } from "./types";
import type { AuthedVars } from "./middleware";
import { authRoutes } from "./routes/auth";
import { meterRoutes } from "./routes/meters";
import { readingRoutes } from "./routes/readings";
import { photoRoutes } from "./routes/photos";
import { userRoutes } from "./routes/users";
import { dashboardRoutes } from "./routes/dashboard";
import { settingsRoutes } from "./routes/settings";
import { exportRoutes } from "./routes/exports";
import { appGate } from "./middleware";
import { purgeExpiredPhotos } from "./purge";

const app = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

app.use("*", cors());

app.get("/api/health", (c) => c.json({ status: "ok" }));

// Settings + minimum-version gate for everything else under /api.
app.use("/api/*", appGate);

app.route("/api/auth", authRoutes);
app.route("/api/meters", meterRoutes);
app.route("/api/readings", readingRoutes);
app.route("/api/photos", photoRoutes);
app.route("/api/users", userRoutes);
app.route("/api/dashboard", dashboardRoutes);
app.route("/api/exports", exportRoutes);
app.route("/api", settingsRoutes);

app.notFound((c) => c.json({ error: "Not found" }, 404));

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: "Internal server error" }, 500);
});

const handler: ExportedHandler<Env> = {
  fetch: (request, env, ctx) => app.fetch(request, env, ctx),
  // Weekly photo purge; schedule lives in wrangler.toml [triggers].
  scheduled: (_event, env, ctx) => {
    ctx.waitUntil(purgeExpiredPhotos(env));
  },
};

export default handler;
