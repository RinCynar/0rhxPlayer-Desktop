import { convertFileSrc } from '@tauri-apps/api/core';

/**
 * Safely converts a local file path to a streaming asset protocol URL
 */
export function getCoverSrc(coverUrl?: string | null): string | undefined {
  if (!coverUrl) return undefined;
  if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://') || coverUrl.startsWith('asset://')) {
    return coverUrl;
  }
  try {
    return convertFileSrc(coverUrl);
  } catch {
    return coverUrl;
  }
}
