# ISKSULARS TRACK

**Real-Time Student Leader & Organization Officer Locator for SKSU**

> [https://isksulars-track.web.app](https://isksulars-track.web.app)

## What it does

Students find their student leaders and organization officers on an interactive campus map, ping them for assistance, and browse a searchable directory. Leaders share their location and availability. Admins manage users, view analytics, and send broadcasts.

## Tech Stack

| Component | Technology |
|---|---|
| Frontend | Flutter 3.8+ (web, compiled to WebAssembly) |
| Auth | Firebase Authentication (email/password, @sksu.edu.ph enforced) |
| Database | Cloud Firestore (Spark free tier) |
| Hosting | Firebase Hosting |
| Maps | flutter_map (2D) + MapLibre GL (3D satellite) |
| Push | Firebase Cloud Messaging via GitHub Actions cron dispatcher |

## Quick Deploy

```bash
# 1. Install dependencies
flutter pub get

# 2. Build
flutter build web --release

# 3. Deploy (requires Firebase CLI)
npx firebase deploy --only hosting
```

## Push Notifications

Push notifications are dispatched by a GitHub Actions workflow that runs every 2 minutes (free tier). It reads Firestore notifications and sends them via FCM.

To activate:

1. Go to [GitHub Settings → Secrets → Actions](https://github.com/burikethhh/UniTrack/settings/secrets/actions)
2. Add a secret named `SERVICE_ACCOUNT_JSON` containing the full contents of your Firebase service account key

## Project Structure

```
lib/
├── main.dart                     # App entry, auth routing, theme
├── core/
│   ├── constants/                # App config, campuses, programs, orgs
│   ├── theme/                    # Light + dark M3 themes
│   └── utils/                    # Validators, helpers, connectivity
├── models/                       # User, Location, Notification models
├── providers/                    # Auth, Location, Faculty, Admin, Theme
├── screens/
│   ├── auth/                     # Login, Register, Email Verification
│   ├── student/                  # Map, Directory, Profile, Faculty Detail
│   ├── admin/                    # Dashboard, Users, Analytics, Broadcast
│   ├── staff/                    # Edit Profile, Notifications
│   └── common/                   # Help, Privacy
├── services/                     # Auth, Database, Location, Push, Broadcast
└── widgets/                     # Reusable UI components
```

## Role System

| Role | Permissions |
|---|---|
| `student` | Browse directory, view map, ping leaders |
| `studentLeader` | Same as student + share location/status, set office hours |
| `organizationOfficer` | Same as studentLeader |
| `admin` | Manage all users, view analytics, send broadcasts |

Role enforcement: Firestore rules prevent self-promotion. Only admins can change roles.

## Firestore Rules

- Users can read all profiles, write only their own (except role/isActive)
- Only admins can write role/isActive, delete users
- Location docs: owner-only writes with lat/lng validation
- Notifications: sender-UID enforcement
- Activity logs: immutable once written, create-only
- [Full rules](./firestore.rules)

## For Admins

See [docs/ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md) for instructions on managing users, broadcasts, and system settings.