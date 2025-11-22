# Build Configuration Guide - SniffTest iOS App

**Last Updated:** January 27, 2025  
**Purpose:** Guide for managing API keys and build configurations for Debug and Release builds

---

## Overview

This guide explains how to manage API keys and build configurations for the SniffTest iOS app. The app uses different API keys for development/testing and production environments.

---

## Current Configuration

### API Keys Location

All API keys are stored in `SniffTest/App/Info.plist` and accessed via `Configuration.swift`.

**Current Keys in Info.plist:**
- `REVENUECAT_PUBLIC_SDK_KEY` - Currently set to test key
- `POSTHOG_API_KEY` - Analytics key
- `SUPABASE_ANON_KEY` - Supabase anonymous key (public by design)
- `API_BASE_URL` - Backend API URL

---

## ⚠️ Critical: Before App Store Submission

### Required Changes

1. **RevenueCat API Key**
   - Current: `test_MOlfphEwuRvEwGfgBdUDfjZFgVJ` (test key)
   - Action: Replace with production key from RevenueCat dashboard
   - Location: `Info.plist` → `REVENUECAT_PUBLIC_SDK_KEY`

2. **PostHog API Key**
   - Current: `phc_6pUTdgcLxEx8GfgBdUDfjZFgVJ`
   - Action: Verify this is the production key (keys starting with `phc_` are typically production)
   - Location: `Info.plist` → `POSTHOG_API_KEY`

3. **API Base URL**
   - Current: `https://snifftest-api-production.up.railway.app/api/v1`
   - Action: Verify this is correct for production
   - Location: `Info.plist` → `API_BASE_URL`

---

## Build Configuration Strategy

### Option 1: Manual Update (Current Approach)

**Pros:** Simple, no build scripts needed  
**Cons:** Manual step before each release, risk of shipping test keys

**Process:**
1. Before creating Release build, update `Info.plist` with production keys
2. Build Release configuration
3. After release, restore test keys for development

### Option 2: Separate Info.plist Files (Recommended)

**Pros:** Automatic switching based on configuration, no manual steps  
**Cons:** Requires maintaining two files

**Implementation:**

1. Create `Info-Release.plist` with production keys
2. Update `project.pbxproj` to use different Info.plist per configuration
3. Set build setting: `INFOPLIST_FILE` = `$(SRCROOT)/SniffTest/App/Info-$(CONFIGURATION).plist`

### Option 3: Build Settings with User-Defined Keys

**Pros:** Centralized configuration in Xcode  
**Cons:** Requires Xcode project changes

**Implementation:**

1. Add user-defined build settings:
   - `REVENUECAT_PUBLIC_SDK_KEY_DEBUG` = `test_MOlfphEwuRvEwGfgBdUDfjZFgVJ`
   - `REVENUECAT_PUBLIC_SDK_KEY_RELEASE` = `[PRODUCTION_KEY]`
   
2. Use build script to inject into Info.plist

---

## Step-by-Step: Creating Release Build

### Before Building for App Store

1. **Backup Current Info.plist**
   ```bash
   cp SniffTest/App/Info.plist SniffTest/App/Info.plist.backup
   ```

2. **Update Production Keys in Info.plist**
   - Open `SniffTest/App/Info.plist`
   - Update `REVENUECAT_PUBLIC_SDK_KEY` with production key
   - Verify all other keys are correct

3. **Verify Entitlements**
   - Open `SniffTest/SniffTest.entitlements`
   - Ensure `aps-environment` = `production` for Release builds

4. **Build Release Configuration**
   - In Xcode: Product → Scheme → Edit Scheme
   - Set Build Configuration to "Release"
   - Archive the app

5. **After Release Build**
   - Restore backup if needed for development
   - Document which keys were used in the release

---

## Recommended Implementation: Separate Info.plist Files

### Step 1: Create Info-Release.plist

Copy `Info.plist` to `Info-Release.plist` and update with production keys:

```xml
<key>REVENUECAT_PUBLIC_SDK_KEY</key>
<string>YOUR_PRODUCTION_REVENUECAT_KEY</string>
```

### Step 2: Update Xcode Project

1. Open `snifftest.xcodeproj` in Xcode
2. Select project in navigator
3. Select SniffTest target
4. Go to Build Settings
5. Search for "Info.plist File"
6. For Debug: `SniffTest/App/Info.plist`
7. For Release: `SniffTest/App/Info-Release.plist`

### Step 3: Add Info-Release.plist to Project

1. Right-click on `SniffTest/App/` folder
2. Add Files to "SniffTest"...
3. Select `Info-Release.plist`
4. Ensure it's added to target

---

## Security Best Practices

### ✅ DO:
- Keep test keys in Debug builds only
- Use production keys only in Release builds
- Store production keys securely (not in git if sensitive)
- Use environment variables for CI/CD pipelines
- Document key locations and update process

### ❌ DON'T:
- Commit production keys to git (if highly sensitive)
- Share keys in screenshots or documentation
- Use test keys in App Store builds
- Hardcode keys in Swift files
- Leave keys in Info.plist comments

---

## Current Keys Status

### Test/Development Keys
- ✅ RevenueCat: `test_MOlfphEwuRvEwGfgBdUDfjZFgVJ` (test key - OK for dev)
- ✅ API Base URL: Can use localhost in Debug

### Production Keys (Verify Before Release)
- ⚠️ RevenueCat: **MUST UPDATE** - Replace test key with production key
- ✅ PostHog: Verify key is production
- ✅ Supabase: Anonymous key (public by design - OK)
- ✅ API Base URL: Verify production URL is correct

---

## Environment Detection

The app automatically detects environment via `Configuration.swift`:

```swift
static var environment: AppEnvironment {
    #if DEBUG
    return .development
    #else
    return .production
    #endif
}
```

This allows runtime behavior changes based on build configuration.

---

## Verification Checklist

Before submitting to App Store:

- [ ] RevenueCat key is production (not test key)
- [ ] API Base URL points to production server
- [ ] PostHog key is production key
- [ ] All keys are verified in Info.plist
- [ ] Release build tested with production keys
- [ ] Entitlements set to production for Release
- [ ] No debug/test code in Release build
- [ ] Privacy manifest included

---

## Troubleshooting

### Issue: Test keys in production build

**Solution:** 
1. Verify `INFOPLIST_FILE` build setting
2. Check which Info.plist is being used
3. Ensure Release configuration uses production keys

### Issue: Missing keys at runtime

**Solution:**
1. Verify keys are in correct Info.plist file
2. Check `Configuration.swift` fallback values
3. Validate keys aren't empty strings

### Issue: Keys exposed in app bundle

**Solution:**
- Info.plist values are in app bundle (expected)
- Use server-side API keys for sensitive operations
- Implement rate limiting on backend
- RevenueCat/PostHog keys are designed to be client-side

---

## Additional Resources

- [Apple: Managing App Configuration Data](https://developer.apple.com/documentation/xcode/managing-app-configuration-data)
- [RevenueCat: API Keys Guide](https://docs.revenuecat.com/docs/api-keys)
- [PostHog: API Keys](https://posthog.com/docs/api/api-keys)

---

## Notes

- Supabase anonymous key is intentionally public (designed for client-side use)
- RevenueCat public SDK key is also designed for client-side use
- PostHog API key should be limited to client-side analytics only
- Always use rate limiting and validation on backend

---

**Next Steps:**
1. Create `Info-Release.plist` with production keys
2. Update Xcode project to use separate Info.plist per configuration
3. Test Release build with production keys
4. Document production key locations securely

