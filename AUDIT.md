# ISKSULARS TRACK — Complete Project Audit

> **Date:** April 8, 2026 (Updated July 27, 2026)
> **Version:** 2.4.0 (Build 265)
> **Platform:** Flutter 3.38+ / Dart 3.10.7+ — Android, iOS, Web

> **2026-07-27 Migration Note:** The app has been migrated from a 3-role "faculty/staff locator" model to a 4-role "student leaders & organization officers locator" model. Roles are now: **student**, **studentLeader**, **organizationOfficer**, **admin**. The old `staff` role has been removed and mapped to `studentLeader`. Many references in this audit document still use the original "faculty/staff" terminology — the functional implementation in code has been updated. See the changelog at the end more recent updates.
> **Backend:** Firebase (Auth, Firestore, Storage, FCM, Hosting) — `asia-southeast1`

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Architecture](#2-architecture)
- [3. The 7 Campuses](#3-the-7-campuses)
- [4. Data Model](#4-data-model)
- [5. Feature Completeness by Role](#5-feature-completeness-by-role)
- [6. Location Engine](#6-location-engine)
- [7. Security Review](#7-security-review)
- [8. Dependencies](#8-dependencies)
- [9. Known Bugs](#9-known-bugs)
- [10. Required Improvements](#10-required-improvements)
- [11. Recommendations](#11-recommendations)
- [12. File Structure](#12-file-structure)

---

## 1. Project Overview

**ISKSULARS TRACK** is a real-time student leader & organization officer locator for **Sultan Kudarat State University (SKSU)**. It allows students to find student leaders and org officers on interactive campus maps and lets leaders/officers share their live location and availability status. The app serves four user roles: **Student**, **Student Leader**, **Organization Officer**, and **Admin**.

### Goals

- Help students locate student leaders & organization officers quickly across SKSU campuses
- Give leaders/officers control over their location visibility and availability status
- Provide admins a dashboard for user management, analytics, and live monitoring
- Work offline with cached data when connectivity is poor
- Support responsive layouts across mobile, tablet, and desktop

---

## 2. Architecture

| Layer | Technology | Details |
|-------|-----------|---------|
| **Frontend** | Flutter 3.38+ / Dart 3.10.7+ | ~60 `.dart` files in `lib/` |
| **State Management** | Provider v6.1.2 + ChangeNotifier | 5 providers (Auth, Faculty, Location, Notification, Admin) |
| **Backend** | Firebase | Auth (email/password), Cloud Firestore, Storage, FCM, Hosting |
| **Maps — 2D** | flutter_map v7.0.2 | OpenStreetMap + ESRI satellite tiles |
| **Maps — 3D** | MapLibre GL v0.25.0 | 3D buildings, satellite, ground-level views |
| **Offline** | SQLite (mobile) / SharedPreferences (web) | 4 tables: faculty_cache, location_cache, sync_meta, pending_operations |
| **Notifications** | FCM + flutter_local_notifications | Push (mobile) + overlay toast (web) |
| **Styling** | Material 3, Google Fonts (Poppins + Inter) | Custom SKSU mint-green theme |
| **Reactive Streams** | RxDart v0.28.0 | CombineLatest for real-time faculty+location merging |

---

## 3. The 7 Campuses

All 7 campuses are **fully integrated** with polygon geofence boundaries, center coordinates, unique color identifiers, and 3D building models.

| # | Campus | Boundary Points | 3D Buildings | Color |
|---|--------|----------------|--------------|-------|
| 1 | **Isulan** (Main) | 4 points | 8 buildings | Mint `#41B3A3` |
| 2 | **Tacurong** | 4 points | 4 buildings | Orange `#FF9800` |
| 3 | **ACCESS** | 7 points | 3 buildings | Purple `#9C27B0` |
| 4 | **Bagumbayan** | 4 points | 2 buildings | Teal `#009688` |
| 5 | **Palimbang** | 4 points | 2 buildings | Indigo `#3F51B5` |
| 6 | **Kalamansig** | 4 points | 2+ buildings | Pink `#E91E63` |
| 7 | **Lutayan** | 4 points | 2+ buildings | Brown `#795548` |

Each campus uses a **point-in-polygon** algorithm for geofence detection (`location_service.dart`).

---

## 4. Data Model

### Firestore Collections

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `users` | User profiles | id, firstName, lastName, email, role, department, campusId, position, photoUrl, isActive, isTrackingEnabled, availabilityStatus, officeHours, phoneNumber |
| `locations` | Live GPS positions | userId, lat, lng, status, quickMessage, isWithinCampus, accuracy, isMoving, timestamp |
| `notifications` | Ping & system alerts | title, body, type (lookingForYou / locationUpdate / statusChange / system), senderId, recipientId, isRead |
| `departments` | Department list | name, shortName, headId, buildingLocation, staffCount |
| `app_versions` | In-app update info | versionName, versionCode, downloadUrl, releaseNotes, isRequired, isActive |
| `activity_logs` | Admin audit trail | action, userId, timestamp (immutable — no update/delete allowed) |
| `config/api` | API version & feature flags | currentApiVersion, features |

### Core Models (8 files)

- **UserModel** — UserRole enum (student / staff / admin), AvailabilityStatus enum (7 statuses: available, busy, inMeeting, teaching, onBreak, outOfOffice, doNotDisturb), campus assignment, legacy migration support
- **LocationModel** — lat/lng, status, quickMessage, isWithinCampus, accuracy, isMoving; sentinel pattern for nullable copyWith; `tryFromFirestore` for error-safe parsing
- **CampusModel** — CampusId enum (7 values), boundary polygon, radius-based `isWithinCampus`
- **FacultyWithLocation** — Combines UserModel + LocationModel, computed `isOnline` (tracking enabled + has location + not stale + within campus), `lastSeenText`, `displayStatus`
- **AppNotification** — 4 notification types, sender/recipient tracking, `timeAgoText`
- **AppVersion** — version info, download URL, required flag, UpdateCheckResult
- **DepartmentModel** — department metadata

---

## 5. Feature Completeness by Role

### 5.1 Student Features

| Feature | Status | Location |
|---------|--------|----------|
| Login / Register (email + password) | ✅ Complete | `screens/auth/login_screen.dart`, `register_screen.dart` |
| Onboarding tutorial (5 pages) | ✅ Complete | `screens/onboarding/onboarding_screen.dart` |
| Faculty Directory (search, department filter, availability filter, online-only toggle) | ✅ Complete | `screens/student/student_directory_screen.dart` |
| Faculty Detail (contact info, office hours, quick message, status, campus badge) | ✅ Complete | `screens/student/faculty_detail_screen.dart` |
| Interactive Map (2D/3D toggle, campus selector, faculty markers, walking directions, route display) | ✅ Complete | `screens/student/student_map_screen.dart` |
| Faculty arrival toast notifications | ✅ Complete | `FacultyProvider.onFacultyArrived` stream |
| "Looking for you" ping to staff (5-min cooldown) | ✅ Complete | `core/utils/helpers.dart` + `NotificationProvider` |
| Profile with location sharing toggle, edit profile, update check | ✅ Complete | `screens/student/student_profile_screen.dart` |
| Responsive layout (mobile bottom nav / tablet rail / desktop drawer) | ✅ Complete | `screens/student/student_home_screen.dart` |
| Email/Call quick actions on faculty cards | ✅ Complete | `widgets/common/faculty_card.dart` |
| Offline cached directory | ✅ Complete | `services/offline_cache_service.dart` |

### 5.2 Staff/Faculty Features

| Feature | Status | Location |
|---------|--------|----------|
| Dashboard (welcome card, location toggle, status selector, quick messages, stats) | ✅ Complete | `screens/staff/staff_dashboard_screen.dart` |
| 7 Availability Statuses (available, busy, inMeeting, teaching, onBreak, outOfOffice, doNotDisturb) | ✅ Complete | `models/user_model.dart` |
| GPS Map with auto-tracking, my-location, 2D/3D toggle, campus selector | ✅ Complete | `screens/staff/staff_map_screen.dart` |
| Manual Pin mode (alternative to GPS) with dedicated heartbeat | ✅ Complete | `LocationProvider` + `LocationService` |
| Auto-hide schedule (configurable hours + weekends) | ✅ Complete | `LocationProvider._checkAutoHideSchedule` |
| Background tracking (web: Wake Lock + beacon; Android: foreground service) | ✅ Complete | `services/web_background_service.dart` |
| Find Colleagues (staff directory, search, filter, bottom sheet with details) | ✅ Complete | `screens/staff/staff_directory_screen.dart` |
| Notifications (grouped by date, swipe-to-dismiss, mark all read, delete all) | ✅ Complete | `screens/staff/notifications_screen.dart` |
| Settings (profile, FCM toggle, location sharing, auto-hide, privacy, help, updates, sign out) | ✅ Complete | `screens/staff/staff_settings_screen.dart` |
| Edit Profile (photo upload ≤2MB to Firebase Storage, name, department, position, phone) | ✅ Complete | `screens/staff/edit_profile_screen.dart` |
| Responsive layout (mobile single column / desktop two-column) | ✅ Complete | `staff_dashboard_screen.dart` |

### 5.3 Admin Features

| Feature | Status | Location |
|---------|--------|----------|
| Admin Dashboard (Overview / Users / Analytics tabs, real-time stats, activity logs) | ✅ Complete | `screens/admin/admin_dashboard_screen.dart` |
| Super Admin Dashboard (5 tabs: Overview, Users, Analytics with charts, Activity, System) | ✅ Complete | `screens/admin/super_admin_dashboard.dart` |
| User Management (search, role/campus filter, banned-only, sort, ban/unban/delete/role-change) | ✅ Complete | `screens/admin/user_management_screen.dart` |
| User Detail (full profile, ban info, account data, role change, delete with batch cleanup) | ✅ Complete | `screens/admin/user_detail_screen.dart` |
| Live Monitor (real-time map of ALL users sharing location, role-color markers, filter by role/online, 2D/3D/campus selector) | ✅ Complete | `screens/admin/live_monitor_screen.dart` |
| Version Management (list versions, seed data, edit) | ✅ Complete | `screens/admin/version_management_screen.dart` |
| Activity Logging (immutable audit trail) | ✅ Complete | `AdminProvider._logActivity` |
| Aggregation queries (online now, active today, new this week/month) | ✅ Complete | `AdminProvider` + `DatabaseService` |

---

## 6. Location Engine

The GPS tracking engine (`services/location_service.dart`) is the core of UniTrack:

| Parameter | Value |
|-----------|-------|
| Minimum accuracy threshold | 50 meters |
| Distance filter | 1 meter |
| Movement threshold | 0.5 meters (with hysteresis) |
| Stale location threshold | 120 seconds |
| Heartbeat interval (GPS) | 15 seconds |
| Heartbeat interval (Manual Pin) | 20 seconds |
| Position smoothing | 3-reading weighted average (recency + accuracy weights) |
| Adaptive timer | 2 seconds (moving) / 5 seconds (stationary) |
| Geofencing | Point-in-polygon across all 7 campuses |
| Web background | Wake Lock API + `beforeunload` beacon |
| Token refresh (web) | Every 50 minutes |
| Marker animation | 800ms eased interpolation on 2D map |

---

## 7. Security Review

| Area | Implementation |
|------|---------------|
| **Firestore Rules** | Role-based access: students can't self-promote, users update only own docs (admins exempt), activity logs are immutable, notifications scoped to sender/recipient |
| **Storage Rules** | Users write only to their own `users/{userId}/` path; APK uploads restricted to admin role |
| **CSP Headers** | Full Content-Security-Policy in `web/index.html` with whitelisted Firebase, map tile, and font domains |
| **Auth** | Email verification on registration, password strength validation (0–4 scale), banned user detection on `refreshUser()` |
| **Staff Email** | Faculty/Staff accounts require `@sksu.edu.ph` domain |
| **Photo Upload** | 2MB size limit enforced client-side |
| **Ping Spam** | 5-minute cooldown on "looking for you" notifications (via `hasRecentlyPinged`) |
| **Batch Delete** | Notification cleanup in 499-document batches (Firestore limit is 500) |

---

## 8. Dependencies (35+)

### Firebase
`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`

### Maps & Location
`flutter_map`, `maplibre_gl`, `latlong2`, `geolocator`, `geocoding`

### State & Reactive
`provider`, `rxdart`

### UI
`google_fonts`, `cached_network_image`, `shimmer`, `flutter_spinkit`, `flutter_animate`, `animations`, `smooth_page_indicator`, `introduction_screen`, `fl_chart`

### Utilities
`shared_preferences`, `intl`, `url_launcher`, `permission_handler`, `http`, `path_provider`, `path`, `file_picker`, `open_file`, `web`

### Offline & Connectivity
`sqflite`, `connectivity_plus`

### Notifications
`flutter_local_notifications`

---

## 9. Known Bugs

### Bug #1 — Login Requires App Restart (Web / PWA)

**Severity:** High
**Description:** After signing in on the web or PWA, users are stuck on the login screen and must manually refresh the page (`Ctrl+Shift+R`) or close and reopen the app before the authenticated state is recognized.
**Root Cause:** The `AuthWrapper` depends on `AuthProvider` notifying listeners after `signIn()` completes. On web, the Firebase Auth state change listener sometimes fires before the Firestore user document is fully fetched, causing a race condition where the Provider updates but the user object is still null. The widget tree rebuilds to the login screen instead of the home screen.
**Where:** `providers/auth_provider.dart` (the `_onAuthStateChanged` listener vs `signIn()` method), `main.dart` (AuthWrapper Consumer rebuild)
**Impact:** Every first-time web/PWA login is broken. Users hit this on every session until they learn the workaround.

### Bug #2 — Live Tracking Unreliability for Teachers

**Severity:** High
**Description:** Teacher/staff locations sometimes stop updating in real-time, causing stale markers on student maps. The tracked position freezes or disappears, and students see faculty as "offline" even when they're on campus.
**Root Cause:** Multiple contributing factors:
- The heartbeat timer (`15s`) can drift or be suspended when the app is backgrounded on mobile
- On web, the Wake Lock API is not supported by all browsers, causing the background service to be killed
- The `beforeunload` beacon is a last-resort mechanism and doesn't maintain continuous tracking
- The stale threshold (120s) means a missed heartbeat can cause a 2-minute invisible window
**Where:** `services/location_service.dart`, `services/web_background_service.dart`, `providers/location_provider.dart`
**Impact:** Core feature of the app becomes unreliable, defeating the purpose of real-time tracking.

### Bug #3 — Location Accuracy Issues

**Severity:** Medium
**Description:** GPS positions can be inaccurate, especially indoors or in areas with poor satellite visibility. Faculty markers can appear in wrong buildings or even outside campus boundaries despite being physically on campus.
**Root Cause:**
- The 50m minimum accuracy threshold is too generous — positions with 30-50m accuracy circles can place markers significantly off
- The 3-reading smoothing window can lag behind actual movement
- Indoor positioning is purely GPS-dependent (no Wi-Fi or Bluetooth beacons)
- Some devices report poor accuracy on initial fix, and the smoothing algorithm weights these early readings
**Where:** `services/location_service.dart` (`LocationConfig.minAccuracy`, `_smoothPosition()`)
**Impact:** Students may walk to the wrong building looking for a faculty member.

### Bug #4 — Storage Rules Mismatch for Profile Photos

**Severity:** Low
**Description:** The edit profile screen uploads photos to `profile_photos/profile_{userId}.jpg`, but storage rules only allow writes to `users/{userId}/{allPaths}`. This means profile photo uploads may be silently denied by security rules in production.
**Where:** `screens/staff/edit_profile_screen.dart` (`_uploadPhoto` method), `storage.rules`
**Impact:** Profile photo uploads could fail in production if rules are enforced strictly.

---

## 10. Required Improvements

### Improvement #1 — Live Tracking Reliability

**Priority:** Critical
**Current State:** Tracking stops when app is backgrounded; web tracking depends on unsupported APIs.
**Required Changes:**
- Implement a proper Android foreground service with a persistent notification that keeps the app alive
- Use `WorkManager` or `flutter_background_service` for periodic location updates even when the app is killed
- On web, implement a Service Worker-based approach that periodically fetches location and posts to Firestore
- Reduce heartbeat interval to 10 seconds for moving users
- Add a server-side Cloud Function that marks users as offline if no heartbeat received in 90 seconds (don't rely solely on client-side stale detection)
- Add a "reconnecting..." UI state when the location stream is interrupted

### Improvement #2 — Location Accuracy

**Priority:** High
**Current State:** 50m accuracy threshold is too loose; indoor positioning is poor.
**Required Changes:**
- Tighten minimum accuracy to 20-25m and discard readings above 30m entirely
- Increase the smoothing window from 3 to 5 readings for stationary users
- Add a "low accuracy" indicator on the map so students know the position is approximate
- Consider implementing Wi-Fi fingerprinting or Bluetooth beacon integration for indoor positioning in major campus buildings
- Add a manual position correction option (staff can tap their exact location on the map)
- Show accuracy radius circle around faculty markers on the student map

### Improvement #3 — Login Bug Fix (Web/PWA)

**Priority:** High
**Current State:** Users must refresh or reopen the app after login.
**Required Changes:**
- Refactor `AuthProvider.signIn()` to await the Firestore user document fetch before calling `notifyListeners()`
- Remove the `_onAuthStateChanged` auto-fetch that races with the manual sign-in flow
- Add an explicit navigation trigger after successful login instead of relying on Consumer rebuilds
- Add a loading state in the AuthWrapper that waits for both auth state AND user document to be ready
- Test on web, Android, and iOS to ensure consistent behavior

### Improvement #4 — Map Enhancement

**Priority:** High
**Current State:** Maps work but lack polish; 3D mode depends on a missing MapTiler API key; no indoor maps.
**Required Changes:**
- Obtain and configure a MapTiler API key (free tier: 100K loads/month) for proper vector streets and satellite labels
- Add building labels and floor plans for major campus buildings
- Improve marker clustering when multiple faculty are in the same building
- Add a "campus overview" mode that shows all 7 campuses on a zoomed-out view with user counts per campus
- Implement indoor floor selection for multi-story buildings
- Add a search-by-building feature ("Show me everyone in the Science Building")
- Optimize 3D building rendering performance on low-end devices
- Add turn-by-turn walking directions with estimated arrival time

### Improvement #5 — Role Enforcement

**Priority:** High
**Current State:** Role-based features exist but boundaries are not strictly enforced in all screens.
**Required Changes:**
- **Students** should ONLY see faculty/staff locations within campus boundaries; any off-campus locations must be hidden (currently `FacultyWithLocation.isOnline` checks `isWithinCampus`, but verify this is enforced everywhere)
- **Staff/Faculty** should only have their location tracked and shared when inside campus boundaries; off-campus positions must NOT be written to Firestore (currently the location is written regardless, and `isWithinCampus` is just a flag — the actual lat/lng is still stored and visible to admins)
- **Admins** should see ALL users (students AND staff) both inside and outside campus — this is the intended behavior for the Live Monitor but needs to be clearly differentiated from the student view
- Add Firestore security rules that prevent location reads by non-admin users when `isWithinCampus == false`
- Add role verification middleware on app startup — if a user's role changes server-side (e.g., admin demotes them), the app should reflect this immediately

### Improvement #6 — Admin Visibility Enhancement

**Priority:** Medium
**Current State:** Live Monitor shows all users with location sharing enabled, but doesn't clearly distinguish inside/outside campus, and doesn't prominently show student locations.
**Required Changes:**
- Add inside/outside campus badges on each user marker in the Live Monitor
- Add a filter toggle: "Inside Campus" / "Outside Campus" / "All"
- Show user counts per campus on the Live Monitor's campus selector
- Add a heatmap overlay showing user density across campus zones
- Add alert notifications when staff leave campus during work hours (optional, configurable)
- Show student locations with a distinct marker style (currently `_markerColor` handles this but needs better visual distinction)

### Improvement #7 — Teacher Tracking Scope

**Priority:** High
**Current State:** Teacher locations are written to Firestore regardless of whether they're within campus.
**Required Changes:**
- In `LocationService`, when a position is outside all campus boundaries, either:
  - (a) Skip writing to Firestore entirely, OR
  - (b) Write with `isWithinCampus: false` and clear the lat/lng fields so only admins can see the timestamp
- In `FacultyProvider`, filter out any location documents where `isWithinCampus == false` before exposing to non-admin consumers
- Add a clear visual indicator on the staff dashboard: "Your location is only shared while on campus"
- Ensure the auto-hide schedule also respects campus boundaries (don't show "sharing" if outside campus)

### Improvement #8 — Student View Restrictions

**Priority:** High
**Current State:** Students can see faculty data from `FacultyWithLocation.isOnline` which already checks `isWithinCampus`, but the raw location data (lat/lng) is still available in the model.
**Required Changes:**
- Enforce at the Firestore rules level: students can only read from `locations/{userId}` if the document's `isWithinCampus == true`
- As a defense-in-depth measure, the `DatabaseService.getFacultyWithLocationsStream()` should filter out off-campus locations for student role
- Remove any ability for students to see exact coordinates of off-campus faculty (even in debug/logs)

### Improvement #9 — UI Cleanup

**Priority:** Medium
**Current State:** UI is functional and modern but has rough edges in several areas.
**Required Changes:**
- Unify card styling across all screens (some use `elevation: 0` with borders, others use `elevation: 2`)
- Fix inconsistent padding between student and staff screens
- Add smooth page transitions (currently using default `MaterialPageRoute`)
- Improve the skeleton loaders to match actual content layout more accurately
- Add pull-to-refresh on the student directory (currently only admin screens have `RefreshIndicator`)
- Improve the campus selector UX — replace the dropdown/popup with a visual campus card carousel
- Add empty state illustrations (currently just icons + text)
- Make the notification badge count visible on the app bar across all screens, not just staff
- Improve dark-text-on-light-background contrast ratios for accessibility
- Add haptic feedback on key interactions (ping, toggle tracking)

---

## 11. Recommendations

### Testing

| Area | Recommendation |
|------|----------------|
| **Unit Tests** | Add tests for all providers and services. Priority: `LocationService` (geofence logic, smoothing), `AuthProvider` (sign-in flow, role detection), `FacultyProvider` (filter logic, staleness) |
| **Widget Tests** | Test all screens render correctly in each role. Test form validation on login/register |
| **Integration Tests** | End-to-end flow: register → login → view directory → ping faculty → receive notification |
| **Coverage Target** | Aim for 70%+ on business logic (providers + services), 50%+ on widgets |

### DevOps & CI/CD

| Area | Recommendation |
|------|----------------|
| **GitHub Actions** | Set up CI pipeline: lint → analyze → test → build APK → deploy to Firebase Hosting |
| **Environment Config** | Use `--dart-define` for Firebase config and MapTiler key instead of hardcoding |
| **Staging Environment** | Create a separate Firebase project for staging/testing |
| **Crash Reporting** | Integrate Firebase Crashlytics or Sentry for production error monitoring |

### Performance

| Area | Recommendation |
|------|----------------|
| **Firestore Reads** | Add pagination to the admin user list (currently loads ALL users at once) |
| **Map Performance** | Implement marker clustering for campuses with many online users |
| **Image Caching** | Profile photos should use `CachedNetworkImage` consistently (already used in some places) |
| **Bundle Size** | Analyze and tree-shake unused dependencies; `introduction_screen` may be redundant with the custom onboarding |
| **Web Performance** | Enable deferred loading for admin screens (students never see them) |

### UX Enhancements

| Area | Recommendation |
|------|----------------|
| **Dark Mode** | Implement a dark theme using the existing `AppColors` pattern |
| **Localization** | Add Filipino (Tagalog) and Maguindanaon language support for SKSU's community |
| **Accessibility** | Add semantic labels to all icons, ensure minimum tap targets (48x48), test with screen readers |
| **Onboarding** | Add role-specific onboarding (student vs staff vs admin get different tutorials) |
| **Biometrics** | Add fingerprint/Face ID login option for returning users |

### Data & Privacy

| Area | Recommendation |
|------|----------------|
| **Data Retention** | Add automatic cleanup of location data older than 24 hours (currently locations persist indefinitely) |
| **GDPR/DPA Compliance** | Add a "Download My Data" feature and clear data deletion flow beyond just account deletion |
| **Consent** | Show location tracking consent banner on first enable (not just a toggle) |
| **Audit Trail** | Extend activity logging to cover all admin actions (currently only some are logged) |

### Infrastructure

| Area | Recommendation |
|------|----------------|
| **Cloud Functions** | Add server-side functions for: auto-offline detection, notification delivery confirmation, daily analytics aggregation |
| **Firestore Indexes** | Review `firestore.indexes.json` for compound query optimization |
| **Rate Limiting** | Add Cloud Functions rate limiting on notification creation (supplement the 5-min client-side check) |
| **Backup** | Set up automated Firestore export/backup schedule |
| **Monitoring** | Set up Firebase Performance Monitoring for tracking app startup time and network latency |

### Missing Features to Consider

| Feature | Description |
|---------|-------------|
| **Schedule Integration** | Import faculty class schedules to auto-set availability status |
| **Appointment Booking** | Students can request a meeting slot with faculty |
| **Campus Announcements** | Admin-pushed broadcast notifications to all users |
| **Analytics Dashboard** | Show faculty "availability hours" trends over weeks/months |
| **QR Code Check-in** | Faculty scan a QR at their office door to mark arrival (supplements GPS) |
| **Faculty Rating/Feedback** | Students can rate consultation experience (anonymized) |
| **Multi-language Support** | English + Filipino toggle |
| **Wearable Integration** | SmartWatch companion for quick status changes |

---

## 12. File Structure

```
lib/
├── main.dart                          # App entry, Firebase init, MultiProvider setup
├── firebase_options.dart              # Firebase config (auto-generated)
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # 7 campuses, geofence data, app metadata
│   │   └── map_constants.dart         # Tile URLs, API keys, 3D building GeoJSON
│   ├── theme/
│   │   ├── app_colors.dart            # SKSU mint-green color palette
│   │   └── app_theme.dart             # Material 3 theme config (Poppins + Inter)
│   └── utils/
│       ├── connectivity_service.dart  # Network monitoring singleton
│       ├── error_handler.dart         # User-friendly error messages + SnackBarMixin
│       ├── helpers.dart               # formatCampusName, formatRelativeTime, pingFaculty
│       ├── responsive.dart            # Breakpoints, DeviceType, ResponsiveGrid/Builder
│       ├── validators.dart            # Email, password, phone validation + strength meter
│       ├── web_utils.dart             # Conditional import for web page reload
│       ├── web_utils_stub.dart        # No-op stub for non-web platforms
│       └── web_utils_web.dart         # Actual web reload implementation
│
├── models/
│   ├── models.dart                    # Barrel export
│   ├── user_model.dart                # UserModel, UserRole, AvailabilityStatus
│   ├── location_model.dart            # LocationModel with sentinel-pattern copyWith
│   ├── campus_model.dart              # CampusModel, CampusId enum
│   ├── faculty_with_location.dart     # Combined model with isOnline, staleness
│   ├── notification_model.dart        # AppNotification, NotificationType enum
│   ├── app_version_model.dart         # AppVersion, UpdateCheckResult
│   └── department_model.dart          # DepartmentModel
│
├── providers/
│   ├── providers.dart                 # Barrel export
│   ├── auth_provider.dart             # Auth state, signIn/register/signOut, banned detection
│   ├── faculty_provider.dart          # Real-time faculty list, filters, arrival detection
│   ├── location_provider.dart         # GPS lifecycle, manual pin, auto-hide, web background
│   ├── notification_provider.dart     # Notification stream, ping cooldown, toast display
│   └── admin_provider.dart            # All users, statistics, ban/unban/delete, activity log
│
├── services/
│   ├── services.dart                  # Barrel export
│   ├── auth_service.dart              # Firebase Auth wrapper, legacy migration
│   ├── database_service.dart          # Firestore CRUD, RxDart streams, aggregation
│   ├── location_service.dart          # GPS engine, smoothing, geofencing, adaptive timer
│   ├── notification_service.dart      # Notification CRUD, local/overlay display
│   ├── push_notification_service.dart # FCM setup, token management, handlers
│   ├── offline_cache_service.dart     # SQLite/SharedPreferences, auto-sync
│   ├── update_service.dart            # Version check, APK download with progress
│   └── web_background_service.dart    # JS interop for Wake Lock + beacon
│
├── screens/
│   ├── screens.dart                   # Barrel export (24 screens)
│   ├── splash_screen.dart             # Animated splash with gradient + pulsing ring
│   ├── auth/
│   │   ├── login_screen.dart          # Email/password login, connectivity check, timeout
│   │   └── register_screen.dart       # Registration with role, campus, department selection
│   ├── onboarding/
│   │   └── onboarding_screen.dart     # 5-page tutorial (Find Faculty, Maps, Notifications, Schedules, Offline)
│   ├── student/
│   │   ├── student_home_screen.dart   # Tab hub: Directory / Map / Profile (responsive nav)
│   │   ├── student_directory_screen.dart # Faculty search, department + availability filters
│   │   ├── student_map_screen.dart    # 2D/3D map, campus selector, walking directions
│   │   ├── student_profile_screen.dart # Profile card, location toggle, settings
│   │   └── faculty_detail_screen.dart # Full faculty details, Notify + Directions actions
│   ├── staff/
│   │   ├── staff_dashboard_screen.dart # Location toggle, status, quick messages, stats
│   │   ├── staff_map_screen.dart      # GPS auto-tracking map with 2D/3D
│   │   ├── staff_directory_screen.dart # Find Colleagues with distance + walk time
│   │   ├── staff_settings_screen.dart # Privacy, notifications, auto-hide, about
│   │   ├── edit_profile_screen.dart   # Photo upload, name, department, position, phone
│   │   └── notifications_screen.dart  # Grouped notifications, swipe-delete, mark-all-read
│   ├── admin/
│   │   ├── admin_dashboard_screen.dart    # Overview / Users / Analytics tabs
│   │   ├── super_admin_dashboard.dart     # 5-tab dashboard with charts (fl_chart)
│   │   ├── user_management_screen.dart    # User list with filters, sort, actions
│   │   ├── user_detail_screen.dart        # Full user profile, ban/unban/delete/role-change
│   │   ├── live_monitor_screen.dart       # Real-time ALL-user map (role-colored markers)
│   │   └── version_management_screen.dart # App version CRUD, seed data
│   └── common/
│       ├── help_support_screen.dart   # FAQ (10 items) + contact support
│       └── privacy_policy_screen.dart # Data collection, location privacy, user rights
│
└── widgets/
    ├── widgets.dart                   # Barrel export
    ├── update_dialog.dart             # In-app update dialog with download progress
    ├── common/
    │   ├── adaptive_scaffold.dart     # Responsive scaffold wrapper
    │   ├── custom_button.dart         # Styled button variants
    │   ├── custom_text_field.dart     # Styled text field + PasswordTextField
    │   ├── faculty_card.dart          # Faculty list card with status, quick actions
    │   ├── loading_widget.dart        # Loading overlay + spinners
    │   ├── offline_banner.dart        # "No internet" banner
    │   ├── skeleton_loaders.dart      # Shimmer skeletons for faculty, map, notifications
    │   ├── status_badge.dart          # Availability status pill badge
    │   └── user_avatar.dart           # UserAvatar + FacultyAvatar (with online indicator)
    ├── faculty/
    │   └── availability_status_widget.dart # Status selection widget
    └── map/
        ├── campus_map.dart            # 2D map (flutter_map) with boundary polygons, smooth marker animation
        ├── campus_map_3d.dart         # 3D map (MapLibre GL) with building extrusions, GeoJSON markers
        ├── campus_selector.dart       # Campus dropdown with color indicators
        ├── faculty_map_sheet.dart     # Faculty detail bottom sheet on map
        └── map_view_controls.dart     # MapViewMode + TrackingMode dropdowns
```

### Other Important Files

```
pubspec.yaml              # 35+ dependencies, Flutter 3.38+ / Dart 3.10.7+
firestore.rules           # Role-based security rules (7 collections)
storage.rules             # User-scoped writes, admin-only APK uploads
firestore.indexes.json    # Compound query indexes
firebase.json             # Hosting + Firestore + Storage config
web/index.html            # CSP headers, PWA meta tags, iOS launch images
web/bg_tracking.js        # Wake Lock + beacon background tracking (JS)
web/sw.js                 # Service Worker for PWA
web/manifest.json         # PWA manifest
website/index.html        # Marketing landing page
website/privacy.html      # Public privacy policy page
analysis_options.yaml     # Dart lint rules
```

---

*End of audit. Generated from a file-by-file source code review of every `.dart` file in the project.*
