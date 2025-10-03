# Push Notifications Setup Guide

This guide explains how to set up and configure push notifications for the Pet Allergy Scanner app using Apple Push Notification service (APNs).

## Overview

The app now supports push notifications for:
- **Engagement reminders**: Weekly and monthly reminders to scan pet food
- **Birthday celebrations**: Surprise notifications during pet birth months
- **Real-time notifications**: Immediate notifications for important events

## Architecture

### iOS App Components

1. **PushNotificationService.swift**: Core service for APNs integration
2. **NotificationSettingsManager.swift**: Updated to support push notifications
3. **AppDelegate**: Handles device token registration
4. **APIService.swift**: Client-side API calls for push notifications

### Server Components

1. **notifications.py**: FastAPI router for push notification endpoints
2. **push_notification_service.py**: Server-side APNs integration
3. **Database**: Updated user table with device_token column

## Setup Instructions

### 1. Apple Developer Account Setup

1. **Create APNs Key**:
   - Go to [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list)
   - Click "+" to create a new key
   - Enable "Apple Push Notifications service (APNs)"
   - Download the `.p8` file and note the Key ID

2. **Get Team ID**:
   - Find your Team ID in the Apple Developer Console
   - Usually found in the top-right corner of the developer portal

3. **App Bundle ID**:
   - Ensure your app has a unique bundle identifier
   - Example: `com.yourcompany.pet-allergy-scanner`

### 2. iOS App Configuration

The app is already configured with:
- ✅ Push notification entitlements
- ✅ APNs environment settings
- ✅ Device token registration
- ✅ Notification handling

### 3. Server Configuration

1. **Install Dependencies**:
   ```bash
   pip install aiohttp PyJWT cryptography
   ```

2. **Environment Variables**:
   Add these to your `.env` file:
   ```env
   # Push Notification Configuration (APNs)
   APNS_URL=https://api.sandbox.push.apple.com  # Use production URL for release
   APNS_KEY_ID=your_apns_key_id_here
   APNS_TEAM_ID=your_apns_team_id_here
   APNS_BUNDLE_ID=com.yourcompany.pet-allergy-scanner
   APNS_PRIVATE_KEY=your_apns_private_key_content_here
   ```

3. **Database Migration**:
   Run the migration script in your Supabase SQL editor:
   ```sql
   -- Add device_token column to users table
   ALTER TABLE public.users 
   ADD COLUMN IF NOT EXISTS device_token TEXT;
   
   -- Add index for device_token lookups
   CREATE INDEX IF NOT EXISTS idx_users_device_token ON public.users(device_token);
   ```

### 4. Testing Push Notifications

1. **Development Testing**:
   - Use the sandbox APNs URL
   - Test on physical devices (simulator doesn't support push notifications)
   - Check device token registration in server logs

2. **Production Deployment**:
   - Change `APNS_URL` to `https://api.push.apple.com`
   - Ensure your app is signed with production certificates
   - Test thoroughly before release

## API Endpoints

### Register Device Token
```http
POST /api/v1/notifications/register-device
Content-Type: application/json
Authorization: Bearer <token>

{
  "device_token": "device_token_here"
}
```

### Send Push Notification
```http
POST /api/v1/notifications/send
Content-Type: application/json
Authorization: Bearer <token>

{
  "device_token": "device_token_here",
  "payload": {
    "aps": {
      "alert": {
        "title": "Notification Title",
        "body": "Notification Body"
      },
      "sound": "default",
      "badge": 1
    },
    "type": "engagement_reminder",
    "action": "navigate_to_scan"
  }
}
```

### Schedule Engagement Notifications
```http
POST /api/v1/notifications/schedule-engagement
Authorization: Bearer <token>
```

### Send Birthday Notification
```http
POST /api/v1/notifications/send-birthday
Content-Type: application/json
Authorization: Bearer <token>

{
  "pet_name": "Buddy",
  "pet_id": "pet_uuid_here"
}
```

## Notification Types

### Engagement Notifications

1. **Weekly Reminder** (7 days):
   - Title: "🔍 Time for a Scan!"
   - Body: "Keep your pet safe by scanning their food ingredients regularly."

2. **Monthly Reminder** (30 days):
   - Title: "🐾 We Miss You!"
   - Body: "It's been a while since your last scan. Your pet's health is important to us."

### Birthday Notifications

- **Birthday Celebration**:
  - Title: "🎉 Surprise! It's [Pet Name]'s Birthday Month! 🎂"
  - Body: "This month is [Pet Name]'s special time! Time to celebrate! 🐾✨"

## Implementation Details

### iOS App Flow

1. **App Launch**: Request push notification permissions
2. **Device Token**: Register with APNs and send to server
3. **Scan Completion**: Update last scan date and reschedule notifications
4. **Notification Tap**: Handle navigation to appropriate views

### Server Flow

1. **Token Registration**: Store device token in user record
2. **Notification Scheduling**: Queue notifications with delays
3. **APNs Integration**: Send notifications via Apple's servers
4. **Error Handling**: Log failures and retry logic

## Security Considerations

1. **Device Token Storage**: Securely stored in database
2. **APNs Authentication**: JWT tokens with short expiration
3. **User Authorization**: All endpoints require authentication
4. **Rate Limiting**: Prevents notification spam

## Troubleshooting

### Common Issues

1. **No Notifications Received**:
   - Check device token registration
   - Verify APNs configuration
   - Ensure app has notification permissions

2. **Invalid Device Token**:
   - Token may have expired
   - User may have reinstalled app
   - Check APNs response codes

3. **Server Errors**:
   - Verify APNs key configuration
   - Check network connectivity
   - Review server logs

### Debug Tools

1. **iOS Console**: Check for APNs errors
2. **Server Logs**: Monitor notification sending
3. **APNs Feedback**: Check for invalid tokens

## Monitoring and Analytics

The system includes:
- Notification delivery tracking
- Error logging and monitoring
- User engagement metrics
- Performance optimization

## Future Enhancements

Potential improvements:
- Rich media notifications
- Notification categories
- User preference management
- A/B testing for notification content
- Advanced scheduling options

## Support

For issues or questions:
1. Check server logs for errors
2. Verify APNs configuration
3. Test with development certificates first
4. Review Apple's APNs documentation

---

**Note**: This implementation follows Apple's best practices and security guidelines for push notifications. Always test thoroughly in development before deploying to production.
