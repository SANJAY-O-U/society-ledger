# 🏢 Society Ledger — Complete Society Management System

A full-stack cross-platform mobile application for housing society management, built with **Flutter + Node.js + MongoDB**.

---

## 📁 Project Structure

```
society-ledger/
├── backend/                      # Node.js + Express REST API
│   ├── src/
│   │   ├── server.js             # Entry point
│   │   ├── config/
│   │   │   └── firebase.js       # Firebase Admin SDK config
│   │   ├── models/
│   │   │   ├── User.js           # User & auth model
│   │   │   ├── Member.js         # Society member model
│   │   │   ├── LedgerTransaction.js
│   │   │   └── index.js          # Payment, Expense, Complaint, Event, Inventory, Document, Notification
│   │   ├── controllers/
│   │   │   ├── authController.js
│   │   │   ├── ledgerController.js
│   │   │   ├── paymentController.js
│   │   │   └── dashboardController.js
│   │   ├── routes/               # Express routers for all modules
│   │   ├── middleware/
│   │   │   ├── auth.js           # JWT + RBAC middleware
│   │   │   ├── asyncHandler.js
│   │   │   └── errorHandler.js
│   │   ├── services/
│   │   │   ├── notificationService.js   # FCM push notifications
│   │   │   ├── emailService.js          # Nodemailer emails
│   │   │   └── cronService.js           # Auto maintenance + reminders
│   │   └── utils/
│   │       ├── fileUpload.js     # Multer config
│   │       └── logger.js         # Winston logger
│   ├── uploads/                  # Local file storage
│   ├── logs/
│   ├── package.json
│   └── .env.example
│
└── flutter_app/                  # Flutter cross-platform app
    ├── lib/
    │   ├── main.dart             # App entry point
    │   ├── config/
    │   │   ├── app_theme.dart    # Colors, typography, themes
    │   │   └── router.dart       # GoRouter navigation
    │   ├── models/
    │   │   └── models.dart       # All data models
    │   ├── providers/
    │   │   ├── auth_provider.dart
    │   │   └── data_providers.dart
    │   ├── services/
    │   │   ├── api_service.dart          # Dio HTTP client
    │   │   ├── storage_service.dart      # Secure token storage
    │   │   └── notification_service.dart # FCM setup
    │   ├── screens/
    │   │   ├── auth/             # Splash, Login, OTP
    │   │   ├── dashboard/        # Admin & Member dashboards
    │   │   ├── ledger/           # Ledger & transactions
    │   │   ├── payments/         # Razorpay payments
    │   │   ├── complaints/       # Complaints management
    │   │   ├── events/           # Events & calendar
    │   │   ├── inventory/        # Asset management
    │   │   ├── documents/        # Document library
    │   │   ├── profile/          # User profile
    │   │   └── admin/            # Admin panel
    │   └── widgets/
    │       ├── main_shell.dart   # Bottom nav shell
    │       └── common_widgets.dart
    └── pubspec.yaml
```

---

## ⚙️ Backend Setup

### Prerequisites
- Node.js v18+
- MongoDB Atlas (or local MongoDB 6+)
- Firebase project with Phone Auth enabled
- Razorpay account

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your actual credentials
```

Required `.env` values:
```env
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/society_ledger
JWT_SECRET=your_min_32_char_secret_here
JWT_REFRESH_SECRET=your_refresh_secret_here
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@project.iam.gserviceaccount.com
RAZORPAY_KEY_ID=rzp_live_xxxx
RAZORPAY_KEY_SECRET=your_razorpay_secret
EMAIL_USER=your@gmail.com
EMAIL_PASS=your_app_password
```

### 3. Create Log Directory
```bash
mkdir -p logs
```

### 4. Start Server
```bash
# Development
npm run dev

# Production
npm start
```

Server starts on `http://localhost:5000`

---

## 📱 Flutter App Setup

### Prerequisites
- Flutter SDK 3.10+
- Android Studio / Xcode
- Firebase CLI

### 1. Install Dependencies
```bash
cd flutter_app
flutter pub get
```

### 2. Firebase Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Configure Firebase for Flutter
dart pub global activate flutterfire_cli
flutterfire configure --project=your-firebase-project
```

This generates `lib/firebase_options.dart` automatically.

### 3. Configure API URL
For Android emulator (default): `http://10.0.2.2:5000/api`
For physical device: Use your machine's LAN IP, e.g. `http://192.168.1.100:5000/api`

Edit `lib/services/api_service.dart`:
```dart
const String baseUrl = String.fromEnvironment('API_URL',
    defaultValue: 'http://10.0.2.2:5000/api');
```

