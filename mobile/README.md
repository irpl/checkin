# Checkin Mobile App

Flutter mobile app for BLE-based proximity check-in.

## Setup

1. Install Flutter SDK (3.x+)
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Supabase credentials:

   **Option A: Environment variables (recommended for builds)**
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

   **Option B: Edit config file (for development)**
   Edit `lib/config/env.dart` with your credentials.

## Running

```bash
# Debug mode
flutter run

# With Supabase config
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
```

## Building

### Android
```bash
flutter build apk --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
```

### iOS
```bash
flutter build ios --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
```

## Features

- User authentication (sign up/sign in)
- Campaign subscription
- BLE beacon scanning (iBeacon format)
- Proximity-based check-in prompts
- Dynamic form rendering for check-in actions

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app.dart               # App widget
├── config/
│   └── env.dart           # Environment config
├── models/                # Data models
├── services/              # Business logic
│   ├── ble_service.dart   # BLE scanning
│   └── supabase_service.dart
├── router/                # Navigation
└── features/
    ├── auth/              # Login/Register
    ├── home/              # Home screen
    ├── campaigns/         # Campaign browsing
    └── checkin/           # Check-in flow
```

## Permissions

### Android
- Bluetooth (BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
- Location (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION)
- Internet

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to detect nearby check-in beacons</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to detect nearby check-in beacons</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location to verify proximity to check-in locations</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app uses your location to detect check-in beacons in the background</string>
```
