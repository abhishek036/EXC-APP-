import { Request, Response, NextFunction } from 'express';
import { sendResponse } from '../../utils/response';

type SupportedPlatform = 'android' | 'ios' | 'web';

function normalizeVersion(input: string): string {
  const cleaned = input.trim().replace(/[^0-9.]/g, '');
  return cleaned.length === 0 ? '0.0.0' : cleaned;
}

function compareVersions(a: string, b: string): number {
  const left = normalizeVersion(a).split('.').map((part) => Number.parseInt(part, 10) || 0);
  const right = normalizeVersion(b).split('.').map((part) => Number.parseInt(part, 10) || 0);
  const maxLen = Math.max(left.length, right.length);

  for (let index = 0; index < maxLen; index += 1) {
    const l = index < left.length ? left[index] : 0;
    const r = index < right.length ? right[index] : 0;
    if (l > r) return 1;
    if (l < r) return -1;
  }

  return 0;
}

function getPlatform(input: string | undefined): SupportedPlatform {
  const value = (input ?? '').toLowerCase();
  if (value === 'ios') return 'ios';
  if (value === 'web') return 'web';
  return 'android';
}

function envKey(platform: SupportedPlatform, field: 'MIN_VERSION' | 'LATEST_VERSION' | 'STORE_URL'): string {
  return `APP_${field}_${platform.toUpperCase()}`;
}

export class AppUpdateController {
  getPolicy = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const platform = getPlatform(req.query.platform?.toString());
      const currentVersion = (req.query.version?.toString() || '0.0.0').trim();

      const minSupportedVersion =
        process.env[envKey(platform, 'MIN_VERSION')] ||
        process.env.APP_MIN_VERSION ||
        '1.0.0';

      const latestVersion =
        process.env[envKey(platform, 'LATEST_VERSION')] ||
        process.env.APP_LATEST_VERSION ||
        minSupportedVersion;

      const storeUrl =
        process.env[envKey(platform, 'STORE_URL')] ||
        process.env.APP_STORE_URL ||
        '';

      const forceUpdate = compareVersions(currentVersion, minSupportedVersion) < 0;
      const recommendUpdate = !forceUpdate && compareVersions(currentVersion, latestVersion) < 0;

      return sendResponse({
        res,
        data: {
          platform,
          currentVersion,
          minSupportedVersion,
          latestVersion,
          forceUpdate,
          recommendUpdate,
          storeUrl,
        },
        message: 'App update policy fetched successfully',
      });
    } catch (error) {
      next(error);
    }
  };
}
