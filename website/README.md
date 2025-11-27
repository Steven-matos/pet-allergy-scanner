# SniffTest Landing Page

A modern, SEO-optimized Next.js landing page for the SniffTest pet food ingredient analysis app. Built with Next.js 16, React 19, and TypeScript for a performant, type-safe experience.

## Tech Stack

- **Next.js 16** - React framework with App Router and server components
- **React 19** - Latest React with improved performance
- **TypeScript 5.6** - Type-safe development
- **Tailwind CSS 3.4** - Utility-first CSS framework
- **Lucide React** - Modern icon library
- **React Icons** - Additional icon support

## Getting Started

### Prerequisites

- Node.js 20+ 
- npm or yarn

### Installation

```bash
npm install
```

### Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

### Build for Production

```bash
npm run build
npm start
```

### Linting

```bash
npm run lint
```

## Environment Variables

Create a `.env.local` file in the root directory:

```env
NEXT_PUBLIC_SITE_URL=https://snifftest.app
```

This is used for:
- Generating absolute URLs for social sharing
- Canonical URLs
- Open Graph images
- Structured data

## Project Structure

```
website/
├── app/
│   ├── layout.tsx          # Root layout with metadata and providers
│   ├── page.tsx            # Main landing page
│   ├── globals.css         # Global styles
│   ├── manifest.ts         # PWA manifest configuration
│   ├── robots.ts           # Robots.txt generation
│   ├── sitemap.ts          # Sitemap generation
│   ├── privacy/
│   │   └── page.tsx        # Privacy policy page
│   ├── terms/
│   │   └── page.tsx        # Terms of service page
│   └── support/
│       ├── layout.tsx      # Support layout
│       └── page.tsx        # Support page
├── components/
│   ├── navigation.tsx      # Header navigation with scroll effects
│   ├── hero.tsx           # Hero section with CTA
│   ├── stats.tsx          # Statistics/metrics section
│   ├── features.tsx       # Features grid
│   ├── how-it-works.tsx   # Process explanation
│   ├── pricing.tsx        # Pricing tiers
│   ├── cta.tsx            # Call-to-action section
│   ├── footer.tsx         # Footer with links
│   ├── back-to-top.tsx    # Scroll to top button
│   ├── scroll-handler.tsx # Smooth scroll utilities
│   ├── structured-data.tsx # JSON-LD structured data
│   ├── waitlist-modal.tsx # Waitlist signup modal
│   └── waitlist-modal-wrapper.tsx # Modal wrapper component
├── contexts/
│   └── waitlist-context.tsx # React context for waitlist state
├── lib/
│   └── metadata.ts        # Metadata utility functions
├── public/                # Static assets (images, icons)
└── tailwind.config.ts     # Tailwind configuration
```

## Features

### Core Features

- ✅ **Fully Responsive Design** - Mobile-first approach with breakpoints for all devices
- ✅ **Server-Side Rendering** - Next.js App Router with React Server Components
- ✅ **SEO Optimized** - Comprehensive metadata, structured data, sitemap, and robots.txt
- ✅ **Performance Optimized** - Image optimization, code splitting, compression
- ✅ **Type-Safe** - Full TypeScript coverage with strict mode
- ✅ **PWA Ready** - Manifest configuration for progressive web app support

### SEO Features

- Open Graph tags for social sharing
- Twitter Card metadata
- JSON-LD structured data (Schema.org)
- Dynamic sitemap generation
- Robots.txt configuration
- Canonical URLs
- Semantic HTML structure

### User Experience

- Smooth scrolling navigation
- Back-to-top button
- Waitlist modal with context management
- Accessible components (ARIA labels, keyboard navigation)
- Loading states and transitions
- Optimized font loading (Inter from Google Fonts)

### Security

- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Referrer policy configuration
- DNS prefetch control

## Design System

The landing page uses a custom color palette defined in `tailwind.config.ts`:

### Colors

- **Primary**: `#2D5016` (Forest Green) - Main brand color
- **Warm Coral**: `#E67E22` - Accent color
- **Golden Yellow**: `#F39C12` - Highlight color
- **Soft Cream**: `#F8F6F0` - Background color
- **Text Primary**: `#2C3E50` - Main text color
- **Text Secondary**: `#BDC3C7` - Secondary text color
- **Border Primary**: `#95A5A6` - Border color
- **Safe**: `#27AE60` - Success/positive states
- **Warning**: `#F39C12` - Warning states
- **Error**: `#E74C3C` - Error/negative states

### Typography

- **Font Family**: Inter (Google Fonts)
- **Font Loading**: Optimized with `next/font/google`

## Development Principles

This project strictly follows:

- **SOLID** - Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY** - Don't Repeat Yourself - Shared utilities and reusable components
- **KISS** - Keep It Simple, Stupid - Clear, maintainable code

### Code Organization

- Each component is under 500 lines (split into modules when needed)
- Single responsibility per component
- Functional components with hooks
- Type-safe with TypeScript interfaces
- JSDoc comments for complex functions
- Early returns for error handling

## Deployment

### Build Configuration

The project includes optimized build settings:

- Image optimization with AVIF and WebP formats
- Package import optimization for `lucide-react` and `react-icons`
- Compression enabled
- Security headers configured

### Recommended Platforms

- **Vercel** - Recommended (built by Next.js creators)
- **Netlify** - Full Next.js support
- **Railway** - Container-based deployment
- **AWS Amplify** - AWS integration

## Performance Optimizations

- Image optimization with Next.js Image component
- Code splitting and lazy loading
- Font optimization with `next/font`
- Package import optimization
- Compression enabled
- DNS prefetch control

## Learn More

To learn more about the technologies used:

- [Next.js Documentation](https://nextjs.org/docs)
- [React 19 Documentation](https://react.dev)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [TypeScript Documentation](https://www.typescriptlang.org/docs)
- [Next.js Image Optimization](https://nextjs.org/docs/app/building-your-application/optimizing/images)
- [Next.js Metadata API](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)

