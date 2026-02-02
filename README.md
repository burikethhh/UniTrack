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
- 📶 **Offline Mode** - Access cached faculty data without internet connection
- 🔔 **Push Notifications** - Get notified about important updates
- 🎓 **Onboarding Tutorial** - Guided tour for new users

### For Faculty/Staff
- 🔒 Privacy-first location sharing with full control
- ⏰ Automatic location hiding outside campus
- 💬 Quick status messages ("In office hours", "Available for consultation")
- ⚙️ Customizable privacy settings
- 📅 Schedule-based auto-hide
- 🏫 Campus-based geofencing
- 🟢 **Availability Status** - Set status (Available, Busy, In Meeting, Teaching, On Break, etc.)
- 📱 **Real-time Status Updates** - Students see your availability instantly

### For Administrators
- 📈 Analytics dashboard
- 👥 User management
- 🏢 Department management
- 📊 Usage statistics
- 🌐 Multi-campus oversight

## 🔮 Future Roadmap

### Kiosk Integration (IoT)
UniTrack will expand beyond mobile devices with **campus kiosk integration**:
- 🖥️ **Interactive Kiosk Displays** - Large touchscreen displays at strategic campus locations
- 📍 **Real-time Faculty Board** - Show all available faculty members on a dedicated screen
- 🗺️ **Wayfinding Stations** - Help visitors navigate to faculty offices
- 🔗 **API Integration** - RESTful API for third-party kiosk hardware
- 📊 **Digital Signage** - Display department-specific faculty availability
- 🎯 **QR Code Check-in** - Faculty can update their status via kiosk scan

### Planned IoT Features
- **Bluetooth Beacons** - Automatic indoor location detection
- **NFC Tags** - Tap to check-in at office doors
- **Smart Room Sensors** - Detect faculty presence in offices automatically
- **Integration Hub** - Connect with existing campus management systems

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

**Version**: 2.0.6  
**Last Updated**: February 2026
