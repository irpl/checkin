# Checkin

A proximity-based check-in system using BLE beacons. Users with the mobile app automatically detect nearby beacons and can check in to locations like stores, classrooms, restaurants, etc.

## Project Structure

```
checkin/
├── mobile/          # Flutter mobile app (client)
├── admin/           # React admin panel
├── supabase/        # Supabase configuration and migrations
└── idea             # Original concept document
```

## Components

### Mobile App (Flutter)
- BLE beacon scanning (iBeacon format)
- User authentication
- Campaign subscription
- Proximity-based check-in prompts
- Dynamic form rendering

### Admin Panel (React)
- Campaign/location management
- Beacon configuration (UUID, major, minor)
- Form builder for check-in actions
- Real-time check-in dashboard

### Backend (Supabase)
- Authentication (email/password)
- PostgreSQL database
- Real-time subscriptions
- Row Level Security

## Quick Start

### 1. Set up Supabase

1. Create a project at https://supabase.com
2. Go to SQL Editor and run the migrations:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_row_level_security.sql`
3. Note your project URL and anon key from Settings > API

### 2. Set up Admin Panel

```bash
cd admin
npm install
cp .env.example .env
# Edit .env with your Supabase credentials
npm run dev
```

Open http://localhost:5173 and create an admin account.

### 3. Set up Mobile App

```bash
cd mobile
flutter pub get

# Run with Supabase config
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxx
```

### 4. Create a Campaign

1. In the admin panel, create a new campaign
2. Add a beacon with your iBeacon's UUID
3. Optionally add a form for users to fill out

### 5. Test Check-in

1. In the mobile app, register/login
2. Subscribe to your campaign
3. When near the beacon, you'll be prompted to check in

## Environment Variables

Copy `.env.example` to `.env` in the root and fill in your Supabase credentials.

For the admin panel, use `admin/.env`:
```
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=xxx
```

For the mobile app, pass via command line or edit `mobile/lib/config/env.dart`.

## Getting a BLE Beacon

For testing, you can use:
- **Physical iBeacon**: Many options on Amazon ($10-30)
- **Phone as beacon**: Apps like "Beacon Simulator" (Android) or "Locate Beacon" (iOS)
- **Raspberry Pi**: Configure as iBeacon with BlueZ

The app looks for standard iBeacon format with configurable UUID, major, and minor values.
