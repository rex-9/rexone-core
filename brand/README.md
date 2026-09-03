# 🖼️ Brand Assets Directory

Place your primary product logo / app icon here:

- **Path**: `brand/logo.png`
- **Recommended Format**: PNG with transparency or solid background.
- **Recommended Resolution**: `1024x1024 px` (or minimum `512x512 px`).

---

### How it works:
When you run `./scripts/rebrand.sh`, the rebranding engine automatically takes `brand/logo.png` and:
1. **Mobile (`rexone_mobile`)**: Copies to `assets/icon/app_icon.png` and runs `flutter_launcher_icons` to generate all Android and iOS launcher icon sizes.
2. **Web (`rexone-web`)**: Copies to `public/favicon.png` for browser tab icons.
