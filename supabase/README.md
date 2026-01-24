# Supabase Setup

## Prerequisites

1. Create a Supabase project at https://supabase.com
2. Get your project URL and anon key from Settings > API

## Running Migrations

### Option 1: Using Supabase Dashboard

1. Go to your project's SQL Editor
2. Copy and paste the contents of each migration file in order:
   - `migrations/001_initial_schema.sql`
   - `migrations/002_row_level_security.sql`
3. Run each script

### Option 2: Using Supabase CLI

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Run migrations
supabase db push
```

## Database Schema

### Tables

- **organizations**: Business/school entities
- **admins**: Admin users linked to organizations
- **campaigns**: Check-in contexts (store, classroom, etc.)
- **beacons**: BLE beacon configurations
- **forms**: Dynamic form schemas for check-in actions
- **clients**: End users who check in
- **subscriptions**: Client subscriptions to campaigns
- **checkins**: Check-in records

### Row Level Security

- Admins can only access data for their organization
- Clients can only access their own data and subscribed campaigns
- All tables have RLS enabled

## Seed Data (Optional)

For testing, you can add sample data:

```sql
-- Create a test organization
INSERT INTO organizations (id, name) VALUES
  ('org-1', 'Test Store');

-- Note: Admins are created through the signup flow
-- which links them to auth.users and an organization
```

## Realtime

The admin panel uses Supabase Realtime for live check-in updates.
This is enabled by default on the `checkins` table.

## Authentication

Both admin and client apps use Supabase Auth with email/password.
You can enable additional providers (Google, Apple, etc.) in the
Supabase dashboard under Authentication > Providers.
