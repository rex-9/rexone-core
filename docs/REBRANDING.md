# 🎨 Ecosystem Rebranding Guide

This guide describes how to transform the **RexOne Ecosystem** (`rexone-core`, `rexone-web`, `rexone_mobile`) into your own branded product using the master rebranding engine.

The engine is **100% brand-agnostic**, supports both single-word brands (e.g., `Nova`) and multi-word brands (e.g., `Pulse Flow`), and executes across all three repositories in a single run.

---

## 🏛️ Prerequisites & Workspace Layout

To rebrand the entire ecosystem simultaneously, keep the three repositories side-by-side inside your workspace directory:

```text
workspace/
├── <brand>-core/    # (or rexone-core)
├── <brand>-web/     # (or rexone-web)
└── <brand>-mobile/  # (or rexone_mobile)
```

The script automatically detects sibling directories matching `${BRAND_SLUG_KEBAB}-web`, `${BRAND_SLUG_KEBAB}-mobile`, or standard `rexone-web` and `rexone_mobile`.

---

## 🚀 3-Step Rebranding Workflow

### Step 1: Configure `brand.config.json`

In the root of the Core repository, edit `brand.config.json` (or copy one of the pre-made templates: `brand.single_word.json` or `brand.multi_word.json`):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "brand": {
    "name": "Nova",
    "slug": "nova",
    "shortName": "Nova",
    "description": "Next-Gen Cloud Collaboration Platform",
    "company": "Nova Technologies",
    "author": "Nova Team",
    "website": "https://nova.me",
    "domain": "nova.me",
    "supportEmail": "support@nova.me",
    "logoPath": "brand/logo.png"
  },
  "mobile": {
    "appName": "Nova Mobile",
    "packageName": "com.nova.app",
    "bundleId": "com.nova.app"
  },
  "web": {
    "appName": "Nova Web",
    "title": "Nova — Next-Gen Platform",
    "shortName": "Nova"
  },
  "core": {
    "appName": "Nova Core",
    "mailerSender": "support@nova.me"
  }
}
```

> [!TIP]
> Refer to [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md) to understand how `name` and `slug` automatically derive kebab-case (Docker), snake_case (Postgres/Dart), and flat lowercase (Bundle IDs) across the stack.

---

### Step 2: Add Your Brand Logo

Place your brand logo or app icon at:
- **Path**: `brand/logo.png` (in Core root)
- **Format**: 1024x1024 PNG (recommended)

The rebranding engine will automatically:
1. Copy the logo to Web (`public/brand/logo.png` and `public/favicon.png`).
2. Copy the logo to Mobile (`assets/brand/logo.png`).
3. Run `flutter_launcher_icons` to generate all required iOS and Android app launcher icons.

---

### Step 3: Run the Master Rebranding Engine

From the Core repository root, execute:

```bash
./scripts/rebrand.sh brand.config.json
```

That's it! In ~10 seconds, the engine synchronizes all three codebases.

---

## ⚡ What is Automated (100% Hands-Free)

| Component | Automated Synchronizations |
| :--- | :--- |
| **Core Backend** | • Updates `docker-compose.yaml` and `docker-compose.dev.yaml` container and volume names<br>• Updates database configs (`config/database.yml`)<br>• Updates Ruby module name (`config/application.rb`) and application fallbacks (`config/app_config.rb`)<br>• Updates Garage S3 storage configs and authentication tokens (`config/garage.toml`)<br>• Updates maintenance scripts (`backup_db.sh`, `backup_garage.sh`, `dev_garage.sh`)<br>• Updates notification templates, Swagger API title, and transactional email templates |
| **Web Client** | • Updates `package.json` project name (`<slug>-web`)<br>• Updates `AppConfig.tsx` default `APP_NAME` and `FROM_EMAIL`<br>• Updates React Query cache key (`<slug>_react_query_cache`)<br>• Updates English and Myanmar localization catalogs (`en.json`, `my.json`)<br>• Updates `docker-compose.yaml` and `docker-compose.dev.yaml`<br>• Updates deployment scripts (`scripts/uat.sh`, `scripts/prod.sh`)<br>• Copies and activates favicon and brand logo assets |
| **Mobile Client** | • Updates Android `namespace` and `applicationId` (both Production and UAT)<br>• Relocates Kotlin `MainActivity.kt` and Patrol `MainActivityTest.java` to match the new package path<br>• Updates iOS bundle identifier in `project.pbxproj` (App, Tests, and Widget Extension)<br>• Updates iOS `Info.plist` (`CFBundleDisplayName`, `CFBundleName`, custom URL scheme)<br>• Updates iOS App Group entitlements (`group.<package_name>`) and Swift ActionStore<br>• Updates `pubspec.yaml` package name and synchronizes **every Dart import statement** across `lib/`, `test/`, and `integration_test/`<br>• Updates Drift local offline SQLite database name (`<slug>_offline`)<br>• Updates secure storage salt seed and platform method channels<br>• Regenerates all Android & iOS app launcher icons |

---

## 📌 Critical Manual Actions Required (Security & Credentials)

In compliance with strict security protocols and Constitutional Law, the rebrand engine **never touches local credentials, gitignored files, or external third-party accounts**. Complete the following manual steps:

### 1. Local Environment Files (`.env`, `.env.dev`)
Local environment files are gitignored and intentionally untouched by automation. All committed `*.example` files strictly retain generic dummy placeholders per Constitutional Law 5.
- In **Core**: Configure `.env` with your brand domain, database name, and service keys.
- In **Web**: Configure `.env` with your backend API and WebSocket endpoints.
- In **Mobile**: Configure `.env.dev`, `.env.uat`, or `.env.prod` with your API URLs and credentials.

### 2. Firebase & Google SSO Configuration
Firebase and Google Cloud configuration files are platform-generated and gitignored:
1. In [Firebase Console](https://console.firebase.google.com/), create a new project matching your app name.
2. Add an **Android App** with your new `packageName` (e.g. `com.nova.app`) and download `google-services.json` -> place into `android/app/`.
3. Add an **iOS App** with your new `bundleId` (e.g. `com.nova.app`) and download `GoogleService-Info.plist` -> place into `ios/Runner/`.
4. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Copy your **Web Server Client ID** into `GOOGLE_SERVER_CLIENT_ID` in Web and Mobile.
   - For iOS: Retrieve your **iOS Client ID** and set the reversed client ID in `ios/Runner/Info.plist` under `CFBundleURLSchemes`.

### 3. Android Release Signing Keystore
Release keystores are encrypted secrets and not committed to git:
1. In the mobile repository, generate a release keystore:
   ```bash
   cd <brand>-mobile
   ./scripts/generate_keystore.sh
   ```
2. Create `android/key.properties` (see `android/keystores/key.properties.example`) containing your keystore password, key alias, and password.
   > [!NOTE]
   > Release builds (`flutter build apk --release`, `flutter build appbundle`) strictly enforce keystore validation and will fail fast if credentials are missing, preventing unverified or debug-signed builds from shipping to UAT or Google Play Store.

### 4. Web Landing Module & Custom SEO
- **Landing Page (`src/modules/landing`)**: Left completely intact. Since RexOne is a starter framework, developers replace the default landing page with their product-specific marketing interface.
- **SEO & AI Discovery (`index.html` metadata, `robots.txt`, `sitemap.xml`, `llms.txt`)**: Intentionally left untouched. Product positioning, Open Graph cards, Schema.org entities, and SEO keywords are 100% the developer's responsibility.

---

## ✅ Post-Rebrand Verification Checklist

Run these commands to verify that your new brand compiles cleanly:

```bash
# 1. Verify Core API & Docker
cd <brand>-core
docker compose -f docker-compose.dev.yaml config

# 2. Verify Web Client Build
cd ../<brand>-web
npm run build

# 3. Verify Mobile Analysis & Debug Compilation
cd ../<brand>-mobile
flutter pub get
dart analyze lib
flutter build apk --debug
```
