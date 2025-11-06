import { Scan, AlertCircle, ShieldCheck, Database, Bookmark, Heart } from 'lucide-react'

/**
 * Features section component
 * Displays product features in a grid layout
 */
export default function Features() {
  const features = [
    {
      icon: Scan,
      title: 'Instant Scanning',
      description: 'Simply scan the ingredient label with your camera. Our on-device OCR instantly recognizes and analyzes all components.',
      bgColor: 'bg-primary/10',
      iconColor: 'text-primary',
    },
    {
      icon: AlertCircle,
      title: 'Allergen Detection',
      description: 'Automatically identifies common allergens like chicken, beef, dairy, wheat, and more for your specific pet.',
      bgColor: 'bg-warm-coral/10',
      iconColor: 'text-warm-coral',
    },
    {
      icon: ShieldCheck,
      title: 'Safety Scoring',
      description: 'Get a comprehensive safety score based on ingredient quality and potential health concerns.',
      bgColor: 'bg-safe/10',
      iconColor: 'text-safe',
    },
    {
      icon: Database,
      title: 'Ingredient Database',
      description: 'Access detailed information on 15,000+ ingredients with nutritional value and safety data.',
      bgColor: 'bg-primary/10',
      iconColor: 'text-primary',
    },
    {
      icon: Bookmark,
      title: 'Scan History',
      description: 'Keep track of all your scanned products and easily compare different food options for your pets.',
      bgColor: 'bg-golden-yellow/10',
      iconColor: 'text-golden-yellow',
    },
    {
      icon: Heart,
      title: 'Pet Profiles',
      description: 'Create profiles for multiple pets with their specific allergies, sensitivities, and dietary needs.',
      bgColor: 'bg-primary/10',
      iconColor: 'text-primary',
    },
  ]

  return (
    <section id="features" className="py-24 px-4 sm:px-6 lg:px-8 scroll-mt-20" aria-labelledby="features-heading">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 id="features-heading" className="text-4xl font-semibold tracking-tight text-text-primary mb-4">
            Everything you need to keep your pets safe
          </h2>
          <p className="text-lg text-text-primary/70 max-w-2xl mx-auto">
            Comprehensive analysis powered by veterinary science and on-device processing
          </p>
        </div>
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8" role="list" aria-label="Product features">
          {features.map((feature) => {
            const Icon = feature.icon
            return (
              <article
                key={feature.title}
                className="p-6 bg-soft-cream rounded-2xl border border-border-primary hover:border-primary/50 hover:shadow-lg transition-all"
                role="listitem"
                itemScope
                itemType="https://schema.org/Thing"
              >
                <div className={`w-12 h-12 ${feature.bgColor} rounded-xl flex items-center justify-center mb-4`} aria-hidden="true">
                  <Icon className={`w-6 h-6 ${feature.iconColor}`} />
                </div>
                <h3 className="text-lg font-semibold text-text-primary mb-2" itemProp="name">{feature.title}</h3>
                <p className="text-text-primary/70" itemProp="description">{feature.description}</p>
              </article>
            )
          })}
        </div>
        <div className="max-w-3xl mx-auto mt-16">
          <div className="bg-warm-coral/10 border border-warm-coral/30 rounded-lg p-6">
            <p className="text-sm text-text-primary leading-relaxed text-center">
              <strong className="font-semibold">Important:</strong> This app does not replace veterinary consultation. Always consult with your veterinarian before making changes to your pet's diet or if you have concerns about your pet's health.
            </p>
          </div>
        </div>
      </div>
    </section>
  )
}

