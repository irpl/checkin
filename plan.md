# Invite-Only Campaigns with Single-Use Links

## Overview

Replace the public campaign browsing model with an invite-only system. Users can only join campaigns via unique, single-use invitation links (shareable as URLs or QR codes). Once redeemed, an invitation is consumed and cannot be reused.

## Database Changes (new migration 008)

### New table: `campaign_invitations`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | default gen_random_uuid() |
| campaign_id | UUID FK → campaigns | NOT NULL |
| token | TEXT UNIQUE NOT NULL | Unique random token (used in the link) |
| created_by | UUID FK → admins(id) | The admin who generated it |
| redeemed_by | UUID FK → clients(id) | NULL until redeemed |
| redeemed_at | TIMESTAMPTZ | NULL until redeemed |
| created_at | TIMESTAMPTZ | default NOW() |

- Index on `token` for fast lookup
- Index on `campaign_id` for listing invitations per campaign

### RLS Policies for `campaign_invitations`
- Admins can SELECT/INSERT/DELETE invitations for their org's campaigns
- Authenticated clients can SELECT invitations by token (to redeem)
- Authenticated clients can UPDATE invitations (to mark as redeemed — only their own redemption)

### Remove public campaign visibility
- **Drop** the RLS policy `"Anyone can view active campaigns"` on `campaigns`
- Clients can only see campaigns they are subscribed to (add a new policy for this)
- Similarly tighten beacon/form policies: clients should only access data for campaigns they're subscribed to (already the case for beacons/forms, but campaign SELECT needs updating)

### New RLS policy on `campaigns`
```sql
CREATE POLICY "Clients can view subscribed campaigns"
    ON campaigns FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions
            WHERE subscriptions.client_id = auth.uid()
            AND subscriptions.campaign_id = campaigns.id
            AND subscriptions.is_active = true
        )
    );
```

## Admin Panel Changes

### Types (`admin/src/types/index.ts`)
- Add `CampaignInvitation` interface: `{ id, campaign_id, token, created_by, redeemed_by, redeemed_at, created_at, client?: { name, email } }`

### Campaign Detail Page (`CampaignDetailPage.tsx`)
- Add new **Invitations** section (between Subscribers and Check-in Responses)
- "Generate Invitation" button creates a new row in `campaign_invitations` with a random token
- Display the shareable link: `{window.location.origin}/invite/{token}`
- Each invitation row shows: token (truncated), status (available/redeemed), redeemed by (if consumed), created date
- Copy-link button per invitation
- Delete button for unused invitations
- Batch generate option: "Generate N invitations" (creates multiple at once)

## Mobile App Changes

### Router (`router/router.dart`)
- Add route: `/invite/:token` → new `InviteScreen`
- This route should work for both authenticated and unauthenticated users:
  - If not logged in → redirect to `/login` with the token preserved, then redirect back after auth
  - If logged in → process the invitation directly

### New Screen: `InviteScreen` (`features/invite/screens/invite_screen.dart`)
- Receives `token` parameter
- Calls `SupabaseService.redeemInvitation(token)` which:
  1. Looks up `campaign_invitations` by token
  2. Validates: not already redeemed
  3. Ensures client profile exists
  4. Subscribes to the campaign (`subscriptions` upsert)
  5. Marks invitation as redeemed (`redeemed_by`, `redeemed_at`)
  6. Returns the campaign for display
- Shows success: "You've been invited to {campaign name}" with a "Go to Home" button
- Shows error states: invalid token, already redeemed, already subscribed

### SupabaseService (`services/supabase_service.dart`)
- Add `redeemInvitation(String token)` method (steps above)
- Remove `getActiveCampaigns()` — no longer needed

### Remove Campaign Browsing
- **Delete** `CampaignsScreen` (`campaigns_screen.dart`) — the "Browse Campaigns" page
- **Remove** `/campaigns` route from router (keep `/campaigns/:id` for detail view of subscribed campaigns)
- **HomeScreen**: Remove the FAB "Find Campaigns" button that links to `/campaigns`
- **CampaignDetailScreen**: Remove the subscribe/unsubscribe button (subscription is now only via invitation). Keep the page for viewing campaign details of already-subscribed campaigns. Adjust the back button to go to `/` instead of `/campaigns`.

### Deep Linking
- Configure deep link handling so that `https://yourdomain.com/invite/{token}` opens the app (or falls back to web)
- For now, at minimum support in-app routing to `/invite/:token`

## QR Code Support

### Admin Panel
- When an invitation is generated, show a QR code icon/button
- Clicking it opens a modal with a QR code encoding the invite URL
- Use a lightweight QR library (e.g., `qrcode.react` or generate via a simple canvas-based approach)
- Admin can download/print the QR code

## Summary of Files to Change

### New files
- `supabase/migrations/008_invite_only_campaigns.sql`
- `mobile/lib/features/invite/screens/invite_screen.dart`

### Modified files
- `admin/src/types/index.ts` — add CampaignInvitation type
- `admin/src/pages/CampaignDetailPage.tsx` — add Invitations section
- `admin/package.json` — add QR code library
- `mobile/lib/router/router.dart` — add invite route, remove campaigns route
- `mobile/lib/services/supabase_service.dart` — add redeemInvitation, remove getActiveCampaigns
- `mobile/lib/features/home/screens/home_screen.dart` — remove "Find Campaigns" FAB
- `mobile/lib/features/campaigns/screens/campaign_detail_screen.dart` — remove subscribe button, fix back nav

### Deleted files
- `mobile/lib/features/campaigns/screens/campaigns_screen.dart`
