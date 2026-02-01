# UniTrack - Real-Time Faculty & Staff Locator

**Sultan Kudarat State University (SKSU) Multi-Campus Navigation System**

Proposed by: **Christian Keth Aguacito**

## 📱 About

UniTrack is a mobile application designed to help students locate faculty and staff members on campus in real-time. The app uses GPS tracking to show the current location of available faculty members, making it easier for students to find and connect with their instructors.

### 🏛️ Supported Campuses

UniTrack now supports **3 SKSU Campuses**:
- **Isulan Campus** - Main campus at Kalawag II, Isulan
- **Tacurong Campus** - Tacurong City campus
- **ACCESS Campus** - EJC Montilla, Tacurong City

## 🌟 Features

### For Students
- 📍 View real-time locations of faculty members on campus
- 🔍 **Smart Faculty Search** - Search for specific faculty and see only their location on the map
- 🏫 **Multi-Campus Support** - Choose your campus during registration
- 🗺️ Interactive 2D/3D campus map with faculty markers
- 🚶 Get walking directions to faculty locations
- 📊 See faculty availability status (Available, Busy, In Class, etc.)
- 🎯 **Focused View** - When searching, only the searched faculty's marker shows on map

### For Faculty/Staff
- 🔒 Privacy-first location sharing with full control
- ⏰ Automatic location hiding outside campus
- 💬 Quick status messages ("In office hours", "Available for consultation")
- ⚙️ Customizable privacy settings
- 📅 Schedule-based auto-hide
- 🏫 Campus-based geofencing

### For Administrators
- 📈 Analytics dashboard
- 👥 User management
- 🏢 Department management
- 📊 Usage statistics
- 🌐 Multi-campus oversight

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.38+
- **Backend**: Firebase (Firestore, Authentication)
- **Maps**: OpenStreetMap with flutter_map
- **State Management**: Provider
- **Location**: Geolocator

## 🚀 Getting Started

### Prerequisites

1. Flutter SDK (3.38 or later)
2. Android Studio / VS Code
3. Firebase account

### Firebase Setup

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for detailed instructions.

### Installation

```bash
# Clone or download the project
cd UniTrack

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Build APK

```bash
# Debug build
flutter build apk --debug

# Release build (requires signing)
flutter build apk --release
```

## 📂 Project Structure

```
lib/
├── core/
│   ├── constants/     # App-wide constants
│   └── theme/         # Theme and colors
├── models/            # Data models
├── providers/         # State management
├── screens/
│   ├── auth/          # Login & Register
│   ├── student/       # Student module
│   ├── staff/         # Staff/Faculty module
│   └── admin/         # Admin module
├── services/          # Firebase & API services
├── widgets/
│   ├── common/        # Reusable widgets
│   └── map/           # Map-related widgets
└── main.dart          # App entry point
```

## 🔐 Privacy & Security

- Location sharing is **opt-in** for staff
- Automatic location hiding outside campus boundaries
- No location history stored
- Staff can disable tracking at any time
- All data encrypted in transit

## 🎨 Theme Colors

- **Primary**: #003366 (SKSU Blue)
- **Accent**: #009933 (SKSU Green)
- **Available**: #4CAF50 (Green)
- **Busy**: #FF9800 (Orange)
- **Unavailable**: #F44336 (Red)

## 📱 Minimum Requirements

- Android 5.0 (API 21) or higher
- iOS 12.0 or higher (if deploying to iOS)
- Location services enabled

## 📜 License

© 2026 Sultan Kudarat State University. All rights reserved.

---

**Version**: 2.0.0 (Multi-Campus Premium Edition)  
**Last Updated**: January 2026
