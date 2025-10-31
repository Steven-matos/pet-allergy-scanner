/**
 * How It Works section component
 * Explains the three-step process for using the app
 */
export default function HowItWorks() {
  const steps = [
    {
      number: '1',
      title: 'Scan the Label',
      description: 'Point your camera at the ingredient list on any pet food package. Our on-device OCR technology instantly captures the text using Apple\'s Neural Engine.',
    },
    {
      number: '2',
      title: 'Instant Analysis',
      description: 'Our FastAPI backend processes ingredients through our comprehensive database, checking for allergens and safety concerns specific to your pet.',
    },
    {
      number: '3',
      title: 'Get Results',
      description: 'View a detailed report with safety scores, allergen warnings, and personalized recommendations for your pet.',
    },
  ]

  return (
    <section id="how-it-works" className="py-24 px-4 sm:px-6 lg:px-8 bg-soft-cream border-y border-border-primary scroll-mt-20">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-semibold tracking-tight text-text-primary mb-4">How it works</h2>
          <p className="text-lg text-text-primary/70 max-w-2xl mx-auto">
            Three simple steps to safer pet food
          </p>
        </div>
        <div className="grid md:grid-cols-3 gap-12">
          {steps.map((step) => (
            <div key={step.number} className="text-center">
              <div className="w-16 h-16 bg-primary text-white rounded-2xl flex items-center justify-center text-2xl font-semibold mx-auto mb-6">
                {step.number}
              </div>
              <h3 className="text-xl font-semibold text-text-primary mb-3">{step.title}</h3>
              <p className="text-text-primary/70">{step.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

