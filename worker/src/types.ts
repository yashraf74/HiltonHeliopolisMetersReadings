export type Role = "moderator" | "engineer" | "technician";

export interface Env {
  DB: D1Database;
  PHOTOS: R2Bucket;
  SETTINGS: KVNamespace;
  JWT_SECRET: string;
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
}
