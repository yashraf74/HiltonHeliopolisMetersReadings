export type Role = "moderator" | "engineer" | "technician";

export interface Env {
  DB: D1Database;
  PHOTOS: R2Bucket;
  SETTINGS: KVNamespace;
  JWT_SECRET: string;
  /** Gmail account exports are emailed from ([vars] in wrangler.toml). */
  GMAIL_USER?: string;
  /** Its app password (wrangler secret). Email is disabled without both. */
  GMAIL_APP_PASSWORD?: string;
}

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
  /** EGP per kWh / m³ for the dashboard cost chart; 0 = not set. */
  prices: Prices;
}

export interface Prices {
  electricity: number;
  water: number;
  gas: number;
}
