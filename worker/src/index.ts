import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Env } from "./types";
import type { AuthedVars } from "./middleware";
import { authRoutes } from "./routes/auth";
import { meterRoutes } from "./routes/meters";
import { readingRoutes } from "./routes/readings";
import { photoRoutes } from "./routes/photos";
import { userRoutes } from "./routes/users";

const app = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

app.use("*", cors());

app.get("/api/health", (c) => c.json({ status: "ok" }));

app.route("/api/auth", authRoutes);
app.route("/api/meters", meterRoutes);
app.route("/api/readings", readingRoutes);
app.route("/api/photos", photoRoutes);
app.route("/api/users", userRoutes);

app.notFound((c) => c.json({ error: "Not found" }, 404));

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: "Internal server error" }, 500);
});

export default app;
