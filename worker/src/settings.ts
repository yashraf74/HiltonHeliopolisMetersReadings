import type { Env, Settings } from "./types";

export const SETTINGS_KEYS = [
  "min_app_version",
  "maintenance_mode",
  "reading_delete_enabled",
  "export_enabled",
  "photo_retention_days",
] as const;
export type SettingsKey = (typeof SETTINGS_KEYS)[number];

export const DEFAULT_SETTINGS: Settings = {
  minAppVersion: "0.0.0",
  maintenanceMode: false,
  readingDeleteEnabled: true,
  exportEnabled: true,
  photoRetentionDays: 90,
};

function bool(v: string | null, fallback: boolean): boolean {
  if (v === null) return fallback;
  return v === "true" || v === "1";
}

function int(v: string | null, fallback: number): number {
  const n = Number(v);
  return v !== null && Number.isInteger(n) && n > 0 ? n : fallback;
}

/** One KV round-trip per request (KV is edge-cached; values are tiny). */
export async function loadSettings(env: Env): Promise<Settings> {
  const [minVersion, maintenance, del, exp, retention] = await Promise.all(
    SETTINGS_KEYS.map((k) => env.SETTINGS.get(k))
  );
  return {
    minAppVersion: minVersion?.trim() || DEFAULT_SETTINGS.minAppVersion,
    maintenanceMode: bool(maintenance, DEFAULT_SETTINGS.maintenanceMode),
    readingDeleteEnabled: bool(del, DEFAULT_SETTINGS.readingDeleteEnabled),
    exportEnabled: bool(exp, DEFAULT_SETTINGS.exportEnabled),
    photoRetentionDays: int(retention, DEFAULT_SETTINGS.photoRetentionDays),
  };
}

export async function saveSettings(env: Env, s: Settings): Promise<void> {
  await Promise.all([
    env.SETTINGS.put("min_app_version", s.minAppVersion),
    env.SETTINGS.put("maintenance_mode", String(s.maintenanceMode)),
    env.SETTINGS.put("reading_delete_enabled", String(s.readingDeleteEnabled)),
    env.SETTINGS.put("export_enabled", String(s.exportEnabled)),
    env.SETTINGS.put("photo_retention_days", String(s.photoRetentionDays)),
  ]);
}

/** "2.1.0" style comparison; missing parts count as 0. */
export function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map((x) => parseInt(x, 10) || 0);
  const pb = b.split(".").map((x) => parseInt(x, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
}

export const UPGRADE_REQUIRED_MESSAGE = "يرجى تحديث التطبيق إلى أحدث إصدار";
export const MAINTENANCE_MESSAGE = "التطبيق قيد الصيانة حاليًا، يرجى المحاولة لاحقًا";
