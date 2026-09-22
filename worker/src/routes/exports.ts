import { Hono } from "hono";
import { WorkerMailer } from "worker-mailer";
import type { Env } from "../types";
import type { AuthedVars } from "../middleware";
import { requireAuth } from "../middleware";
import { PLACEHOLDER_EMAIL } from "./users";

export const exportRoutes = new Hono<{ Bindings: Env; Variables: AuthedVars }>();

exportRoutes.use("*", requireAuth);

const XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
/** Base64 of about 10 MB — far above a readings export, below Gmail's 25 MB. */
const MAX_CONTENT_LENGTH = 14_000_000;
const FILE_NAME_RE = /^[^/\\]{1,120}\.xlsx$/;
const BASE64_RE = /^[A-Za-z0-9+/]+={0,2}$/;
const SENDER_NAME = "Hilton Heliopolis Meters";

// POST /api/exports/email { fileName, content: base64 .xlsx }
// Emails the workbook the app built to the signed-in user's own address,
// from the Gmail account in GMAIL_USER / GMAIL_APP_PASSWORD.
exportRoutes.post("/email", async (c) => {
  if (!c.get("settings").exportEnabled) {
    return c.json({ error: "Export is disabled", code: "export_disabled" }, 403);
  }
  const { GMAIL_USER, GMAIL_APP_PASSWORD } = c.env;
  if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
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

  let mailer: WorkerMailer | null = null;
  try {
    mailer = await WorkerMailer.connect({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      credentials: { username: GMAIL_USER, password: GMAIL_APP_PASSWORD },
      authType: "plain",
    });
    await mailer.send({
      from: { name: SENDER_NAME, email: GMAIL_USER },
      to: { name: user.full_name, email: user.email },
      subject: `تقرير القراءات - ${fileName.replace(/\.xlsx$/, "")}`,
      text: `مرفق ملف القراءات (${fileName}) الذي طلبته من تطبيق عدادات هيلتون.\n\nThe readings export you requested from the Hilton Heliopolis Meters app is attached.`,
      attachments: [{ filename: fileName, content, mimeType: XLSX_MIME }],
    });
  } catch (err) {
    console.error("export email failed", err);
    return c.json({ error: "Could not send the email", code: "email_failed" }, 502);
  } finally {
    await mailer?.close().catch(() => undefined);
  }

  return c.json({ sentTo: user.email });
});
