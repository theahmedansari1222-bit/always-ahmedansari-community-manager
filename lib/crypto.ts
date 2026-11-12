import "server-only";
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

function encryptionKey(): Buffer {
  const raw = process.env.TOKEN_ENCRYPTION_KEY;
  if (!raw) throw new Error("TOKEN_ENCRYPTION_KEY is not configured.");
  const key = Buffer.from(raw, "base64");
  if (key.length !== 32) throw new Error("TOKEN_ENCRYPTION_KEY must be 32 random bytes encoded as base64.");
  return key;
}

// Stored format: 12-byte IV + ciphertext + 16-byte GCM authentication tag.
export function encryptToken(value: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  return Buffer.concat([iv, ciphertext, cipher.getAuthTag()]).toString("hex");
}
export function decryptToken(hex: string): string {
  const payload = Buffer.from(hex, "hex");
  if (payload.length < 29) throw new Error("Encrypted token payload is invalid.");
  const iv = payload.subarray(0, 12);
  const tag = payload.subarray(payload.length - 16);
  const ciphertext = payload.subarray(12, payload.length - 16);
  const decipher = createDecipheriv("aes-256-gcm", encryptionKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString("utf8");
}
