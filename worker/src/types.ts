export type Role = "engineer" | "technician";

export interface Env {
  DB: D1Database;
  PHOTOS: R2Bucket;
  JWT_SECRET: string;
}

export interface AuthUser {
  id: string;
  username: string;
  fullName: string;
  role: Role;
}