Or pass at build time:
```bash
flutter run --dart-define=API_URL=https://your-api.com/api
```

### 4. Android Configuration

In `android/app/src/main/AndroidManifest.xml`, add:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

### 5. iOS Configuration

In `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture photos for complaints</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to upload photos</string>
```

### 6. Run App
```bash
# Android
flutter run

# iOS
flutter run -d ios

# Release build
flutter build apk --release
flutter build ios --release
```

---

## 🗄️ Database Schema

### Collections Overview

| Collection | Purpose |
|---|---|
| `users` | Authentication, FCM tokens, roles |
| `members` | Flat details, maintenance config, parking |
| `ledgertransactions` | All debit/credit entries with running balance |
| `payments` | Razorpay payment records |
| `expenses` | Society expense tracking with approval |
| `complaints` | Member complaints with responses |
| `events` | Society events with RSVP |
| `inventories` | Asset management with checkout logs |
| `documents` | Notices, circulars, AGM docs |
| `notifications` | Push notification records |

### Key Indexes
```javascript
// LedgerTransaction
{ member: 1, date: -1 }
{ month: 1, year: 1 }
{ status: 1 }

// Member
{ flatNumber: 1, wing: 1 } // unique
{ user: 1 }

// Payment
{ member: 1, status: 1 }
{ razorpayOrderId: 1 }
```

---

## 🔌 API Reference

### Authentication
```
POST   /api/auth/send-otp           Send OTP (Firebase)
POST   /api/auth/verify-otp         Verify OTP + login
POST   /api/auth/login              Email/password login
POST   /api/auth/refresh-token      Refresh access token
GET    /api/auth/me                 Get current user
PUT    /api/auth/change-password    Change password
POST   /api/auth/logout             Logout + remove FCM
```

### Members
```
GET    /api/members                 List all members (paginated)
GET    /api/members/:id             Get single member
POST   /api/members                 Create member (mgmt)
PUT    /api/members/:id             Update member (mgmt)
DELETE /api/members/:id             Deactivate member (admin)
POST   /api/members/:id/documents   Upload member document
GET    /api/members/meta/wings      List all wings
```

### Ledger
```
GET    /api/ledger/:memberId        Member ledger (paginated)
GET    /api/ledger/pending-dues     All pending dues (mgmt)
GET    /api/ledger/summary          Monthly summary chart data
GET    /api/ledger/receipt/:id      Download PDF receipt
POST   /api/ledger/add-transaction  Add manual transaction (mgmt)
POST   /api/ledger/generate-maintenance  Auto-gen monthly bills
POST   /api/ledger/apply-late-fee   Apply late fees to overdue
```

### Payments
```
POST   /api/payments/create-order   Create Razorpay order
POST   /api/payments/verify         Verify payment signature
POST   /api/payments/cash           Record offline payment (mgmt)
GET    /api/payments                Payment list
GET    /api/payments/stats          Payment statistics
```

### Complaints
```
GET    /api/complaints              List complaints
GET    /api/complaints/:id          Complaint detail
POST   /api/complaints              Raise complaint (member)
PUT    /api/complaints/:id/status   Update status (mgmt)
POST   /api/complaints/:id/respond  Add response
PUT    /api/complaints/:id/feedback Rate resolution
```

### Events
```
GET    /api/events                  List events
GET    /api/events/:id              Event detail
POST   /api/events                  Create event (mgmt)
PUT    /api/events/:id              Update event (mgmt)
POST   /api/events/:id/rsvp         RSVP to event
DELETE /api/events/:id              Delete event (mgmt)
```

### Dashboard
```
GET    /api/dashboard/admin         Full admin dashboard data
GET    /api/dashboard/member        Member-specific dashboard
```

---

## 🔐 Role-Based Access Control

| Feature | Member | Secretary | Treasurer | Chairman | Admin |
|---|---|---|---|---|---|
| View own ledger | ✅ | ✅ | ✅ | ✅ | ✅ |
| Pay maintenance | ✅ | ✅ | ✅ | ✅ | ✅ |
| Raise complaint | ✅ | ✅ | ✅ | ✅ | ✅ |
| View all ledgers | ❌ | ✅ | ✅ | ✅ | ✅ |
| Add transactions | ❌ | ❌ | ✅ | ✅ | ✅ |
| Approve expenses | ❌ | ❌ | ✅ | ✅ | ✅ |
| Manage members | ❌ | ✅ | ✅ | ✅ | ✅ |
| Generate maintenance | ❌ | ❌ | ✅ | ✅ | ✅ |
| Delete member | ❌ | ❌ | ❌ | ❌ | ✅ |
| Send notifications | ❌ | ✅ | ✅ | ✅ | ✅ |

