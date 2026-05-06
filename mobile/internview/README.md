# Internview (Flutter)

Backend API Gateway üzerinden çalışan Internview mobil istemcisi.

## Çalıştırma

API tabanı `--dart-define` ile verilir:

```bash
cd mobile/internview

# Android emülatör (host makinedeki gateway:8080 → 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# iOS simülatör (aynı makinede gateway)
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Varsayılan olmayan URL için `lib/core/config/env.dart` içinde tanımlı sabite bakın.

## Test

```bash
flutter test
```

## Notlar

- Ağ güvenliği: Android’de `network_security_config` ile `10.0.2.2` / `localhost` üzerinde cleartext (HTTP) geliştirme trafiğine izin verilir; üretimde HTTPS kullanın.
- Mülakat odası: kamera ve mikrofon izinleri gerekir (`permission_handler` + manifest/Info.plist).
