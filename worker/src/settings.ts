import type { Env, ExportColumn, ExportSettings, Settings } from "./types";
import { EXPORT_COLUMNS, EXPORT_DATE_FORMATS } from "./types";

export const SETTINGS_KEYS = [
  "min_app_version",
  "maintenance_mode",
  "reading_delete_enabled",
  "export_enabled",
  "photo_retention_days",
  "token_lifetime_days",
  "profile_editing_enabled",
  "export_settings",
  "price_electricity",
  "price_water",
  "price_gas",
] as const;
export type SettingsKey = (typeof SETTINGS_KEYS)[number];

export const DEFAULT_SETTINGS: Settings = {
  minAppVersion: "0.0.0",
  maintenanceMode: false,
  readingDeleteEnabled: true,
  exportEnabled: true,
  photoRetentionDays: 90,
  tokenLifetimeDays: 7,
  profileEditingEnabled: true,
  export: {
    columns: [...EXPORT_COLUMNS],
    direction: "auto",
    dateFormat: EXPORT_DATE_FORMATS[0],
    decimals: 2,
    thousandsSeparator: true,
    sheetPerType: false,
  },
  prices: { electricity: 0, water: 0, gas: 0 },
};

function bool(v: string | null, fallback: boolean): boolean {
  if (v === null) return fallback;
  return v === "true" || v === "1";
}

function price(v: string | null): number {
  const n = Number(v);
  return v !== null && Number.isFinite(n) && n >= 0 ? n : 0;
}

/** Parses the stored export settings, falling back per field. */
export function parseExportSettings(raw: string | null): ExportSettings {
  const fallback = DEFAULT_SETTINGS.export;
  let value: Partial<ExportSettings>;
  try {
    value = raw ? (JSON.parse(raw) as Partial<ExportSettings>) : {};
  } catch {
    return { ...fallback, columns: [...fallback.columns] };
  }
  const columns = Array.isArray(value.columns)
    ? value.columns.filter((c): c is ExportColumn => (EXPORT_COLUMNS as readonly string[]).includes(c))
    : [];
  const decimals = Number(value.decimals);
  return {
    columns: columns.length ? [...new Set(columns)] : [...fallback.columns],
    direction: value.direction === "rtl" || value.direction === "ltr" ? value.direction : "auto",
    dateFormat: (EXPORT_DATE_FORMATS as readonly string[]).includes(value.dateFormat ?? "")
      ? value.dateFormat!
      : fallback.dateFormat,
    decimals: Number.isInteger(decimals) && decimals >= 0 && decimals <= 3 ? decimals : fallback.decimals,
    thousandsSeparator: typeof value.thousandsSeparator === "boolean" ? value.thousandsSeparator : fallback.thousandsSeparator,
    sheetPerType: typeof value.sheetPerType === "boolean" ? value.sheetPerType : fallback.sheetPerType,
  };
}

function int(v: string | null, fallback: number): number {
  const n = Number(v);
  return v !== null && Number.isInteger(n) && n > 0 ? n : fallback;
}

/** One KV round-trip per request (KV is edge-cached; values are tiny). */
export async function loadSettings(env: Env): Promise<Settings> {
  const [minVersion, maintenance, del, exp, retention, tokenDays, profileEditing, exportJson, pElectricity, pWater, pGas] = await Promise.all(
    SETTINGS_KEYS.map((k) => env.SETTINGS.get(k))
  );
  return {
    minAppVersion: minVersion?.trim() || DEFAULT_SETTINGS.minAppVersion,
    maintenanceMode: bool(maintenance, DEFAULT_SETTINGS.maintenanceMode),
    readingDeleteEnabled: bool(del, DEFAULT_SETTINGS.readingDeleteEnabled),
    exportEnabled: bool(exp, DEFAULT_SETTINGS.exportEnabled),
    photoRetentionDays: int(retention, DEFAULT_SETTINGS.photoRetentionDays),
    tokenLifetimeDays: int(tokenDays, DEFAULT_SETTINGS.tokenLifetimeDays),
    profileEditingEnabled: bool(profileEditing, DEFAULT_SETTINGS.profileEditingEnabled),
    export: parseExportSettings(exportJson),
    prices: { electricity: price(pElectricity), water: price(pWater), gas: price(pGas) },
  };
}

export async function saveSettings(env: Env, s: Settings): Promise<void> {
  await Promise.all([
    env.SETTINGS.put("min_app_version", s.minAppVersion),
    env.SETTINGS.put("maintenance_mode", String(s.maintenanceMode)),
    env.SETTINGS.put("reading_delete_enabled", String(s.readingDeleteEnabled)),
    env.SETTINGS.put("export_enabled", String(s.exportEnabled)),
    env.SETTINGS.put("photo_retention_days", String(s.photoRetentionDays)),
    env.SETTINGS.put("token_lifetime_days", String(s.tokenLifetimeDays)),
    env.SETTINGS.put("profile_editing_enabled", String(s.profileEditingEnabled)),
    env.SETTINGS.put("export_settings", JSON.stringify(s.export)),
    env.SETTINGS.put("price_electricity", String(s.prices.electricity)),
    env.SETTINGS.put("price_water", String(s.prices.water)),
    env.SETTINGS.put("price_gas", String(s.prices.gas)),
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
