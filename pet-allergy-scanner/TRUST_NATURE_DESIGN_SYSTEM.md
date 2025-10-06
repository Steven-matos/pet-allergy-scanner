# Trust & Nature Design System
## SniffTest iOS App - Pet Nutrition & Allergy Scanner

### Overview
This design system defines the visual language for the SniffTest iOS app, creating a warm, trustworthy, and natural feeling that aligns with our mission of providing reliable, nature-inspired health solutions for pets.

---

## 🎨 Brand Identity

### Core Values
- **Trust**: Reliable, professional, and trustworthy
- **Nature**: Natural, organic, and health-focused
- **Care**: Warm, caring, and pet-centric
- **Simplicity**: Clean, intuitive, and accessible

### Design Philosophy
- **Warm & Inviting**: Soft colors and natural tones
- **Professional**: Clean typography and consistent spacing
- **Accessible**: High contrast and readable text
- **Cohesive**: Unified experience across all features

---

## 🌿 Color Palette

### Primary Colors
```swift
// Deep Forest Green - Primary brand color
ModernDesignSystem.Colors.primary = Color(hex: "#2D5016")
// Usage: Primary actions, health indicators, success states

// Warm Coral - Attention and warmth
ModernDesignSystem.Colors.warmCoral = Color(hex: "#E67E22")
// Usage: Warnings, alerts, weight management, health risks

// Golden Yellow - Highlights and insights
ModernDesignSystem.Colors.goldenYellow = Color(hex: "#F39C12")
// Usage: Feeding consistency, optimization suggestions, insights
```

### Supporting Colors
```swift
// Soft Cream - Card backgrounds
ModernDesignSystem.Colors.softCream = Color(hex: "#F8F6F0")
// Usage: Card backgrounds, surface elements

// Charcoal Gray - Primary text
ModernDesignSystem.Colors.textPrimary = Color(hex: "#2C3E50")
// Usage: Main text, headings, important information

// Light Gray - Secondary text
ModernDesignSystem.Colors.textSecondary = Color(hex: "#BDC3C7")
// Usage: Secondary text, labels, descriptions

// Border Primary - Card outlines
ModernDesignSystem.Colors.borderPrimary = Color(hex: "#95A5A6")
// Usage: Card borders, input field borders
```

### Semantic Colors
```swift
// Success states
ModernDesignSystem.Colors.safe = Color(hex: "#27AE60")
// Warning states  
ModernDesignSystem.Colors.warning = Color(hex: "#F39C12")
// Error states
ModernDesignSystem.Colors.error = Color(hex: "#E74C3C")
```

---

## 📝 Typography

### Font Hierarchy
```swift
// Display styles
ModernDesignSystem.Typography.largeTitle = Font.largeTitle.weight(.bold)
ModernDesignSystem.Typography.title = Font.title.weight(.semibold)
ModernDesignSystem.Typography.title2 = Font.title2.weight(.semibold)
ModernDesignSystem.Typography.title3 = Font.title3.weight(.medium)

// Body styles
ModernDesignSystem.Typography.body = Font.body
ModernDesignSystem.Typography.bodyEmphasized = Font.body.weight(.medium)
ModernDesignSystem.Typography.callout = Font.callout
ModernDesignSystem.Typography.subheadline = Font.subheadline
ModernDesignSystem.Typography.footnote = Font.footnote
ModernDesignSystem.Typography.caption = Font.caption
ModernDesignSystem.Typography.caption2 = Font.caption2

// Monospace for codes
ModernDesignSystem.Typography.code = Font.system(.body, design: .monospaced)
ModernDesignSystem.Typography.codeLarge = Font.system(.title2, design: .monospaced)
```

### Usage Guidelines
- **Large Title**: App titles, major headings
- **Title**: Section headers, important labels
- **Title2**: Card headers, pet names
- **Title3**: Subsection headers, component titles
- **Body**: Main content, descriptions
- **Subheadline**: Labels, secondary information
- **Caption**: Small text, metadata, weight information
- **Code**: Technical information, IDs

---

## 📏 Spacing System

### Spacing Scale
```swift
ModernDesignSystem.Spacing.xs = 4    // Extra small - tight spacing
ModernDesignSystem.Spacing.sm = 8   // Small - compact elements
ModernDesignSystem.Spacing.md = 16  // Medium - standard spacing
ModernDesignSystem.Spacing.lg = 24  // Large - section spacing
ModernDesignSystem.Spacing.xl = 32  // Extra large - major sections
```

