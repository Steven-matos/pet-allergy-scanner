# SEO Quick Reference - SniffTest Website

A concise guide for maintaining and improving SEO for the SniffTest website.

## Quick Links

- **Sitemap**: `/sitemap.xml`
- **Robots**: `/robots.txt`
- **Manifest**: `/manifest.json`
- **Full SEO Guide**: See `SEO.md`

## Current SEO Score

### Implemented Features ✅
- Metadata & Open Graph tags
- Twitter Cards
- Structured data (JSON-LD)
- Sitemap & Robots.txt
- PWA Manifest
- Security headers
- Image optimization
- Semantic HTML + ARIA
- Core Web Vitals optimized
- BreadcrumbList schema

### Pending (Production) ⏳
- Google Analytics integration
- Google Search Console verification
- SSL/TLS certificate
- CDN configuration

## Primary Keywords

**Target**: Pet health tracking, pet food scanner, pet allergy tracker, dog/cat nutrition

**Geographic**: US-focused, expandable internationally

**Competition**: Medium-High (Health & Pet niches)

## Core Web Vitals Targets

| Metric | Target | Status |
|--------|--------|--------|
| LCP | < 2.5s | ✅ Optimized |
| INP | < 200ms | ✅ Optimized |
| CLS | < 0.1 | ✅ Optimized |
| TTFB | < 800ms | ✅ Optimized |

## Quick Checks

### Before Deployment
```bash
# Build the site
npm run build

# Check for errors in output
# Verify all pages render correctly
# Test Core Web Vitals with Lighthouse
```

### Post-Deployment
1. ✅ Verify sitemap loads: `yoursite.com/sitemap.xml`
2. ✅ Verify robots.txt: `yoursite.com/robots.txt`
3. ✅ Test structured data: [Rich Results Test](https://search.google.com/test/rich-results)
4. ✅ Run Lighthouse audit (aim for 90+ scores)
5. ✅ Submit sitemap to Google Search Console
6. ✅ Submit sitemap to Bing Webmaster Tools

## Common Maintenance Tasks

### Update Page Title
**File**: `/website/app/page.tsx` or specific page
**Update**: `export const metadata: Metadata` object

### Update Sitemap
**File**: `/website/app/sitemap.ts`
**Add**: New URL entry with priority and frequency

### Add Structured Data
**File**: `/website/components/structured-data.tsx`
**Update**: Relevant function for page type

### Update Meta Description
**File**: Page-specific `page.tsx` file
**Update**: `metadata.description` field

## Emergency SEO Fixes

### Site Not Indexed
1. Check robots.txt isn't blocking
2. Verify sitemap in Search Console
3. Check for noindex tags
4. Request manual indexing

### Drop in Rankings
1. Check Core Web Vitals
2. Verify no broken links
3. Check for duplicate content
4. Review recent content changes
5. Monitor for algorithm updates

### Slow Performance
1. Run Lighthouse audit
2. Check image optimization
3. Verify CDN is working
4. Check for render-blocking resources
5. Monitor TTFB

## SEO Tools Access

- **Google Search Console**: [Link when set up]
- **Google Analytics**: [Link when set up]
- **PageSpeed Insights**: https://pagespeed.web.dev/
- **Rich Results Test**: https://search.google.com/test/rich-results

## Contact & Support

For SEO issues or questions:
1. Check `/website/SEO.md` for detailed documentation
2. Review Next.js docs for metadata API
3. Test with Lighthouse for performance issues
4. Consult Google Search Console for indexing issues

---

**Last Updated**: January 2025
