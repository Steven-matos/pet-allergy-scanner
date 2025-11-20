# PostHog Complete Guide for SniffTest

This comprehensive guide covers everything you need to know about PostHog analytics integration in the SniffTest iOS application, including setup, implementation status, configuration, and best practices.

## Table of Contents

1. [Overview](#overview)
2. [Initial Setup](#initial-setup)
3. [Implementation Status](#implementation-status)
4. [Project Configuration](#project-configuration)
5. [Event Tracking](#event-tracking)
6. [User Identification & Properties](#user-identification--properties)
7. [Session Replay Configuration](#session-replay-configuration)
8. [Feature Flags](#feature-flags)
9. [Dashboards and Insights](#dashboards-and-insights)
10. [Privacy and Compliance](#privacy-and-compliance)
11. [Best Practices](#best-practices)
12. [Troubleshooting](#troubleshooting)
13. [Advanced Features](#advanced-features)
14. [Testing Checklist](#testing-checklist)
15. [Next Steps](#next-steps)

---

## Overview

PostHog is integrated into SniffTest to provide comprehensive analytics, session replay, and user behavior tracking. This guide covers:

- **Setup**: How to configure PostHog in your PostHog account
- **Implementation**: What's already implemented in the codebase
- **Configuration**: How to optimize PostHog for your needs
- **Best Practices**: Guidelines for effective analytics

**Status**: Core integrations complete ✅  
**Last Updated**: November 2025

---

## Initial Setup

### 1. Create PostHog Account

1. Go to [https://posthog.com](https://posthog.com)
2. Sign up for a PostHog account (free tier available)
3. Choose your deployment option:
   - **Cloud** (recommended for most apps): Managed by PostHog
   - **Self-hosted**: For maximum control and data sovereignty

### 2. Create a Project

1. After logging in, create a new project
2. Name it "SniffTest" or "SniffTest iOS"
3. Select "iOS" as the platform
4. Note your **Project API Key** (starts with `phc_`)
5. Note your **Project Host** URL (e.g., `https://us.i.posthog.com`)

### 3. Configure Project Settings

Navigate to **Project Settings** → **General**:

- **Project Name**: SniffTest
- **Timezone**: Set to your primary timezone
- **Data Retention**: Configure based on your needs (default: 1 year)
- **Session Recording**: Enable (required for session replay)

---

## Implementation Status

### ✅ Implemented Integrations

#### 1. User Identification ✅

**Location**: `AuthService.swift`

- **On Login**: User is identified with PostHog when they log in via:
  - `handleAuthResponse()` - Regular login
  - `handleEmailConfirmation()` - Email verification
  - `handleAuthCallback()` - OAuth callbacks
  
- **User Properties Set**:
  - `email`
  - `role` (free/premium)
  - `onboarded` (boolean)
  - `account_created_at`
  - `username` (if available)
  - `first_name` (if available)
  - `last_name` (if available)
  - `pets_count`

**Code**:
```swift
PostHogAnalytics.identifyUser(freshUser, petsCount: petsCount)
PostHogAnalytics.trackUserLoggedIn(userId: freshUser.id, role: freshUser.role.rawValue)
```

#### 2. User Reset on Logout ✅

**Location**: `AuthService.swift` - `logout()` method

- Tracks logout event
- Resets PostHog user identification

**Code**:
```swift
PostHogAnalytics.trackUserLoggedOut()
PostHogAnalytics.resetUser()
```

#### 3. Premium Upgrade Tracking ✅

**Location**: `RevenueCatSubscriptionProvider.swift`

- Tracks when user upgrades to premium
- Updates user role property
- Tracks tier (weekly/monthly/yearly) and product ID

**Code**:
```swift
PostHogAnalytics.trackPremiumUpgrade(tier: tier, productId: product.id)
PostHogAnalytics.updateUserRole("premium")
```

#### 4. Pet Management Events ✅

**Location**: `CachedPetService.swift`

- **Pet Created**: Tracks when a pet is added
- **Pet Updated**: Tracks when a pet is modified
- **Pet Deleted**: Tracks when a pet is removed
- Updates `pets_count` user property after each operation

**Code**:
```swift
PostHogAnalytics.trackPetCreated(petId: newPet.id, species: newPet.species.rawValue)
PostHogAnalytics.trackPetUpdated(petId: updatedPet.id, species: updatedPet.species.rawValue)
PostHogAnalytics.trackPetDeleted(petId: id, species: petSpecies)
PostHogAnalytics.updatePetCount(self.pets.count)
```

#### 5. Onboarding Completion Tracking ✅

**Location**: 
- `CachedPetService.swift` - `completeOnboarding()`
- `AuthService.swift` - `checkAndCompleteOnboardingIfNeeded()`

- Tracks when user completes onboarding
- Updates `onboarded` user property

**Code**:
```swift
PostHogAnalytics.trackOnboardingCompleted(petsCount: self.pets.count)
```

#### 6. User Property Updates ✅

**Location**: Multiple files

- **Pet Count**: Updated when pets are added/deleted
- **User Role**: Updated when subscription status changes
- **Onboarding Status**: Updated when onboarding completes

**Code**:
```swift
PostHogAnalytics.updatePetCount(count)
PostHogAnalytics.updateUserRole(role)
PostHogAnalytics.updateUserProperties(properties)
```

#### 7. Subscription Status Tracking ✅

**Location**: `RevenueCatSubscriptionProvider.swift` - `applyCustomerInfo()`

- Tracks when subscription becomes active
- Tracks when subscription expires/cancels
- Updates user role property accordingly

**Code**:
```swift
if hasActiveSubscription && !wasSubscribedBefore {
    PostHogAnalytics.updateUserRole("premium")
} else if !hasActiveSubscription && wasSubscribedBefore {
    PostHogAnalytics.updateUserRole("free")
}
```

#### 8. User Refresh Tracking ✅

**Location**: `AuthService.swift` - `refreshCurrentUser()`

- Updates user properties when user data is refreshed
- Detects role changes and updates PostHog
- Updates pet count

### 📊 Events Tracked

#### User Events
- `user_logged_in` - When user logs in
- `user_logged_out` - When user logs out
- `user_registered` - When user registers (method available, needs to be called)
- `premium_upgraded` - When user upgrades to premium
- `onboarding_completed` - When user completes onboarding

#### Pet Events
- `pet_created` - When pet is added
- `pet_updated` - When pet is modified
- `pet_deleted` - When pet is removed

#### Scanning Events
- `scan_view_opened` - When user opens scanning screen
- `scan_image_captured` - When user captures an image (with barcode detection status)
- `scan_completed` - When scan analysis finishes
  - Properties: `scan_id`, `has_allergens`, `allergen_count`, `product_found`
- `scan_failed` - When scan fails
  - Properties: `error`
- `barcode_detected` - When barcode is found
  - Properties: `barcode_type`
- `scan_history_viewed` - When user views scan history
- `pet_selected_for_scan` - When user selects a pet
  - Properties: `pet_id`, `pet_species`

#### Health Events
- `health_events_view_opened` - When health events view opens
  - Properties: `pet_id`
- `add_health_event_tapped` - When user taps add event
  - Properties: `pet_id`
- `health_event_viewed` - When user views an event
  - Properties: `event_id`, `event_category`
- `health_event_filter_changed` - When filter changes
  - Properties: `category`
- `health_events_refreshed` - When user refreshes
  - Properties: `pet_id`

#### Nutrition Events
- `nutrition_dashboard_opened` - When nutrition dashboard opens
- `nutrition_pet_selected` - When pet is selected
  - Properties: `pet_id`, `pet_species`
- `nutrition_premium_upgrade_tapped` - When upgrade button tapped
- `nutrition_section_viewed` - When section is viewed
  - Properties: `section`, `pet_id`

### 🔧 User Properties Tracked

- `email` - User email address
- `role` - User role (free/premium)
- `onboarded` - Whether user completed onboarding
- `account_created_at` - Account creation timestamp
- `pets_count` - Number of pets user has
- `username` - User username (if set)
- `first_name` - User first name (if set)
- `last_name` - User last name (if set)
- `role_updated_at` - When role was last updated
- `onboarded_at` - When onboarding was completed
- `premium_tier` - Subscription tier (when upgraded)
- `upgraded_at` - When premium upgrade occurred

### 📝 Files Modified

1. **PostHogAnalytics.swift**
   - Added user identification methods
   - Added user property update methods
   - Added pet management event tracking
   - Added onboarding completion tracking
   - Added premium upgrade tracking
   - Added Date extension for ISO8601 formatting

2. **AuthService.swift**
   - Added PostHog user identification on login
   - Added PostHog user reset on logout
   - Added onboarding completion tracking
   - Added user property updates on refresh

3. **CachedPetService.swift**
   - Added pet creation tracking
   - Added pet update tracking
   - Added pet deletion tracking
   - Added onboarding completion tracking

4. **RevenueCatSubscriptionProvider.swift**
   - Added premium upgrade tracking on purchase
   - Added subscription status change tracking
   - Added tier determination helper

---

## Project Configuration

### 1. Enable Required Features

Go to **Project Settings** → **Feature Flags & Experiments**:

- ✅ **Session Replay**: Enable
- ✅ **Feature Flags**: Enable (for A/B testing and gradual rollouts)
- ✅ **Surveys**: Optional (for user feedback)
- ✅ **Correlation Analysis**: Enable (helps identify issues)

### 2. Configure Session Replay

Navigate to **Project Settings** → **Session Replay**:

#### Recording Settings:
- **Recording Mode**: Screenshot mode (required for SwiftUI)
- **Minimum Duration**: 30 seconds (filter out accidental opens)
- **Sample Rate**: 100% (or adjust based on volume)
- **Record Console Logs**: Enable (helps with debugging)
- **Record Network Activity**: Enable (for API call tracking)

#### Privacy Settings:
- **Mask Text Inputs**: Enable (protects sensitive data)
- **Mask Images**: Disable (you need to see food labels)
- **Block Elements**: Add selectors for sensitive areas if needed
- **Block Network Requests**: Configure to block sensitive API endpoints

### 3. Set Up Data Retention

Go to **Project Settings** → **Data Management**:

- **Event Retention**: 1 year (adjust based on needs)
- **Session Replay Retention**: 90 days (adjust based on storage costs)
- **Person Profiles**: 1 year
- **Feature Flag Evaluations**: 90 days

---

## Event Tracking

### 1. Create Event Definitions

Go to **Data Management** → **Event Definitions**:

For each event, create a definition with:
- **Name**: Event name (e.g., `scan_completed`)
- **Description**: What the event represents
- **Tags**: Add tags like `scanning`, `health`, `nutrition` for organization
- **Property Definitions**: Define expected properties

Example for `scan_completed`:
```
Name: scan_completed
Description: User successfully completed a product scan
Tags: scanning, core-feature
Properties:
  - scan_id (string): Unique scan identifier
  - has_allergens (boolean): Whether allergens were detected
  - allergen_count (number): Number of allergens found
  - product_found (boolean): Whether product was found in database
```

### 2. Set Up Event Groups

Create event groups for better organization:

1. **Core Features**:
   - `scan_view_opened`
   - `scan_completed`
   - `scan_failed`

2. **User Actions**:
   - `pet_selected_for_scan`
   - `add_health_event_tapped`
   - `nutrition_pet_selected`

3. **Navigation**:
   - `scan_history_viewed`
   - `health_events_view_opened`
   - `nutrition_dashboard_opened`

---

## User Identification & Properties

### 1. Identify Users on Login

When a user logs in, they are automatically identified with PostHog. The implementation includes:

- User ID as distinct identifier
- User properties (email, role, onboarded status, etc.)
- Pet count
- Login event tracking

### 2. Set User Properties

User properties are automatically set and updated:

```swift
// Automatically called on login
PostHogAnalytics.identifyUser(user, petsCount: petsCount)

// Update properties when they change
PostHogAnalytics.updatePetCount(count)
PostHogAnalytics.updateUserRole(role)
```

### 3. Update User Properties

Properties are updated automatically when:
- User upgrades to premium
- Pets are added/deleted
- User completes onboarding
- Subscription status changes

### 4. Reset on Logout

User identification is automatically reset on logout:

```swift
PostHogAnalytics.trackUserLoggedOut()
PostHogAnalytics.resetUser()
```

---

## Session Replay Configuration

### 1. Enable Session Replay

Session replay is already enabled in your iOS app configuration. Verify in PostHog:

1. Go to **Session Replay** in the sidebar
2. Confirm recordings are appearing
3. Check recording quality and completeness

### 2. Configure Recording Filters

Set up filters to focus on important sessions:

#### Useful Filters:
- **Sessions with errors**: `has_errors = true`
- **Sessions with scan failures**: `event = scan_failed`
- **Long sessions**: `duration > 5 minutes`
- **Sessions with multiple scans**: `scan_completed count > 3`
- **Premium user sessions**: `user_role = premium`

### 3. Set Up Session Replay Alerts

Create alerts for critical issues:

1. Go to **Alerts** → **Create Alert**
2. Set conditions:
   - **Trigger**: When `scan_failed` events exceed threshold
   - **Frequency**: Daily or real-time
   - **Recipients**: Your team email

### 4. Configure Privacy Settings

Review and configure privacy settings:

1. **Mask Sensitive Data**:
   - Enable text input masking
   - Configure custom selectors for sensitive fields
   - Block network requests to sensitive endpoints

2. **Compliance**:
   - Enable GDPR compliance mode if applicable
   - Configure data retention policies
   - Set up data deletion workflows

---

## Feature Flags

### 1. Create Feature Flags

Feature flags allow you to:
- A/B test new features
- Gradually roll out features
- Enable features for specific user segments

#### Example Feature Flags for SniffTest:

**New Scanning UI**:
```
Flag Key: new-scanning-ui
Description: New improved scanning interface
Rollout: 10% of users initially
```

**Nutrition Recommendations**:
```
Flag Key: nutrition-recommendations
Description: AI-powered nutrition recommendations
Rollout: Premium users only
```

**Advanced Health Tracking**:
```
Flag Key: advanced-health-tracking
Description: Enhanced health event tracking features
Rollout: Gradual rollout starting at 25%
```

### 2. Implement Feature Flags in Code

Add feature flag checks in your iOS app:

```swift
// Example: Check if new scanning UI should be shown
let showNewScanningUI = PostHogSDK.shared.isFeatureEnabled("new-scanning-ui")
```

### 3. Set Up Feature Flag Experiments

Create experiments to test feature impact:

1. Go to **Experiments** → **New Experiment**
2. Define:
   - **Hypothesis**: What you're testing
   - **Control**: Current version
   - **Variant**: New feature
   - **Success Metric**: e.g., `scan_completed` rate
   - **Duration**: 2 weeks
   - **Sample Size**: Minimum users needed

---

## Dashboards and Insights

### 1. Create Core Dashboards

#### Dashboard 1: Scanning Analytics

**Metrics to Track**:
- Total scans per day/week/month
- Scan success rate (`scan_completed` / `scan_view_opened`)
- Scan failure rate (`scan_failed` / `scan_view_opened`)
- Average scans per user
- Barcode detection rate
- Product found rate

**Visualizations**:
- Line chart: Scans over time
- Pie chart: Scan success vs failures
- Bar chart: Scans by pet species
- Funnel: Scan completion funnel

#### Dashboard 2: Health Events Analytics

**Metrics to Track**:
- Health events added per day
- Most common event categories
- Events per pet
- Health event views
- Filter usage

**Visualizations**:
- Line chart: Events added over time
- Bar chart: Events by category
- Heatmap: Events by day of week
- Table: Top pets by event count

#### Dashboard 3: Nutrition Analytics

**Metrics to Track**:
- Nutrition dashboard views
- Pet selection frequency
- Premium upgrade clicks
- Section views

**Visualizations**:
- Line chart: Dashboard views over time
- Bar chart: Most viewed sections
- Conversion funnel: Dashboard → Upgrade

#### Dashboard 4: User Engagement

**Metrics to Track**:
- Daily/Monthly Active Users (DAU/MAU)
- Session duration
- Features used per session
- User retention (Day 1, Day 7, Day 30)
- Churn rate

**Visualizations**:
- Line chart: DAU/MAU trend
- Retention cohort table
- Bar chart: Average session duration
- Funnel: User onboarding flow

### 2. Set Up Key Insights

Create insights for important metrics:

1. **Scan Success Rate**:
   ```
   Formula: (scan_completed count) / (scan_view_opened count) * 100
   Alert: If rate drops below 80%
   ```

2. **Scan Failure Analysis**:
   ```
   Group by: error property
   Show: Top 10 error types
   Alert: If new error type appears frequently
   ```

3. **User Retention**:
   ```
   Metric: Retention rate
   Period: 7-day retention
   Alert: If retention drops significantly
   ```

### 3. Create Funnels

#### Scanning Funnel:
```
Step 1: scan_view_opened
Step 2: scan_image_captured
Step 3: scan_completed
```

**Analysis**:
- Identify drop-off points
- Calculate conversion rates
- Compare by user segments

#### Health Event Funnel:
```
Step 1: health_events_view_opened
Step 2: add_health_event_tapped
Step 3: health_event_created (if you add this event)
```

---

## Privacy and Compliance

### 1. Configure GDPR Settings

If serving EU users:

1. Go to **Project Settings** → **Privacy**
2. Enable **GDPR Compliance Mode**
3. Configure:
   - Data retention policies
   - Right to deletion workflows
   - Data export capabilities

### 2. Set Up Data Deletion

Configure automatic data deletion:

1. Go to **Project Settings** → **Data Management**
2. Set retention periods
3. Enable automatic deletion
4. Set up manual deletion workflows for user requests

### 3. Configure IP Anonymization

For privacy compliance:

1. Go to **Project Settings** → **Privacy**
2. Enable **IP Anonymization**
3. Configure geolocation data handling

### 4. Set Up Consent Management

If required by regulations:

1. Implement consent banner in app
2. Only initialize PostHog after consent
3. Provide opt-out mechanism
4. Track consent status as user property

---

## Best Practices

### 1. Event Naming Conventions

Follow consistent naming:
- ✅ Use snake_case: `scan_completed`
- ✅ Be descriptive: `health_event_viewed` not `event_viewed`
- ✅ Use present tense: `scan_completed` not `scan_complete`
- ✅ Group related events: `scan_*`, `health_*`, `nutrition_*`

### 2. Property Naming

- ✅ Use snake_case for properties
- ✅ Be consistent: `pet_id` not `petId` or `petID`
- ✅ Use appropriate types: strings for IDs, numbers for counts
- ✅ Include units: `duration_seconds`, `weight_kg`

### 3. Event Volume Management

- ✅ Track important events, not every click
- ✅ Use feature flags to control event volume
- ✅ Aggregate similar events when possible
- ✅ Monitor event volume to avoid costs

### 4. Error Tracking

Track errors with context:

```swift
PostHogAnalytics.trackScanFailed(
    error: error.localizedDescription
)
// Also include:
// - User ID
// - Device info
// - App version
// - Scan context
```

### 5. Performance Monitoring

Track performance metrics:

- Scan processing time
- API response times
- Image upload times
- App launch time

### 6. User Segmentation

Create user segments for analysis:

- **Free Users**: `role = free`
- **Premium Users**: `role = premium`
- **Active Scanners**: `scan_completed count > 10`
- **Health Trackers**: `health_events_view_opened count > 5`
- **New Users**: `account_created_at > 30 days ago`

---

## Troubleshooting

### 1. Events Not Appearing

**Check**:
- API key is correct in Info.plist
- PostHog host URL is correct
- Network connectivity
- PostHog dashboard filters
- Event name spelling (case-sensitive)

**Debug**:
- Enable debug mode in development
- Check PostHog logs
- Verify events in PostHog Live Events

### 2. Session Replay Not Working

**Check**:
- Session replay is enabled in PostHog
- Screenshot mode is enabled (required for SwiftUI)
- Recording filters aren't excluding sessions
- User has sufficient permissions

**Debug**:
- Check PostHog session replay settings
- Verify iOS app configuration
- Test with a known user session

### 3. User Identification Issues

**Check**:
- User ID is being set correctly
- User properties are being updated
- Reset is called on logout
- User ID format is consistent

### 4. High Event Volume

**Solutions**:
- Reduce event frequency
- Use sampling
- Aggregate events
- Review event definitions

### 5. Missing Properties

**Check**:
- Properties are being sent with events
- Property names match definitions
- Property types are correct
- Properties aren't being filtered out

---

## Advanced Features

### 1. Cohorts

Create user cohorts for targeted analysis:

- **Power Users**: Users with >50 scans
- **Health Focused**: Users with >20 health events
- **Premium Converters**: Free users who viewed upgrade

### 2. Correlation Analysis

Use correlation analysis to:
- Identify factors affecting scan success
- Find patterns in user behavior
- Discover feature relationships

### 3. Surveys

Set up in-app surveys:
- Post-scan satisfaction survey
- Feature request surveys
- Onboarding feedback

### 4. Webhooks

Set up webhooks for:
- Real-time notifications
- Integration with other tools
- Automated workflows

---

## Testing Checklist

### Implementation Verification

- [x] User identification works on login
- [x] User reset works on logout
- [x] Premium upgrade tracking works
- [x] Pet management events fire correctly
- [x] Onboarding completion tracking works
- [x] User properties update correctly
- [x] Subscription status changes tracked

### PostHog Dashboard Verification

- [ ] Verify events appear in PostHog dashboard
- [ ] Verify user properties are set correctly
- [ ] Test session replay includes user identification
- [ ] Verify event properties are captured correctly
- [ ] Check that user segments work correctly
- [ ] Test dashboards display data correctly

### Setup Checklist

- [ ] PostHog account created
- [ ] Project created
- [ ] API key and host configured in app
- [ ] Project settings configured
- [ ] Session Replay enabled
- [ ] Feature Flags enabled
- [ ] All events defined in PostHog
- [ ] Event properties documented
- [ ] Event groups created
- [ ] Dashboards created
- [ ] Alerts configured
- [ ] Privacy settings reviewed

---

## Next Steps

### Immediate Actions

1. **Week 1**: Complete initial setup and verify events are tracking
2. **Week 2**: Create dashboards and review initial data
3. **Week 3**: Set up alerts and monitoring
4. **Week 4**: Implement feature flags for A/B testing

### Optional Enhancements

1. **User Registration Tracking**
   - Method exists but needs to be called in registration flow
   - Location: Registration view/screen

2. **Error Tracking**
   - Global error handler not implemented
   - Could track API errors, network errors, etc.

3. **Screen View Tracking**
   - PostHog auto-tracks, but manual tracking could provide more control
   - Could add to key screens like onboarding, settings, etc.

4. **Performance Tracking**
   - Could track scan processing time
   - API response times
   - Image upload times

5. **Feature Flag Integration**
   - PostHog feature flags could be used for A/B testing
   - Gradual feature rollouts

### Ongoing Maintenance

- Review dashboards weekly
- Monitor event volume
- Iterate on tracking based on insights
- Update user segments as needed
- Review and optimize session replay filters

---

## Resources

- [PostHog Documentation](https://posthog.com/docs)
- [PostHog iOS SDK](https://posthog.com/docs/libraries/ios)
- [Session Replay Privacy](https://posthog.com/docs/session-replay/privacy)
- [Feature Flags Guide](https://posthog.com/docs/feature-flags)
- [PostHog Community](https://posthog.com/questions)

---

**Last Updated**: November 2025  
**App Version**: iOS App  
**PostHog Version**: 3.35.0+  
**Status**: Core integrations complete ✅