### Usage Guidelines
- **xs (4px)**: Text line spacing, icon padding
- **sm (8px)**: Element spacing within cards
- **md (16px)**: Standard spacing between elements
- **lg (24px)**: Section spacing, card padding
- **xl (32px)**: Major section separation

---

## 🔲 Corner Radius

### Radius Scale
```swift
ModernDesignSystem.CornerRadius.small = 8   // Small elements, tags
ModernDesignSystem.CornerRadius.medium = 12 // Cards, buttons
ModernDesignSystem.CornerRadius.large = 16  // Large containers
```

### Usage Guidelines
- **Small (8px)**: Tags, small buttons, input fields
- **Medium (12px)**: Cards, main buttons, containers
- **Large (16px)**: Large containers, modal backgrounds

---

## 🌟 Shadows

### Shadow System
```swift
ModernDesignSystem.Shadows.small = Shadow(
    color: Color.black.opacity(0.1),
    radius: 2,
    x: 0,
    y: 1
)

ModernDesignSystem.Shadows.medium = Shadow(
    color: Color.black.opacity(0.15),
    radius: 4,
    x: 0,
    y: 2
)

ModernDesignSystem.Shadows.large = Shadow(
    color: Color.black.opacity(0.2),
    radius: 8,
    x: 0,
    y: 4
)
```

### Usage Guidelines
- **Small**: Cards, buttons, subtle elevation
- **Medium**: Modals, important cards
- **Large**: Major overlays, prominent elements

---

## 🧩 Component Patterns

### Card Components
```swift
// Standard card styling
.padding(ModernDesignSystem.Spacing.lg)
.background(ModernDesignSystem.Colors.softCream)
.overlay(
    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
)
.cornerRadius(ModernDesignSystem.CornerRadius.medium)
.shadow(
    color: ModernDesignSystem.Shadows.small.color,
    radius: ModernDesignSystem.Shadows.small.radius,
    x: ModernDesignSystem.Shadows.small.x,
    y: ModernDesignSystem.Shadows.small.y
)
```

### Button Components
```swift
// Primary button
.modernButton(style: .primary)

// Secondary button
.modernButton(style: .secondary)
```

### Input Field Components
```swift
// Standard input field
.modernInputField()
```

### Loading Components
```swift
// Loading states
ModernLoadingView(message: "Loading...")
```

---

## 📊 Data Visualization

### Chart Colors
```swift
// Calorie trends
Chart colors: ModernDesignSystem.Colors.goldenYellow

// Macronutrient trends
Protein: ModernDesignSystem.Colors.warmCoral
Fat: ModernDesignSystem.Colors.primary
Fiber: ModernDesignSystem.Colors.goldenYellow

// Feeding patterns
Bars: ModernDesignSystem.Colors.primary
Line: ModernDesignSystem.Colors.goldenYellow

// Health scores
80+: ModernDesignSystem.Colors.primary (excellent)
60-79: ModernDesignSystem.Colors.goldenYellow (good)
<60: ModernDesignSystem.Colors.warmCoral (needs attention)
```

### Trend Indicators
```swift
// Increasing trends
Image(systemName: "arrow.up.right")
    .foregroundColor(ModernDesignSystem.Colors.primary)

// Decreasing trends
Image(systemName: "arrow.down.right")
    .foregroundColor(ModernDesignSystem.Colors.warmCoral)

// Stable trends
Image(systemName: "minus")
    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
```

---

## 🐾 Pet Selection Components

### Pet Selection Cards
```swift
// Pet image styling
.frame(width: 50, height: 50)
.clipShape(Circle())
.overlay(
    Circle()
        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 2)
)

// Pet information layout
VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
    Text(pet.name)
        .font(ModernDesignSystem.Typography.title3)
        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
    
    Text(pet.species.rawValue.capitalized)
        .font(ModernDesignSystem.Typography.subheadline)
        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
    
    if let weight = pet.weightKg {
        Text(unitService.formatWeight(weight))
            .font(ModernDesignSystem.Typography.caption)
            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
    }
}
```

---

## 🎯 Navigation & Tab Styling

