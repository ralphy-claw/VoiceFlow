# Adding a New Variant

This guide explains how to add a new variant to VoiceFlow.

## Architecture

```
Configurations/
├── Base/                           # Shared settings (all variants)
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   └── Release.xcconfig
├── Variants/
│   └── VoiceFlow/                  # Default variant
│       ├── Config.xcconfig         # Brand-specific settings
│       ├── Debug.xcconfig          # Includes Base/Debug + Config
│       ├── Release.xcconfig        # Includes Base/Release + Config
│       └── Assets.xcassets/        # Variant-specific colors & icons
└── Scripts/
    └── copy-variant-resources.sh   # Copies resources at build time
```

## Steps

1. Create `Configurations/Variants/YourVariant/` folder
2. Create `Config.xcconfig` with brand values (bundle ID, display name, emails, etc.)
3. Create `Debug.xcconfig` that includes `../../Base/Debug.xcconfig` + `Config.xcconfig`
4. Create `Release.xcconfig` that includes `../../Base/Release.xcconfig` + `Config.xcconfig`
5. Create `Assets.xcassets/` with brand colors (BrandPrimary, BrandBackground, etc.)
6. In Xcode: duplicate Debug/Release configurations, link xcconfigs
7. Create a new scheme pointing to your configurations
8. Build and verify

## Config.xcconfig Template

```xcconfig
// Config.xcconfig - [VARIANT] Variant
APP_DISPLAY_NAME = [Display Name]
BRAND_IDENTIFIER = [VariantName]
DEVELOPMENT_TEAM = [TEAM_ID]
SUPPORT_EMAIL = [email]
BRAND_NAME = [Brand Name]
PREFERRED_COLOR_SCHEME = dark
WEBSITE_BASE_URL = https:/$()/example.com
```
