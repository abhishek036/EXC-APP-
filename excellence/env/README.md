# Backend Environment Profiles

Use the same profile for both Chrome and APK to avoid account/data mismatch.

## Cloudflare tunnel backend

- Run Chrome:
  flutter run -d chrome --dart-define-from-file=env/cloudflare.json
- Build APK:
  flutter build apk --release --dart-define-from-file=env/cloudflare.json

## Production droplet backend

- Run Chrome:
  flutter run -d chrome --dart-define-from-file=env/production.json
- Build APK:
  flutter build apk --release --dart-define-from-file=env/production.json

This profile targets `https://api.excellenceacademy.site/api/`.

## Important

Cloudflare quick tunnel URLs are temporary. If tunnel URL changes, update env/cloudflare.json and rebuild APK.

## Local backend on same Wi-Fi (LAN)

Use this when phone and backend machine are on the same network.

- Run Chrome:
  flutter run -d chrome --dart-define-from-file=env/local_lan.json
- Build APK:
  flutter build apk --release --dart-define-from-file=env/local_lan.json

If local IP changes, update env/local_lan.json and rebuild APK.
