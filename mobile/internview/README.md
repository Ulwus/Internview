# Internview (Flutter)

Backend API Gateway üzerinden çalışan Internview mobil istemcisi.

## Çalıştırma

API tabanı `--dart-define-from-file` ile **tek bir yerde** tutulur:

```bash
cd mobile/internview

# Android emülatör (host makinedeki gateway:8080 → 10.0.2.2)
bash scripts/run_android.sh

# iOS simülatör (aynı makinede gateway)
bash scripts/run_ios.sh
```

Değerler:

- `env/android.json`
- `env/ios.json`

Varsayılan olmayan URL için `lib/core/config/env.dart` içinde tanımlı sabite bakın.

## Test

```bash
flutter test
```

## Notlar

- Ağ güvenliği: Android’de `network_security_config` ile `10.0.2.2` / `localhost` üzerinde cleartext (HTTP) geliştirme trafiğine izin verilir; üretimde HTTPS kullanın.
- Mülakat odası: kamera ve mikrofon izinleri gerekir (`permission_handler` + manifest/Info.plist).
