# Traverse iOS App

A beautiful iOS app built with SwiftUI featuring a stunning onboarding experience and backend integration.

## Features

### ✨ Onboarding Experience
- **Unified Design** - Consistent onboarding style for both sign-up and sign-in
- **Account Type Selection** - Choose between creating new account or signing in
- **Haptic Feedback** - Tactile response on every button interaction
- **Back Navigation** - Go back at any step in the onboarding flow
- Smooth gradient animations
- Text carousel with rotating feature highlights
- Multi-step registration form
- Beautiful transitions and animations
- Responsive design

### 🔐 Authentication
- User registration with backend API
- User login with existing credentials
- Secure token storage in iOS Keychain
- Automatic session management
- Logout capability
- Seamless account type switching

### 🛠 Technical Stack
- **SwiftUI** - Modern declarative UI framework
- **Async/Await** - Modern Swift concurrency
- **Keychain** - Secure credential storage
- **REST API** - Backend integration

## Backend Integration

The app connects to the Traverse backend API at:
```
https://traverse-backend-api.azurewebsites.net/api
```

### Supported Endpoints

#### Register User
```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "string",
  "email": "string",
  "password": "string",
  "timezone": "string"
}
```

**Response (201):**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": 1,
    "username": "johndoe",
    "email": "john@example.com",
    "timezone": "America/New_York",
    "visibility": "public",
    "currentStreak": 0,
    "totalXp": 0,
    "createdAt": "2025-12-21T10:00:00.000Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "string",
  "password": "string"
}
```

**Response (200):**
```json
{
  "message": "Login successful",
  "user": { /* user object */ }
}
```

## Project Structure

```
traverse/
├── Models/
│   ├── AuthModels.swift       # API request/response models
│   └── AuthViewModel.swift    # Authentication state management
├── Services/
│   ├── NetworkService.swift   # API communication layer
│   └── KeychainHelper.swift   # Secure token storage
├── Views/
│   ├── Step.swift             # Form step component
│   ├── ContinueButton.swift   # Action button component
│   ├── InputField.swift       # Text input component
│   ├── TextCarousel.swift     # Animated carousel
│   ├── CompletionStep.swift   # Completion animation
│   └── MultiStepForm.swift    # Multi-step form logic
├── Screens/
│   └── WelcomeScreen.swift    # Welcome/splash screen
├── OnboardingFlow.swift       # Main onboarding coordinator
├── ContentView.swift          # Root view with auth routing
└── traverseApp.swift          # App entry point
```

## Key Components

### AuthViewModel
Manages authentication state and coordinates with the NetworkService:
- User registration
- Login/logout
- Session persistence
- Error handling

### NetworkService
Handles all API communication:
- RESTful API calls
- JSON encoding/decoding
- Error handling
- Token management

### KeychainHelper
Provides secure storage for authentication tokens:
- Save token
- Retrieve token
- Delete token

### OnboardingFlow
Beautiful multi-step onboarding experience:
- Animated gradients
- Text carousel
- Form validation
- Smooth transitions

## Security

- **Keychain Storage**: Authentication tokens are securely stored in iOS Keychain
- **HTTPS**: All API communication uses HTTPS
- **Token-based Auth**: Stateless authentication using JWT tokens

## Getting Started

1. Open `traverse.xcodeproj` in Xcode
2. Build and run the project (⌘R)
3. Complete the onboarding flow to create an account
4. Your session will persist until you logout

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## Notes

- The app uses system SF Symbols for icons
- Placeholder images from FuseAppOnboarding are used for the carousel
- Add custom images to `Assets.xcassets` for branding

## Future Enhancements

- [ ] Password strength validation
- [ ] Email verification
- [ ] Social login (Apple, Google)
- [ ] Biometric authentication
- [ ] Password reset flow
- [ ] Custom logo and branding
- [ ] Error alerts and user feedback
- [ ] Form validation with real-time feedback
- [ ] Loading states and retry logic

## License

MIT License
