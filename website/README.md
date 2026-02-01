# UniTrack Download Website

This folder contains the download website for UniTrack - SKSU Faculty Tracking System.

## Structure

```
website/
├── index.html          # Main landing page
├── privacy.html        # Privacy policy page
├── assets/             # Images and icons
│   └── icon.png        # App icon (used as favicon and logo)
├── downloads/          # APK files for download
│   └── unitrack-latest.apk   # Always the latest version
└── README.md           # This file
```

## Updating the APK (For New Releases)

When you release a new version, simply replace the APK file:

```powershell
# Build the release APK
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot"
flutter build apk --release

# Copy to downloads folder (always use the same filename)
copy build\app\outputs\flutter-apk\app-release.apk website\downloads\unitrack-latest.apk
```

**Important:** Always use `unitrack-latest.apk` as the filename. This ensures users always download the newest version without needing to update the website HTML.

## Update Version Display

When releasing a new version, update the version badge in `index.html`:

```html
<div class="version-info">
    <span class="version-badge">v2.1.0</span>  <!-- Update this -->
    <span>Latest Release • March 2026</span>   <!-- Update date -->
</div>
```

## Setup Instructions

### 1. Add App Icon

The app icon should already be in `assets/icon.png`. If not:
```powershell
copy assets\icon.png website\assets\icon.png
```

### 2. Hosting Options

#### Option A: GitHub Pages (Free)
1. Push this `website` folder to a GitHub repository
2. Go to Settings → Pages
3. Select the branch and folder
4. Your site will be live at `https://yourusername.github.io/reponame`

#### Option B: Firebase Hosting (Free tier available)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting (select 'website' as public directory)
firebase init hosting

# Deploy
firebase deploy --only hosting
```

#### Option C: Netlify (Free)
1. Go to netlify.com
2. Drag and drop the `website` folder
3. Get your free URL instantly

#### Option D: Local Testing
```powershell
cd website
python -m http.server 8080
```
Then open http://localhost:8080

## Mobile Responsiveness

The website is fully responsive and works on:
- Desktop (1200px+)
- Tablet (768px - 900px)
- Mobile (480px - 768px)  
- Small Mobile (< 480px)

Features:
- Hamburger menu on mobile
- Touch-friendly buttons
- Optimized phone mockup display
- Readable text at all sizes

## Notes

- The admin role is kept hidden from the public website (secret feature)
- Only Faculty and Department Heads roles are displayed
- Download link always points to `unitrack-latest.apk` for easy updates

## Contact

For issues or updates, contact the SKSU IT Department.
