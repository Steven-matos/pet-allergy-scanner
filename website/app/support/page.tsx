'use client'

import { useState, useMemo } from 'react'
import Navigation from '@/components/navigation'
import Footer from '@/components/footer'
import BackToTop from '@/components/back-to-top'
import StructuredData from '@/components/structured-data'
import { Search, Mail, MessageSquare, ChevronRight, ChevronDown, Camera, PawPrint, AlertTriangle, CreditCard, Heart, BarChart, Lock } from 'lucide-react'

/**
 * FAQ Article interface
 */
interface FAQArticle {
  question: string
  answer: string
  isImportant: boolean
}

/**
 * Support Category interface
 */
interface SupportCategory {
  id: string
  title: string
  icon: React.ReactNode
  iconColor: string
  questions: FAQArticle[]
}

/**
 * Support page component
 * Mirrors the in-app help center with search, quick actions, and FAQ categories
 * Follows DRY principle by reusing components and data structures
 */
export default function SupportPage() {
  const [searchText, setSearchText] = useState('')
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set())
  const [expandedQuestions, setExpandedQuestions] = useState<Set<string>>(new Set())

  /**
   * Toggles category expansion state
   */
  const toggleCategory = (categoryId: string) => {
    const newExpanded = new Set(expandedCategories)
    if (newExpanded.has(categoryId)) {
      newExpanded.delete(categoryId)
    } else {
      newExpanded.add(categoryId)
    }
    setExpandedCategories(newExpanded)
  }

  /**
   * Toggles question expansion state
   */
  const toggleQuestion = (questionId: string) => {
    const newExpanded = new Set(expandedQuestions)
    if (newExpanded.has(questionId)) {
      newExpanded.delete(questionId)
    } else {
      newExpanded.add(questionId)
    }
    setExpandedQuestions(newExpanded)
  }

  /**
   * FAQ Categories data
   * Mirrors the in-app help center structure
   */
  const categories: SupportCategory[] = [
    {
      id: 'scanning',
      title: 'Scanning & OCR',
      icon: <Camera className="w-5 h-5" />,
      iconColor: 'text-primary',
      questions: scanningFAQs,
    },
    {
      id: 'pet-management',
      title: 'Pet Management',
      icon: <PawPrint className="w-5 h-5" />,
      iconColor: 'text-golden-yellow',
      questions: petManagementFAQs,
    },
    {
      id: 'allergies',
      title: 'Allergies & Safety',
      icon: <AlertTriangle className="w-5 h-5" />,
      iconColor: 'text-warm-coral',
      questions: allergiesFAQs,
    },
    {
      id: 'subscription',
      title: 'Subscription & Billing',
      icon: <CreditCard className="w-5 h-5" />,
      iconColor: 'text-primary',
      questions: subscriptionFAQs,
    },
    {
      id: 'health-tracker',
      title: 'Health Tracker',
      icon: <Heart className="w-5 h-5" />,
      iconColor: 'text-warm-coral',
      questions: healthTrackerFAQs,
    },
    {
      id: 'nutrition',
      title: 'Nutrition & Tracking',
      icon: <BarChart className="w-5 h-5" />,
      iconColor: 'text-primary',
      questions: nutritionFAQs,
    },
    {
      id: 'privacy',
      title: 'Privacy & Security',
      icon: <Lock className="w-5 h-5" />,
      iconColor: 'text-text-secondary',
      questions: privacyFAQs,
    },
  ]

  /**
   * Filters categories and questions based on search text
   * Implements client-side search functionality
   */
  const filteredCategories = useMemo(() => {
    if (!searchText.trim()) {
      return categories
    }

    const searchLower = searchText.toLowerCase()
    return categories
      .map((category) => {
        const filteredQuestions = category.questions.filter(
          (q) =>
            q.question.toLowerCase().includes(searchLower) ||
            q.answer.toLowerCase().includes(searchLower)
        )
        return {
          ...category,
          questions: filteredQuestions,
        }
      })
      .filter((category) => category.questions.length > 0)
  }, [searchText])

  return (
    <main>
      <StructuredData type="support" />
      <Navigation />
      <div className="min-h-screen bg-white pt-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 lg:py-12">
          {/* Header Section */}
          <div className="text-center mb-8">
            <div className="flex justify-center mb-4">
              <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
                <span className="text-4xl">❓</span>
              </div>
            </div>
            <h1 className="text-4xl font-bold text-text-primary mb-2">How can we help?</h1>
            <p className="text-lg text-text-secondary">
              Find answers to common questions and get support
            </p>
          </div>

          {/* Search Section */}
          <div className="mb-8">
            <div className="relative">
              <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-text-secondary w-5 h-5" />
              <input
                type="text"
                placeholder="Search help topics..."
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                className="w-full pl-12 pr-4 py-3 bg-soft-cream border border-border-primary rounded-lg focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent text-text-primary placeholder:text-text-secondary"
              />
              {searchText && (
                <button
                  onClick={() => setSearchText('')}
                  className="absolute right-4 top-1/2 transform -translate-y-1/2 text-text-secondary hover:text-text-primary"
                  aria-label="Clear search"
                >
                  ✕
                </button>
              )}
            </div>
          </div>

          {/* Quick Actions Section */}
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-text-primary mb-4">Quick Actions</h2>
            <div className="space-y-3">
              <QuickActionCard
                icon={<Mail className="w-6 h-6" />}
                title="Contact Support"
                description="Get help from our support team"
                iconColor="text-primary"
                href="mailto:support@snifftestapp.com"
              />
              <QuickActionCard
                icon={<MessageSquare className="w-6 h-6" />}
                title="Send Feedback"
                description="Help us improve the app"
                iconColor="text-warm-coral"
                href="mailto:feedback@petallergycheck.com"
              />
            </div>
          </div>

          {/* FAQ Categories Section */}
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-text-primary mb-4">
              Frequently Asked Questions
            </h2>
            <div className="space-y-3">
              {filteredCategories.map((category) => (
                <FAQCategoryCard
                  key={category.id}
                  category={category}
                  isExpanded={expandedCategories.has(category.id)}
                  onToggle={() => toggleCategory(category.id)}
                  expandedQuestions={expandedQuestions}
                  onToggleQuestion={toggleQuestion}
                />
              ))}
            </div>
          </div>

          {/* App Information Section */}
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-text-primary mb-4">App Information</h2>
            <div className="space-y-3">
              <LinkCard
                icon="🛡️"
                title="Privacy Policy"
                href="/privacy"
                iconColor="text-primary"
              />
              <LinkCard
                icon="📄"
                title="Terms of Service"
                href="/terms"
                iconColor="text-primary"
              />
            </div>
          </div>

          {/* Back to Top Link */}
          <BackToTop />
        </div>
      </div>
      <Footer />
    </main>
  )
}

