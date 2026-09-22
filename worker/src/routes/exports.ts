import { Hono } from "hono";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth } from "../middleware";
import { PLACEHOLDER_EMAIL } from "./users";

export const exportRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

exportRoutes.use("*", requireAuth);

const XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
/** Base64 of about 10 MB — far above a readings export, below Mailjet's 15 MB. */
const MAX_CONTENT_LENGTH = 14_000_000;
const FILE_NAME_RE = /^[^/\\]{1,120}\.xlsx$/;
const BASE64_RE = /^[A-Za-z0-9+/]+={0,2}$/;
const SENDER_NAME = "Hilton Heliopolis Meters";

// POST /api/exports/email { fileName, content: base64 .xlsx }
// Emails the workbook the app built to the signed-in user's own address,
// from MAIL_FROM through Mailjet's Send API v3.1.
exportRoutes.post("/email", async (c) => {
  if (!c.get("settings").exportEnabled) {
    return c.json({ error: "Export is disabled", code: "export_disabled" }, 403);
  }
  const { MAIL_FROM, MAILJET_API_KEY, MAILJET_SECRET_KEY } = c.env;
  if (!MAIL_FROM || !MAILJET_API_KEY || !MAILJET_SECRET_KEY) {
    return c.json({ error: "Email sending is not configured", code: "email_not_configured" }, 503);
  }

  const body = await c.req.json().catch(() => null);
  const fileName = typeof body?.fileName === "string" && FILE_NAME_RE.test(body.fileName) ? body.fileName : null;
  const content = typeof body?.content === "string" ? body.content : "";
  if (!fileName) return c.json({ error: "fileName must end in .xlsx" }, 400);
  if (!content || content.length > MAX_CONTENT_LENGTH || !BASE64_RE.test(content)) {
    return c.json({ error: "content must be a base64 .xlsx under 10 MB" }, 400);
  }

  const user = await c.env.DB.prepare("SELECT email, full_name FROM users WHERE id = ?")
    .bind(c.get("user").id)
    .first<{ email: string; full_name: string }>();
  if (!user || user.email === PLACEHOLDER_EMAIL) {
    return c.json({ error: "No email address is set for your account", code: "no_email" }, 400);
  }

  const res = await fetch("https://api.mailjet.com/v3.1/send", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${MAILJET_API_KEY}:${MAILJET_SECRET_KEY}`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      Messages: [
        {
          From: { Email: MAIL_FROM, Name: SENDER_NAME },
          To: [{ Email: user.email, Name: user.full_name }],
          Subject: `Meter readings export - ${fileName.replace(/\.xlsx$/, "")}`,
          TextPart: `مرفق ملف القراءات (${fileName}) الذي طلبته من تطبيق عدادات هيلتون.\n\nThe readings export you requested from the Hilton Heliopolis Meters app is attached.`,
          Attachments: [{ ContentType: XLSX_MIME, Filename: fileName, Base64Content: content }],
        },
      ],
    }),
  }).catch((err: unknown) => {
    console.error("export email failed", err);
    return null;
  });
  const result = res ? ((await res.json().catch(() => null)) as { Messages?: { Status?: string }[] } | null) : null;
  if (!res?.ok || result?.Messages?.[0]?.Status !== "success") {
    console.error("export email rejected", res?.status, JSON.stringify(result));
    return c.json({ error: "Could not send the email", code: "email_failed" }, 502);
  }

  return c.json({ sentTo: user.email });
});
