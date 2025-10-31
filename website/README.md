# SniffTest Landing Page

A modern Next.js landing page for the SniffTest pet food ingredient analysis app.

## Tech Stack

- **Next.js 14** - React framework with App Router
- **TypeScript** - Type-safe development
- **Tailwind CSS** - Utility-first CSS framework
- **Lucide React** - Icon library

## Getting Started

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

## Project Structure

```
website/
├── app/
│   ├── layout.tsx      # Root layout with metadata
│   ├── page.tsx        # Main landing page
│   └── globals.css     # Global styles
├── components/
│   ├── navigation.tsx  # Header navigation
│   ├── hero.tsx        # Hero section
│   ├── stats.tsx       # Statistics section
│   ├── features.tsx    # Features grid
│   ├── how-it-works.tsx # Process explanation
│   ├── pricing.tsx     # Pricing tiers
│   ├── cta.tsx         # Call-to-action
│   └── footer.tsx      # Footer section
├── public/            # Static assets
└── tailwind.config.ts # Tailwind configuration
```

## Features

- ✅ Fully responsive design
- ✅ Server-side rendering with Next.js App Router
- ✅ Optimized images with Next.js Image component
- ✅ Type-safe with TypeScript
- ✅ Custom color palette matching brand identity
- ✅ Modular component architecture
- ✅ SEO optimized with metadata API
- ✅ Smooth scrolling navigation

## Design System

The landing page uses a custom color palette defined in `tailwind.config.ts`:

- **Primary**: #2D5016 (Forest Green)
- **Warm Coral**: #E67E22
- **Golden Yellow**: #F39C12
- **Soft Cream**: #F8F6F0
- **Text Primary**: #2C3E50
- **Safe**: #27AE60 (Green)
- **Warning**: #F39C12 (Yellow)
- **Error**: #E74C3C (Red)

## Development Principles

This project follows:

- **SOLID** - Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY** - Don't Repeat Yourself
- **KISS** - Keep It Simple, Stupid

Each component is under 150 lines and has a single, clear purpose.

## Learn More

To learn more about the technologies used:

- [Next.js Documentation](https://nextjs.org/docs)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [TypeScript Documentation](https://www.typescriptlang.org/docs)

