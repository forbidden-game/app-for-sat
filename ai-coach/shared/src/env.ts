import * as dotenv from "dotenv";

dotenv.config();

export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env var: ${name}`);
  return value;
}

export function readIntEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (Number.isNaN(parsed)) throw new Error(`Invalid int env var: ${name}=${raw}`);
  return parsed;
}

export function readStringEnv(name: string, fallback: string): string {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = raw.trim();
  return value.length > 0 ? value : fallback;
}

export function readBoolEnv(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (!raw) return fallback;
  const normalized = raw.trim().toLowerCase();
  if (["1", "true", "yes", "y"].includes(normalized)) return true;
  if (["0", "false", "no", "n"].includes(normalized)) return false;
  throw new Error(`Invalid bool env var: ${name}=${raw}`);
}

export function readCsvEnv(name: string): string[] | null {
  const raw = process.env[name];
  if (!raw) return null;
  const parts = raw
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  return parts.length > 0 ? parts : null;
}
