# SEO & Social Media Preview Improvements

## Summary
This document outlines the SEO improvements made to fix Twitter/X link previews and enhance overall SEO.

## Changes Made

### 1. Fixed Twitter/X Card Images
- **Issue**: Twitter/X requires absolute URLs for images, not relative paths
- **Solution**: Created utility function `getAbsoluteUrl()` to convert relative paths to absolute URLs
- **Files Updated**:
  - `app/layout.tsx`
  - `app/page.tsx`
  - `app/privacy/page.tsx`
  - `app/terms/page.tsx`

### 2. Created Metadata Utility
- **File**: `app/utils/metadata.ts`
- **Functions**:
  - `getAbsoluteUrl(path: string)`: Converts relative paths to absolute URLs
  - `getBaseUrl()`: Returns the base URL for the site
- **Purpose**: Follows DRY principle by centralizing URL generation logic

### 3. Enhanced Open Graph Tags
- All pages now use absolute URLs for Open Graph images
- Added proper image dimensions (1024x1024 for current image)
- Added `site` property to Twitter cards for better attribution

### 4. Updated All Page Metadata
- **Homepage** (`app/page.tsx`): Enhanced with absolute URLs
- **Privacy Policy** (`app/privacy/page.tsx`): Added Open Graph and Twitter card images
- **Terms of Service** (`app/terms/page.tsx`): Added Open Graph and Twitter card images
- **Root Layout** (`app/layout.tsx`): Enhanced with comprehensive metadata

### 5. SEO Enhancements
- Added verification meta tags placeholder (ready for Google Search Console, etc.)
- Ensured canonical URLs are properly set
- Enhanced robots meta tags for better crawling
- Improved structured data support

## Twitter/X Card Configuration

### Current Setup
- **Card Type**: `summary_large_image`
- **Image**: `/main-logo-transparent.png` (1024x1024px)
- **Image URL**: Now uses absolute URL format: `https://snifftest.app/main-logo-transparent.png`

### Recommended Next Steps
For optimal Twitter/X card display, consider creating a dedicated social sharing image:
- **Dimensions**: 1200x630px (Twitter's recommended size)
- **Filename**: `og-image.png` or `twitter-card.png`
- **Location**: `/public/og-image.png`
- **Update**: Change image references in metadata to use the new optimized image

## Testing

### Twitter/X Card Validator
Test your Twitter cards using:
- [Twitter Card Validator](https://cards-dev.twitter.com/validator)
- [Open Graph Debugger](https://developers.facebook.com/tools/debug/)

### SEO Testing
- Use [Google Search Console](https://search.google.com/search-console) to verify indexing
- Test with [Google Rich Results Test](https://search.google.com/test/rich-results)
- Validate structured data with [Schema.org Validator](https://validator.schema.org/)

## Environment Variables

Ensure `NEXT_PUBLIC_SITE_URL` is set in your environment:
```bash
NEXT_PUBLIC_SITE_URL=https://snifftest.app
```

If not set, defaults to `https://snifftest.app`.

## Files Modified

1. `app/utils/metadata.ts` (new file)
2. `app/layout.tsx`
3. `app/page.tsx`
4. `app/privacy/page.tsx`
5. `app/terms/page.tsx`

## Verification Checklist

- [x] All image URLs are absolute (not relative)
- [x] Twitter card type is `summary_large_image`
- [x] Open Graph images include proper dimensions
- [x] Canonical URLs are set correctly
- [x] All pages have proper metadata
- [ ] Create optimized 1200x630px social sharing image (optional but recommended)
- [ ] Add verification codes for Google Search Console (when available)
- [ ] Test Twitter/X card preview after deployment

## Notes

- The current 1024x1024 image will work for Twitter/X cards, but 1200x630px is the optimal size
- After deploying, use Twitter's Card Validator to clear any cached previews
- Social media platforms cache previews, so changes may take time to appear
