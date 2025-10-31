import { Check } from 'lucide-react'

/**
 * Pricing section component
 * Displays three pricing tiers with features
 */
export default function Pricing() {
  const plans = [
    {
      name: 'Free',
      description: 'Perfect for trying out',
      price: '$0',
      features: [
        '5 scans per month',
        '1 pet profile',
        'Basic allergen detection',
      ],
      buttonText: 'Get Started',
      buttonClass: 'w-full px-6 py-3 border border-border-primary hover:border-primary text-text-primary font-medium rounded-lg transition-colors',
      popular: false,
    },
    {
      name: 'Pro',
      description: 'For pet parents',
      price: '$9',
      features: [
        'Unlimited scans',
        'Up to 3 pet profiles',
        'Advanced analysis',
        'History tracking',
      ],
      buttonText: 'Get Started',
      buttonClass: 'w-full px-6 py-3 bg-white text-primary hover:bg-soft-cream font-medium rounded-lg transition-colors',
      popular: true,
    },
    {
      name: 'Premium',
      description: 'For multiple pets',
      price: '$19',
      features: [
        'Everything in Pro',
        'Unlimited pet profiles',
        'Priority support',
        'Export reports',
      ],
      buttonText: 'Get Started',
      buttonClass: 'w-full px-6 py-3 border border-border-primary hover:border-primary text-text-primary font-medium rounded-lg transition-colors',
      popular: false,
    },
  ]

  return (
    <section id="pricing" className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-semibold tracking-tight text-text-primary mb-4">
            Simple, transparent pricing
          </h2>
          <p className="text-lg text-text-primary/70 max-w-2xl mx-auto">
            Choose the plan that works for you and your pets
          </p>
        </div>
        <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`p-8 rounded-2xl relative transition-all ${
                plan.popular
                  ? 'bg-primary text-white hover:shadow-2xl'
                  : 'bg-soft-cream border border-border-primary hover:border-primary/50 hover:shadow-lg'
              }`}
            >
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-3 py-1 bg-golden-yellow text-white text-xs font-semibold rounded-full">
                  POPULAR
                </div>
              )}
              <h3 className={`text-xl font-semibold mb-2 ${plan.popular ? '' : 'text-text-primary'}`}>
                {plan.name}
              </h3>
              <p className={`mb-6 ${plan.popular ? 'text-white/80' : 'text-text-primary/70'}`}>
                {plan.description}
              </p>
              <div className="mb-6">
                <span className={`text-4xl font-semibold tracking-tight ${plan.popular ? '' : 'text-text-primary'}`}>
                  {plan.price}
                </span>
                <span className={plan.popular ? 'text-white/80' : 'text-text-primary/70'}>/month</span>
              </div>
              <ul className="space-y-3 mb-8">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start space-x-3">
                    <Check className={`w-5 h-5 mt-0.5 ${plan.popular ? '' : 'text-safe'}`} />
                    <span className={`text-sm ${plan.popular ? '' : 'text-text-primary/70'}`}>{feature}</span>
                  </li>
                ))}
              </ul>
              <button className={plan.buttonClass}>{plan.buttonText}</button>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

