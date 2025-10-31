/**
 * Stats section component
 * Displays key metrics and social proof
 */
export default function Stats() {
  const stats = [
    { value: '5K+', label: 'Scans Completed' },
    { value: '2K+', label: 'Ingredients Analyzed' },
    { value: '98%', label: 'Accuracy Rate' },
  ]

  return (
    <section className="py-16 px-4 sm:px-6 lg:px-8 bg-soft-cream border-y border-border-primary">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-8">
          {stats.map((stat) => (
            <div key={stat.label} className="text-center">
              <div className="text-4xl font-semibold tracking-tight text-text-primary mb-2">
                {stat.value}
              </div>
              <div className="text-sm text-text-primary/70">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

