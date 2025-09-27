# iOS App CORS Configuration Guide

## Overview

This guide explains how to configure CORS for iOS apps that will consume the Pet Allergy Scanner API. iOS apps use custom URL schemes rather than traditional HTTP origins, which requires special CORS configuration.

## iOS App URL Schemes

### Capacitor/Ionic Apps
- **Development**: `capacitor://localhost` or `ionic://localhost`
- **Production**: `capacitor://your-app-id` or `ionic://your-app-id`

### React Native Apps
- **Development**: `http://localhost:8081` (Metro bundler)
- **Production**: Custom scheme like `yourapp://`

### Native iOS Apps
- **Custom Scheme**: `yourapp://` (defined in Info.plist)

## Current Configuration

The server is configured to allow the following origins by default:

```python
allowed_origins = [
    "http://localhost:3000",      # Web development
    "http://localhost:8080",      # Web development
    "capacitor://localhost",      # Capacitor iOS development
    "ionic://localhost",          # Ionic iOS development
    "http://localhost",           # General localhost
    "https://localhost"           # HTTPS localhost
]
```

## Production Configuration

For production, you'll need to update the `ALLOWED_ORIGINS` environment variable:

```bash
# Example production configuration
ALLOWED_ORIGINS=https://yourdomain.com,capacitor://com.yourcompany.petallergyscanner,yourapp://
```

## iOS App Setup

### 1. Capacitor/Ionic Apps

In your `capacitor.config.ts`:

```typescript
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.yourcompany.petallergyscanner',
  appName: 'Pet Allergy Scanner',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
    iosScheme: 'capacitor'
  }
};

export default config;
```

### 2. React Native Apps

In your `metro.config.js`:

```javascript
module.exports = {
  resolver: {
    sourceExts: ['js', 'json', 'ts', 'tsx', 'jsx'],
  },
  server: {
    port: 8081,
  },
};
```

### 3. Native iOS Apps

In your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.petallergyscanner</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

## API Client Configuration

### Swift/iOS Example

```swift
import Foundation

class APIClient {
    private let baseURL = "https://your-api-domain.com/api/v1"
    
    func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        if let token = UserDefaults.standard.string(forKey: "auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }.resume()
    }
}
```

### JavaScript/TypeScript Example (Capacitor)

```typescript
import { CapacitorHttp } from '@capacitor/core';

class APIClient {
  private baseURL = 'https://your-api-domain.com/api/v1';
  
  async makeRequest<T>(
    endpoint: string,
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
    body?: any
  ): Promise<T> {
    const options = {
      url: `${this.baseURL}${endpoint}`,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${await this.getAuthToken()}`
      },
      method: method
    };
    
    if (body) {
      options.data = body;
    }
    
    const response = await CapacitorHttp.request(options);
    return response.data;
  }
  
  private async getAuthToken(): Promise<string> {
    // Get stored auth token
    return localStorage.getItem('auth_token') || '';
  }
}
```

## Testing CORS Configuration

### 1. Test with curl

```bash
# Test from iOS app origin
curl -H "Origin: capacitor://localhost" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type,Authorization" \
     -X OPTIONS \
     https://your-api-domain.com/api/v1/auth/login
```

### 2. Test with JavaScript

```javascript
// Test CORS from iOS app
fetch('https://your-api-domain.com/api/v1/health', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
  },
})
.then(response => response.json())
.then(data => console.log('CORS test successful:', data))
.catch(error => console.error('CORS test failed:', error));
```

## Troubleshooting

### Common Issues

1. **CORS Error**: "Access to fetch at '...' from origin 'capacitor://localhost' has been blocked by CORS policy"
   - **Solution**: Add your iOS app's URL scheme to `ALLOWED_ORIGINS`

2. **Preflight Request Fails**: OPTIONS request returns 403
   - **Solution**: Ensure CORS middleware is properly configured and origins are correct

3. **Authentication Issues**: JWT tokens not being sent
   - **Solution**: Check that Authorization header is properly set in your API client

### Debug Steps

1. Check server logs for CORS-related errors
2. Verify the Origin header in browser dev tools
3. Test with different URL schemes
4. Check that the CORS middleware is applied in the correct order

## Security Considerations

1. **Production Origins**: Only add production app schemes to avoid security issues
2. **HTTPS**: Always use HTTPS in production
3. **Token Security**: Store JWT tokens securely (Keychain on iOS)
4. **Certificate Pinning**: Consider implementing certificate pinning for additional security

## Environment-Specific Configuration

### Development
```bash
ALLOWED_ORIGINS=http://localhost:3000,capacitor://localhost,ionic://localhost
```

### Staging
```bash
ALLOWED_ORIGINS=https://staging.yourdomain.com,capacitor://com.yourcompany.petallergyscanner.staging
```

### Production
```bash
ALLOWED_ORIGINS=https://yourdomain.com,capacitor://com.yourcompany.petallergyscanner
```

## Additional Resources

- [Capacitor HTTP Plugin](https://capacitorjs.com/docs/apis/http)
- [iOS URL Schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [CORS Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [FastAPI CORS](https://fastapi.tiangolo.com/tutorial/cors/)

---

**Last Updated**: December 2024
**Version**: 1.0.0
