'use client'

// import { FaXTwitter, FaFacebook, FaInstagram } from 'react-icons/fa6'
import Image from 'next/image'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

/**
 * Footer component
 * Contains site links, legal information, and social media links
 * Footer links properly route to home page sections from any page
 */
export default function Footer() {
  const pathname = usePathname()
  const isHomePage = pathname === '/'

  /**
   * Creates the proper link href based on current page
   * If on home page, use anchor link; otherwise link to home with anchor
   */
  const getNavLink = (anchor: string) => {
    return isHomePage ? anchor : `/${anchor}`
  }

  /**
   * Handles click for navigation links with smooth scroll
   */
  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
    if (isHomePage && href.startsWith('#')) {
      e.preventDefault()
      const element = document.querySelector(href)
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    }
  }

  const footerLinks = {
    product: [
      { name: 'Features', href: getNavLink('#features') },
      { name: 'Waitlist', href: isHomePage ? '#waitlist' : '/#waitlist' },
      { name: 'Support', href: '/support' },
    ],
    legal: [
      { name: 'Privacy', href: '/privacy' },
      { name: 'Terms', href: '/terms' },
    ],
  }

  // const socialLinks = [
  //   { Icon: FaXTwitter, href: '#', label: 'X' },
  //   { Icon: FaFacebook, href: '#', label: 'Facebook' },
  //   { Icon: FaInstagram, href: '#', label: 'Instagram' },
  // ]

  return (
    <footer className="border-t border-border-primary py-12 px-4 sm:px-6 lg:px-8 bg-soft-cream">
      <div className="max-w-7xl mx-auto">
        <div className="grid md:grid-cols-3 gap-8 mb-8">
          <div>
            <div className="flex items-center space-x-2 mb-4">
              <Image
                src="/main-logo-transparent.png"
                alt="SniffTest Logo"
                width={32}
                height={32}
                className="w-8 h-8 object-contain"
              />
              <span className="text-lg font-semibold tracking-tight text-text-primary">SniffTest</span>
            </div>
            <p className="text-sm text-text-primary/70">Keeping pets safe, one scan at a time.</p>
          </div>
          <div>
            <h4 className="font-semibold text-text-primary mb-4">Product</h4>
            <ul className="space-y-2 text-sm text-text-primary/70">
              {footerLinks.product.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    onClick={(e) => handleNavClick(e, link.href)}
                    className="hover:text-text-primary transition-colors"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-text-primary mb-4">Legal</h4>
            <ul className="space-y-2 text-sm text-text-primary/70">
              {footerLinks.legal.map((link) => (
                <li key={link.name}>
                  <Link href={link.href} className="hover:text-text-primary transition-colors">
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>
        <div className="pt-8 border-t border-border-primary flex flex-col sm:flex-row justify-between items-center">
          <p className="text-sm text-text-primary/70">© 2025 SniffTest. All rights reserved.</p>
          {/* <div className="flex items-center space-x-6 mt-4 sm:mt-0">
            {socialLinks.map(({ Icon, href, label }) => (
              <a
                key={label}
                href={href}
                className="text-text-primary/70 hover:text-text-primary transition-colors"
                aria-label={label}
              >
                <Icon className="w-5 h-5" />
              </a>
            ))}
          </div> */}
        </div>
      </div>
    </footer>
  )
}

