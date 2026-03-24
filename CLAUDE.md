# Checkin

Proximity-based check-in system using BLE beacons. Mobile users detect nearby beacons and get prompted to check in at locations (stores, classrooms, restaurants). Admins manage campaigns, beacons, and forms via a web dashboard.

## Tech Stack

- **Mobile**: Flutter 3.0+ · Riverpod (state) · GoRouter (navigation) · flutter_blue_plus (BLE)
- **Admin**: React 18 · TypeScript · Vite · Tailwind · Zustand · React Hook Form + Zod
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)

## Project Structure

- `mobile/` — Flutter client app
- `admin/` — React admin panel
- `supabase/migrations/` — Sequential SQL migrations (001–008)

## Database

All tables use Row Level Security. Admin permission checks use `SECURITY DEFINER` helper functions (`is_admin_of(org_id)`, `get_admin_org_id()`) to avoid RLS recursion on the `admins` table. See migration 008 for details.

**Tables:** organizations → admins → campaigns → beacons + forms + campaign_time_blocks; clients → subscriptions → checkins

**Campaign types:** `instant` (one-time check-in) or `duration` (attendance tracking with presence percentage).

## Environment

- Admin: `admin/.env` with `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
- Mobile: `flutter run --dart-define-from-file=.env` or `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## Key Patterns

- RLS policies referencing admin org membership must call `public.is_admin_of(org_id)` — never query the `admins` table directly in a policy
- Policy names must stay under 63 characters (PostgreSQL NAMEDATALEN limit) or they get silently truncated
- The `register_admin` function (migration 003) is `SECURITY DEFINER` to bypass RLS during signup
- Migration files have been synced to match the actual DB state as of migration 008

## Supabase

- Project ref: `kbuestevqljmrholptyn`
- CLI is linked (`supabase link` already done)
- Migrations are run manually via SQL Editor (no Docker for `supabase db push`)