### Tab Selection
```swift
// Active tab styling
.background(ModernDesignSystem.Colors.softCream)
.overlay(
    Rectangle()
        .frame(height: 3)
        .foregroundColor(ModernDesignSystem.Colors.primary),
    alignment: .bottom
)

// Tab icons and text
Image(systemName: tabIcon)
    .font(ModernDesignSystem.Typography.title3)
    .foregroundColor(selectedTab == index ? 
        ModernDesignSystem.Colors.primary : 
        ModernDesignSystem.Colors.textSecondary)

Text(tabTitle)
    .font(ModernDesignSystem.Typography.caption)
    .fontWeight(selectedTab == index ? .semibold : .regular)
    .foregroundColor(selectedTab == index ? 
        ModernDesignSystem.Colors.primary : 
        ModernDesignSystem.Colors.textSecondary)
```

### Navigation Bar
```swift
.toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
.toolbarColorScheme(.light, for: .navigationBar)
```

---

## 📱 View-Specific Implementations

### Weight Management Views
- **Cards**: Soft cream backgrounds with border primary outlines
- **Progress Indicators**: Color-coded based on health status
- **Charts**: Trust & Nature color palette for data visualization
- **Input Fields**: Modern input field styling with proper spacing

### Trends Views
- **Summary Cards**: Grid layout with Trust & Nature colors
- **Charts**: Consistent color coding across all chart types
- **Insights**: Golden yellow lightbulb icons for recommendations
- **Correlation Cards**: Color-coded strength indicators

### Analytics Views
- **Health Insights**: Color-coded health scores and risk indicators
- **Pattern Cards**: Soft cream backgrounds with optimization suggestions
- **Summary Cards**: Grid layout with semantic color usage

### Pet Selection Views
- **Selection Cards**: Consistent card styling with pet information
- **Empty States**: Trust & Nature typography and colors
- **Loading States**: Modern loading view implementation

---

## 🔧 Implementation Guidelines

### DO's
✅ Use `ModernDesignSystem` for all styling
✅ Apply consistent spacing using the spacing scale
✅ Use semantic colors for different states
✅ Maintain proper typography hierarchy
✅ Apply shadows for depth and elevation
✅ Use soft cream backgrounds for cards
✅ Apply border primary for card outlines

### DON'Ts
❌ Use system colors directly (Color.blue, Color.red, etc.)
❌ Use hardcoded spacing values
❌ Mix different corner radius values
❌ Use inconsistent shadow styles
❌ Apply colors that don't match the Trust & Nature palette
❌ Use system typography without ModernDesignSystem

---

## 🎨 Color Usage Examples

### Health & Nutrition
- **Excellent Health (80+)**: Deep Forest Green
- **Good Health (60-79)**: Golden Yellow  
- **Needs Attention (<60)**: Warm Coral
- **Health Risks**: Warm Coral
- **Positive Indicators**: Deep Forest Green
- **Optimization Suggestions**: Golden Yellow

### Data Visualization
- **Calorie Trends**: Golden Yellow
- **Protein Data**: Warm Coral
- **Fat Data**: Deep Forest Green
- **Fiber Data**: Golden Yellow
- **Feeding Patterns**: Deep Forest Green (bars), Golden Yellow (line)

### Interactive Elements
- **Primary Actions**: Deep Forest Green
- **Secondary Actions**: Soft Cream with border
- **Warnings**: Warm Coral
- **Success States**: Deep Forest Green
- **Information**: Golden Yellow

---

## 📋 Checklist for New Components

When creating new components, ensure:

- [ ] Uses `ModernDesignSystem` for all styling
- [ ] Applies consistent spacing using the spacing scale
- [ ] Uses Trust & Nature color palette
- [ ] Follows typography hierarchy
- [ ] Applies proper shadows and borders
- [ ] Uses semantic colors for different states
- [ ] Maintains consistent corner radius
- [ ] Follows card component patterns
- [ ] Includes proper accessibility considerations
- [ ] Tests with different content lengths

---

## 🔄 Maintenance

### Regular Updates
- Review color accessibility ratios
- Update spacing scale if needed
- Ensure consistency across all views
- Test with different device sizes
- Validate with user feedback

### Version Control
- Document any changes to the design system
- Update this file when making modifications
- Ensure all team members have access to latest version
- Maintain backward compatibility when possible

---

*This design system ensures a cohesive, professional, and trustworthy user experience that aligns with the SniffTest brand values of nature, care, and reliability.*