/**
 * Quick Action Card Component
 * Displays actionable support options
 */
function QuickActionCard({
  icon,
  title,
  description,
  iconColor,
  href,
}: {
  icon: React.ReactNode
  title: string
  description: string
  iconColor: string
  href: string
}) {
  return (
    <a
      href={href}
      className="flex items-center gap-4 p-4 bg-soft-cream border border-border-primary rounded-lg hover:shadow-md transition-shadow"
    >
      <div className={`${iconColor} bg-current/10 rounded-full p-3`}>{icon}</div>
      <div className="flex-1">
        <h3 className="font-semibold text-text-primary">{title}</h3>
        <p className="text-sm text-text-secondary">{description}</p>
      </div>
      <ChevronRight className="w-5 h-5 text-text-secondary" />
    </a>
  )
}

/**
 * FAQ Category Card Component
 * Displays category with expandable questions
 */
function FAQCategoryCard({
  category,
  isExpanded,
  onToggle,
  expandedQuestions,
  onToggleQuestion,
}: {
  category: SupportCategory
  isExpanded: boolean
  onToggle: () => void
  expandedQuestions: Set<string>
  onToggleQuestion: (id: string) => void
}) {
  return (
    <div className="bg-soft-cream border border-border-primary rounded-lg overflow-hidden">
      <button
        onClick={onToggle}
        className="w-full flex items-center gap-4 p-4 hover:bg-white/50 transition-colors text-left"
      >
        <div className={`${category.iconColor} bg-current/10 rounded-full p-2`}>
          {category.icon}
        </div>
        <div className="flex-1">
          <h3 className="font-semibold text-text-primary">{category.title}</h3>
          <p className="text-sm text-text-secondary">{category.questions.length} questions</p>
        </div>
        {isExpanded ? (
          <ChevronDown className="w-5 h-5 text-text-secondary" />
        ) : (
          <ChevronRight className="w-5 h-5 text-text-secondary" />
        )}
      </button>
      {isExpanded && (
        <div className="border-t border-border-primary p-4 space-y-3">
          {category.questions.map((article, index) => {
            const questionId = `${category.id}-${index}`
            const isQuestionExpanded = expandedQuestions.has(questionId)
            return (
              <div key={questionId} className="bg-white rounded-lg border border-border-primary/50">
                <button
                  onClick={() => onToggleQuestion(questionId)}
                  className="w-full flex items-start gap-3 p-3 hover:bg-soft-cream transition-colors text-left"
                >
                  <div className="flex-1">
                    <div className="flex items-start gap-2">
                      {article.isImportant && (
                        <AlertTriangle className="w-4 h-4 text-warm-coral flex-shrink-0 mt-0.5" />
                      )}
                      <h4 className="font-medium text-text-primary text-sm">{article.question}</h4>
                    </div>
                  </div>
                  {isQuestionExpanded ? (
                    <ChevronDown className="w-4 h-4 text-text-secondary flex-shrink-0 mt-0.5" />
                  ) : (
                    <ChevronRight className="w-4 h-4 text-text-secondary flex-shrink-0 mt-0.5" />
                  )}
                </button>
                {isQuestionExpanded && (
                  <div className="px-3 pb-3 pt-0">
                    <p className="text-sm text-text-secondary leading-relaxed">{article.answer}</p>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

/**
 * Link Card Component
 * Displays navigation links to legal pages
 */
function LinkCard({
  icon,
  title,
  href,
  iconColor,
}: {
  icon: string
  title: string
  href: string
  iconColor: string
}) {
  return (
    <a
      href={href}
      className="flex items-center gap-4 p-4 bg-soft-cream border border-border-primary rounded-lg hover:shadow-md transition-shadow"
    >
      <span className={`text-2xl ${iconColor}`}>{icon}</span>
      <div className="flex-1">
        <h3 className="font-semibold text-primary">{title}</h3>
      </div>
      <ChevronRight className="w-5 h-5 text-primary" />
    </a>
  )
}

// MARK: - FAQ Content
// Mirrors the in-app help center FAQ data

const scanningFAQs: FAQArticle[] = [
  {
    question: 'How do I scan a pet food label?',
    answer:
      'Open the app and tap the camera icon on the main screen. Point your camera at the ingredient list on the pet food label. Make sure the text is clearly visible and well-lit. The app will automatically extract the text and analyze it for your pet\'s safety.',
    isImportant: false,
  },
  {
    question: 'Why is my camera not working?',
    answer:
      'First, make sure you\'ve granted camera permissions to SniffTest in your device settings. Go to Settings > Privacy & Security > Camera > SniffTest and ensure it\'s enabled. If the issue persists, try restarting the app or your device.',
    isImportant: true,
  },
  {
    question: 'What if the text is blurry or hard to read?',
    answer:
      'Ensure good lighting and hold your device steady. Try moving closer to the label or adjusting the angle. The app works best with clear, high-contrast text. If the label is damaged or faded, you can manually type the ingredients in the text input option.',
    isImportant: false,
  },
  {
    question: 'Can I scan multiple products at once?',
    answer:
      'No, you can only scan one product at a time. This ensures accurate analysis for each specific product. After scanning one item, you can scan another by tapping the camera button again.',
    isImportant: false,
  },
  {
    question: 'Does the app work offline?',
    answer:
      'Basic scanning and text extraction work offline, but ingredient analysis requires an internet connection. The app will store your scans and process them when you\'re back online.',
    isImportant: true,
  },
  {
    question: 'How accurate is the OCR text recognition?',
    answer:
      'Our OCR technology works well with clear, well-lit text. Accuracy may vary with poor lighting, damaged labels, or unusual fonts. You can always review and edit the extracted text before analysis. Results are for informational purposes only.',
    isImportant: false,
  },
  {
    question: 'What languages are supported for scanning?',
    answer:
      'Currently, SniffTest supports English text recognition. We\'re working on adding support for Spanish in future updates.',
    isImportant: false,
  },
  {
    question: 'Can I scan handwritten ingredient lists?',
    answer:
      'The app works best with printed text. Handwritten text may not be recognized accurately. For handwritten lists, we recommend manually typing the ingredients into the text input field.',
    isImportant: false,
  },
  {
    question: 'What if the scan fails or shows an error?',
    answer:
      'Try these steps: 1) Ensure good lighting, 2) Clean your camera lens, 3) Hold the device steady, 4) Make sure the text is clearly visible. If problems persist, try the manual text input option or contact support.',
    isImportant: true,
  },
  {
    question: 'How long does it take to analyze a scan?',
    answer:
      'Most scans are analyzed within 10-30 seconds. Complex products with many ingredients may take up to 2 minutes. You\'ll see a progress indicator during analysis.',
    isImportant: false,
  },
  {
    question: 'Can I save scan results for later?',
    answer:
      'Yes! All your scans are automatically saved to your scan history. You can also mark products as favorites if they\'re safe for your pet.',
    isImportant: false,
  },
  {
    question: 'What if I disagree with the safety assessment?',
    answer:
      'Our analysis is for informational purposes only and should not replace professional veterinary advice. Every pet is unique and may have individual health considerations. Always consult your veterinarian for specific dietary concerns and medical decisions. You can provide feedback on our analysis through the app.',
    isImportant: true,
  },
]

const petManagementFAQs: FAQArticle[] = [
  {
    question: 'How do I add a new pet to my profile?',
    answer:
      'Go to the Pets tab and tap the \'+\' button. Fill in your pet\'s name, species (dog or cat), breed, birthday, weight, and any known sensitivities. You can also add a photo and vet information.',
    isImportant: false,
  },
  {
    question: 'Can I have multiple pets in one account?',
    answer:
      'Multiple pet profiles are available with a premium subscription. Free users can have one pet profile, while premium subscribers can add unlimited pets. Each pet has their own profile with individual allergy tracking and scan history.',
    isImportant: true,
  },
  {
    question: 'How do I update my pet\'s information?',
    answer:
      'Go to the Pets tab, select your pet, and tap \'Edit Profile\'. You can update weight, add new sensitivities, change vet information, or update their photo at any time.',
    isImportant: false,
  },
  {
    question: 'What if I don\'t know my pet\'s exact birthday?',
    answer:
      'You can estimate your pet\'s age in months or years. The app will calculate their life stage (puppy/kitten, adult, senior) based on their species and estimated age.',
    isImportant: false,
  },
  {
    question: 'How do I track my pet\'s weight changes?',
    answer:
      'In your pet\'s profile, tap \'Update Weight\' to record new measurements. The app will track weight trends and provide insights about your pet\'s health.',
    isImportant: false,
  },
  {
    question: 'What are known sensitivities and how do I add them?',
    answer:
      'Known sensitivities are ingredients your pet has reacted to in the past. Add them in your pet\'s profile so the app can warn you when scanning products that contain these ingredients.',
    isImportant: true,
  },
  {
    question: 'Can I delete a pet profile?',
    answer:
      'Yes, you can delete a pet profile by going to their profile page and selecting \'Delete Pet\'. This will remove all associated scan history and data permanently.',
    isImportant: true,
  },
  {
    question: 'How do I add vet information?',
    answer:
      'In your pet\'s profile, scroll down to \'Veterinary Information\' and add your vet\'s name and phone number. This information is stored locally on your device for quick access.',
    isImportant: false,
  },
]

const allergiesFAQs: FAQArticle[] = [
  {
    question: 'What ingredients are most dangerous for dogs?',
    answer:
      'Common ingredients that may be problematic for dogs include: chocolate, grapes, raisins, onions, garlic, xylitol, macadamia nuts, and certain artificial sweeteners. This information is for educational purposes only. Always consult your veterinarian about your specific pet\'s dietary needs and health concerns.',
    isImportant: true,
  },
  {
    question: 'What ingredients are most dangerous for cats?',
    answer:
      'Ingredients that may be problematic for cats include: onions, garlic, chocolate, caffeine, alcohol, grapes, raisins, and certain essential oils. Cats are obligate carnivores, so high-carb diets may not be ideal. This information is for educational purposes only. Always consult your veterinarian about your specific pet\'s dietary needs.',
    isImportant: true,
  },
  {
    question: 'How does the app determine if an ingredient is safe?',
    answer:
      'Our database includes general information about ingredients and their potential effects on pets. The app considers your pet\'s species, age, and known sensitivities when analyzing ingredients. However, this analysis is for informational purposes only and should not replace professional veterinary advice.',
    isImportant: false,
  },
  {
    question: 'What should I do if my pet has an allergic reaction?',
    answer:
      'If you suspect your pet is having an allergic reaction, contact your veterinarian or emergency veterinary clinic immediately. Common symptoms may include vomiting, diarrhea, itching, swelling, or difficulty breathing. This is a medical emergency that requires professional veterinary care.',
    isImportant: true,
  },
  {
    question: 'Can the app detect food allergies vs. food intolerances?',
    answer:
      'The app identifies potentially problematic ingredients for informational purposes only. It cannot and does not diagnose specific allergies or intolerances. Only a licensed veterinarian can diagnose food allergies through proper medical testing and evaluation.',
    isImportant: true,
  },
  {
    question: 'What if my pet has a rare allergy not in the database?',
    answer:
      'You can add custom sensitivities in your pet\'s profile. The app will flag any products containing those specific ingredients during scans.',
    isImportant: false,
  },
  {
    question: 'Are grain-free diets always better for pets?',
    answer:
      'Not necessarily. While some pets may benefit from grain-free diets, others may develop health issues from grain-free foods. This is a complex topic that varies by individual pet. Always consult your veterinarian about the best diet for your specific pet\'s health needs.',
    isImportant: true,
  },
  {
    question: 'How often should I check ingredients for my pet?',
    answer:
      'Check ingredients every time you buy new food or treats, even from the same brand. Manufacturers may change formulations without notice.',
    isImportant: false,
  },
  {
    question: 'What about treats and supplements?',
    answer:
      'Yes, you can scan treats and supplements too. The app analyzes all pet food products, including treats, supplements, and dental chews.',
    isImportant: false,
  },
  {
    question: 'Can I trust the safety ratings completely?',
    answer:
      'Our ratings are for informational purposes only and should not be the sole basis for dietary decisions. Every pet is unique and may have individual health considerations. Always consult your veterinarian for specific dietary recommendations, especially for pets with health conditions or special needs.',
    isImportant: true,
  },
  {
    question: 'What if an ingredient is marked as \'caution\'?',
    answer:
      'A \'caution\' rating means the ingredient may be problematic for some pets or in large quantities. This is for informational purposes only. Consider your pet\'s individual health and always consult your veterinarian if you have concerns about specific ingredients.',
    isImportant: false,
  },
  {
    question: 'How do I know if my pet is having a food reaction?',
    answer:
      'Common signs that may indicate a food reaction include vomiting, diarrhea, itching, skin irritation, ear infections, or changes in behavior. If you suspect your pet is having a food reaction, contact your veterinarian immediately for proper evaluation and care.',
    isImportant: true,
  },
  {
    question: 'Can the app help with elimination diets?',
    answer:
      'The app can help identify potential allergens in foods for informational purposes, but elimination diets should always be conducted under direct veterinary supervision and guidance. Never attempt elimination diets without professional veterinary oversight.',
    isImportant: true,
  },
  {
    question: 'What about prescription diets?',
    answer:
      'Prescription diets should only be used under direct veterinary guidance and supervision. The app can analyze their ingredients for informational purposes, but always follow your veterinarian\'s specific recommendations and never make dietary changes without professional veterinary approval.',
    isImportant: true,
  },
  {
    question: 'How do I transition my pet to a new food safely?',
    answer:
      'Gradually mix the new food with the old food over 7-10 days, increasing the proportion of new food each day. This general guideline may help prevent digestive upset, but always consult your veterinarian for specific transition advice tailored to your pet\'s individual needs.',
    isImportant: false,
  },
]

const subscriptionFAQs: FAQArticle[] = [
  {
    question: 'Is SniffTest free to use?',
    answer:
      'SniffTest offers a free tier with basic scanning features and one pet profile. Premium subscriptions unlock advanced features like unlimited scans, multiple pet profiles, detailed nutritional analysis, and priority support.',
    isImportant: false,
  },
  {
    question: 'What features are included in the premium subscription?',
    answer:
      'Premium includes: unlimited scans, detailed nutritional breakdowns, weight tracking trends, multiple pet profiles (unlimited), scan history export, and priority customer support. Free users get basic scanning with one pet profile.',
    isImportant: false,
  },
  {
    question: 'How do I cancel my subscription?',
    answer:
      'You can cancel through your iPhone\'s App Store settings. Go to Settings > [Your Name] > Subscriptions > SniffTest > Cancel Subscription.',
    isImportant: true,
  },
  {
    question: 'Will I lose my data if I cancel?',
    answer:
      'Your scan history and pet profiles are saved for 30 days after cancellation, subject to our terms of service and privacy policy. You can reactivate your subscription to restore full access to your data. Data retention is subject to applicable data protection laws.',
    isImportant: true,
  },
  {
    question: 'Can I get a refund for my subscription?',
    answer:
      'Refund requests are handled through Apple. Contact Apple Support for subscription refunds through the App Store.',
    isImportant: false,
  },
  {
    question: 'Do you offer family plans?',
    answer:
      'Currently, we offer individual subscriptions. Each family member needs their own account and subscription to use the app.',
    isImportant: false,
  },
]

const healthTrackerFAQs: FAQArticle[] = [
  {
    question: 'How do I log a health event for my pet?',
    answer:
      'Go to the Trackers tab and tap \'Add Health Event\'. Select your pet, choose the event type (vomiting, diarrhea, vet visit, medication, etc.), add a title and notes, set the date and time, and tap \'Save\'. The event will be saved to your pet\'s health history.',
    isImportant: false,
  },
  {
    question: 'What types of health events can I track?',
    answer:
      'You can track: vomiting, diarrhea, vet visits, medication administration, behavioral changes, skin issues, eye/ear problems, and other custom events. Each event type helps you monitor patterns in your pet\'s health over time.',
    isImportant: false,
  },
  {
    question: 'How do I add a medication reminder?',
    answer:
      'When logging a medication health event, enable \'Create Reminder\' and fill in the medication name, dosage, frequency (daily, twice daily, weekly, etc.), and reminder times. The app will send you notifications at the scheduled times to give your pet their medication.',
    isImportant: true,
  },
  {
    question: 'Can I attach documents to vet visits?',
    answer:
      'Yes! When logging a vet visit, you can attach documents like lab results, vaccination records, or vet notes by tapping \'Add Document\'. This helps you keep all your pet\'s medical records in one place.',
    isImportant: false,
  },
  {
    question: 'How do I view my pet\'s health event history?',
    answer:
      'Go to the Trackers tab and tap on your pet\'s card, or tap \'View Events\' on any pet card. You\'ll see a chronological list of all health events with dates, types, and notes. Tap any event to see full details.',
    isImportant: false,
  },
  {
    question: 'Can I edit or delete a health event?',
    answer:
      'Yes, you can edit or delete health events. Open the event from your pet\'s health event list, tap \'Edit\' to modify details, or \'Delete\' to remove it. This helps you keep accurate health records.',
    isImportant: false,
  },
  {
    question: 'How do I set up medication reminders?',
    answer:
      'When creating a medication health event, toggle \'Create Reminder\' on. Enter the medication name, dosage, frequency (daily, twice daily, weekly, etc.), and set specific reminder times. You can set multiple reminder times per day for medications that need to be given multiple times.',
    isImportant: true,
  },
  {
    question: 'Can I track health events for multiple pets?',
    answer:
      'Yes! Each pet has their own health event history. When adding an event, select which pet it\'s for. Premium users can track unlimited pets, while free users can track one pet.',
    isImportant: false,
  },
  {
    question: 'What should I include in health event notes?',
    answer:
      'Include details like: symptoms observed, duration, severity, any triggers you noticed, what you did (if anything), and any follow-up actions needed. Detailed notes help you and your veterinarian identify patterns and make informed decisions about your pet\'s health.',
    isImportant: false,
  },
  {
    question: 'How can health event tracking help my veterinarian?',
    answer:
      'Regular health event tracking creates a detailed history that can help your veterinarian identify patterns, make diagnoses, and recommend treatments. You can share this information with your vet during visits to provide a complete picture of your pet\'s health over time.',
    isImportant: true,
  },
]

const nutritionFAQs: FAQArticle[] = [
  {
    question: 'How do I log a feeding for my pet?',
    answer:
      'Go to the Nutrition tab and tap \'Log Feeding\' or \'Add Feeding\'. Select your pet, choose the food item (search or scan a barcode), enter the amount in grams or cups, select the date and time, add optional notes, and tap \'Save\'. The feeding will be recorded in your pet\'s nutrition history.',
    isImportant: false,
  },
  {
    question: 'How do I track my pet\'s weight?',
    answer:
      'Go to the Nutrition tab and select \'Weight Management\'. Tap \'Record Weight\' to add a new weight entry. Enter the weight, date, and optional notes. The app will track weight trends over time and show you a chart of weight changes.',
    isImportant: false,
  },
  {
    question: 'How do I set a calorie goal for my pet?',
    answer:
      'In the Nutrition tab, go to \'Calorie Goals\' and tap \'Set Goal\'. Enter your pet\'s target daily calories, select the goal type (maintenance, weight loss, weight gain), set start and end dates, and save. The app will track your pet\'s progress toward this goal.',
    isImportant: false,
  },
  {
    question: 'What is a daily nutrition summary?',
    answer:
      'The daily nutrition summary shows you a complete breakdown of what your pet ate in a day, including total calories, protein, fat, carbohydrates, and fiber. It compares this to your pet\'s nutritional requirements and shows how much is remaining to meet daily goals.',
    isImportant: false,
  },
  {
    question: 'How do I view my pet\'s feeding history?',
    answer:
      'Go to the Nutrition tab and tap \'Feeding Log\' or \'Feeding History\'. You\'ll see a chronological list of all feedings with dates, times, food items, amounts, and notes. You can filter by date range or search for specific foods.',
    isImportant: false,
  },
  {
    question: 'Can I compare different foods?',
    answer:
      'Yes! In the Nutrition tab, go to \'Food Comparison\' and select multiple food items to compare. The app will show you side-by-side nutritional information, helping you choose the best food for your pet\'s needs.',
    isImportant: false,
  },
  {
    question: 'How do I set a weight goal for my pet?',
    answer:
      'In Weight Management, tap \'Set Weight Goal\'. Enter your target weight, select the goal type (weight loss or weight gain), set start and target dates, and add notes. The app will track progress and show you how close your pet is to reaching the goal.',
    isImportant: false,
  },
  {
    question: 'What are nutritional trends?',
    answer:
      'Nutritional trends show you patterns in your pet\'s nutrition over time. You can see trends for calories, protein, fat, and other nutrients across different time periods (weekly, monthly, etc.). This helps identify if your pet is getting consistent nutrition.',
    isImportant: false,
  },
  {
    question: 'How do I search for foods in the database?',
    answer:
      'When logging a feeding, tap \'Select Food\' and use the search bar to find foods by name or brand. You can also scan a barcode to quickly find a product. The database includes thousands of pet food products with complete nutritional information.',
    isImportant: false,
  },
  {
    question: 'What are nutritional requirements?',
    answer:
      'Nutritional requirements are the daily amounts of calories, protein, fat, carbohydrates, and fiber your pet needs based on their species, age, weight, and activity level. The app calculates these automatically and compares them to what your pet actually eats.',
    isImportant: false,
  },
  {
    question: 'Can I track nutrition for multiple pets?',
    answer:
      'Yes! Premium users can track nutrition for unlimited pets. Each pet has their own feeding logs, weight records, and nutrition goals. Free users can track one pet. Switch between pets using the pet selector in the Nutrition tab.',
    isImportant: false,
  },
  {
    question: 'How do I view advanced nutrition analytics?',
    answer:
      'In the Nutrition tab, tap \'Advanced Nutrition\' to see detailed analytics including health insights, nutritional patterns, trends over time, and personalized recommendations. These insights help you make informed decisions about your pet\'s diet.',
    isImportant: false,
  },
]

const privacyFAQs: FAQArticle[] = [
  {
    question: 'Is my pet\'s data secure?',
    answer:
      'We implement industry-standard security measures to protect your data, including encryption and secure storage practices. However, no system is 100% secure. We never share your personal information with third parties without your explicit consent, subject to our privacy policy.',
    isImportant: true,
  },
  {
    question: 'What information does the app collect?',
    answer:
      'We collect: pet profiles, scan results, and usage analytics for app functionality. We do not collect personal information like your name, address, or payment details (handled by Apple). For complete details, please review our privacy policy.',
    isImportant: false,
  },
  {
    question: 'Can I export my pet\'s data?',
    answer:
      'Yes, you can export your pet profiles and scan history through the app settings. This includes all your data in a readable format.',
    isImportant: false,
  },
  {
    question: 'How do I delete my account and data?',
    answer:
      'Go to Settings > Account > Delete Account. This will permanently remove all your data, including pet profiles and scan history. This action cannot be undone. Data deletion is subject to our privacy policy and applicable data protection laws.',
    isImportant: true,
  },
  {
    question: 'Do you share data with veterinarians?',
    answer:
      'No, we don\'t automatically share data with veterinarians. You can manually share scan results with your vet through the app\'s sharing features.',
    isImportant: false,
  },
  {
    question: 'Is my scan data used for research?',
    answer:
      'We may use anonymized, aggregated data to improve our ingredient database, but never your personal pet information or individual scan results. Any data usage is subject to our privacy policy and applicable privacy laws.',
    isImportant: false,
  },
  {
    question: 'How long is my data stored?',
    answer:
      'Your data is stored as long as your account is active. If you delete your account, all data is permanently removed within 30 days, subject to our privacy policy and applicable data protection laws.',
    isImportant: false,
  },
  {
    question: 'Can I use the app without creating an account?',
    answer:
      'Basic scanning features work without an account, but you\'ll need to create an account to save pet profiles and scan history.',
    isImportant: false,
  },
  {
    question: 'What about children\'s privacy?',
    answer:
      'SniffTest is not intended for children under 13. We don\'t knowingly collect information from children under 13 years of age. If you believe we have collected information from a child under 13, please contact us immediately.',
    isImportant: true,
  },
]

