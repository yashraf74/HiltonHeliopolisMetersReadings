export type Role = "moderator" | "engineer" | "technician";

export interface Env {
  DB: D1Database;
  PHOTOS: R2Bucket;
  SETTINGS: KVNamespace;
  JWT_SECRET: string;
  /** Mailjet-verified sender exports are emailed from ([vars] in wrangler.toml). */
  MAIL_FROM?: string;
  /** Mailjet API key pair (wrangler secrets). Email is disabled without them. */
  MAILJET_API_KEY?: string;
  MAILJET_SECRET_KEY?: string;
}

export type Language = "ar" | "en";

/** Language used until a user picks one: English for moderators. */
export const defaultLanguage = (role: Role): Language => (role === "moderator" ? "en" : "ar");

export interface AuthUser {
  id: string;
  username: string;
  fullName: string;
  role: Role;
}

/** Roles that see every reading and may edit/delete any of them. */
export const READINGS_ADMIN_ROLES: Role[] = ["moderator", "engineer"];

/** Runtime switches, editable by moderators from the app (stored in KV). */
export interface Settings {
  minAppVersion: string;
  maintenanceMode: boolean;
  readingDeleteEnabled: boolean;
  exportEnabled: boolean;
  photoRetentionDays: number;
  /** How long a login stays valid, in days. */
  tokenLifetimeDays: number;
  /** Lets every user edit their own photo, email and mobile number. */
  profileEditingEnabled: boolean;
  /** How the app builds the Excel export. */
  export: ExportSettings;
  /** EGP per kWh / m³ for the dashboard cost chart; 0 = not set. */
  prices: Prices;
}

/** Columns the export can include, in the order they're offered. */
export const EXPORT_COLUMNS = [
  "logged_at",
  "meter_name",
  "meter_type",
  "meter_area",
  "meter_number",
  "value",
  "gain",
  "unit",
  "logged_by",
  "synced_at",
  "reading_id",
] as const;
export type ExportColumn = (typeof EXPORT_COLUMNS)[number];

/** Date patterns offered for export cells (intl/Excel-friendly). */
export const EXPORT_DATE_FORMATS = [
  "yyyy-MM-dd HH:mm",
  "dd/MM/yyyy HH:mm",
  "MM/dd/yyyy HH:mm",
  "yyyy-MM-dd",
  "dd/MM/yyyy",
] as const;

export interface ExportSettings {
  /** Selected columns, in export order. */
  columns: ExportColumn[];
  /** Sheet direction: follow the exporter's language, or force one. */
  direction: "auto" | "rtl" | "ltr";
  dateFormat: string;
  /** Decimal places for reading values (0-3). */
  decimals: number;
  thousandsSeparator: boolean;
  /** One sheet per meter type (tab named after the type) instead of one. */
  sheetPerType: boolean;
}

export interface Prices {
  electricity: number;
  water: number;
  gas: number;
}