---

## ⏰ Automated Cron Jobs

| Schedule | Task |
|---|---|
| 1st of month, 9 AM | Auto-generate monthly maintenance for all active members |
| Daily, 10 AM | Send 3-day advance payment reminders; mark overdue entries |
| 15th of month, 11 AM | Apply late fees to overdue maintenance entries |

---

## 🚀 Deployment

### Backend — AWS EC2 / Railway / Render

**Option 1: Render (Recommended for quick deploy)**
1. Push backend to GitHub
2. Connect to [render.com](https://render.com)
3. Create Web Service → set build command: `npm install`
4. Set start command: `node src/server.js`
5. Add all environment variables in Render dashboard

**Option 2: AWS EC2**
```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
npm install -g pm2

# Clone and run
git clone <repo>
cd society-ledger/backend
npm install
pm2 start src/server.js --name society-ledger
pm2 save && pm2 startup

# Nginx reverse proxy
sudo apt install nginx
# Configure nginx to proxy port 80 → 5000
```

**Nginx config (`/etc/nginx/sites-available/society-ledger`):**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /uploads {
        alias /path/to/backend/uploads;
    }
}
```

### Flutter App — Play Store / App Store

```bash
# Android - Release APK
flutter build apk --release \
  --dart-define=API_URL=https://your-api.com/api

# Android - App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
# Then archive in Xcode → upload to App Store Connect
```

### MongoDB Atlas Setup
1. Create cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
2. Create database user with read/write access
3. Whitelist IP (or `0.0.0.0/0` for all)
4. Copy connection string to `.env`

---

## 🔥 Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project
3. Enable **Phone Authentication**
4. Enable **Cloud Messaging** (FCM)
5. Create service account → download JSON
6. Extract values to `.env`:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_PRIVATE_KEY`
   - `FIREBASE_CLIENT_EMAIL`

---

## 💳 Razorpay Setup

1. Sign up at [razorpay.com](https://razorpay.com)
2. Get Key ID and Secret from Dashboard → Settings → API Keys
3. Add to `.env`:
   ```env
   RAZORPAY_KEY_ID=rzp_live_xxxx
   RAZORPAY_KEY_SECRET=your_secret
   ```
4. For testing, use `rzp_test_xxxx` key and test cards

---

## 🧪 Test Credentials (Development)

```
Admin Login:
  Phone: 9999999999
  OTP: 123456 (Firebase test)

Member Login:
  Phone: 8888888888
  OTP: 123456

Test Razorpay Card:
  Card: 4111 1111 1111 1111
  Expiry: Any future date
  CVV: Any 3 digits
  OTP: 1234
```

---

## 📋 Environment Variables Complete Reference

```env
# ─── Server ────────────────────────────
PORT=5000
NODE_ENV=production

# ─── MongoDB ───────────────────────────
MONGODB_URI=mongodb+srv://...

# ─── JWT ───────────────────────────────
JWT_SECRET=minimum_32_character_secret_key
JWT_EXPIRE=30d
JWT_REFRESH_SECRET=different_32_char_refresh_secret
JWT_REFRESH_EXPIRE=90d

# ─── Firebase ──────────────────────────
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nXXXX\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@project.iam.gserviceaccount.com

# ─── Email ─────────────────────────────
EMAIL_SERVICE=gmail
EMAIL_USER=your@gmail.com
EMAIL_PASS=app_specific_password
EMAIL_FROM=Society Ledger <noreply@society.com>

# ─── Razorpay ──────────────────────────
RAZORPAY_KEY_ID=rzp_live_xxxx
RAZORPAY_KEY_SECRET=your_secret

# ─── App ───────────────────────────────
FRONTEND_URL=https://your-domain.com
MAX_FILE_SIZE=10485760
```

---

## 🛡️ Security Checklist

- [x] JWT access tokens (30 day expiry)
- [x] Refresh tokens (90 day expiry)
- [x] Bcrypt password hashing (cost 12)
- [x] Role-based API access control
- [x] Rate limiting (100 req/15min global, 10 req/15min auth)
- [x] Helmet.js security headers
- [x] CORS whitelist
- [x] Input validation (express-validator)
- [x] MongoDB schema validation
- [x] Secure JWT storage (flutter_secure_storage)
- [x] Razorpay signature verification
- [x] File type + size validation
- [x] Environment variables (no hardcoded secrets)

---

## 🤝 Contributing

Built by **Society Ledger Team** — SE Semester IV, Terna Engineering College, Navi Mumbai.

Guide: **Prof. Harnam Grover**

---

## 📄 License

MIT License — Free to use for academic and commercial projects.
