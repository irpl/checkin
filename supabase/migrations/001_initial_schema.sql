-- Checkin App Database Schema

-- Organizations (businesses, schools, etc.)
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Admin users (linked to Supabase auth)
CREATE TABLE admins (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Campaigns (check-in contexts: store pickup, classroom, restaurant, etc.)
CREATE TABLE campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    campaign_type TEXT NOT NULL CHECK (campaign_type IN ('instant', 'duration')),
    -- For duration-based campaigns (e.g., classroom attendance)
    required_duration_minutes INTEGER DEFAULT 0,
    required_presence_percentage INTEGER DEFAULT 100 CHECK (required_presence_percentage BETWEEN 1 AND 100),
    -- Proximity settings
    proximity_delay_seconds INTEGER DEFAULT 0, -- How long before prompting check-in
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Beacons associated with campaigns
CREATE TABLE beacons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    -- BLE beacon identifiers (iBeacon format)
    beacon_uuid TEXT NOT NULL, -- The UUID broadcast by the beacon
    major INTEGER, -- Optional major value (0-65535)
    minor INTEGER, -- Optional minor value (0-65535)
    -- Location info
    location_description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Form definitions (JSON schema for dynamic forms)
CREATE TABLE forms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    -- JSON schema defining the form fields
    schema JSONB NOT NULL DEFAULT '{"fields": []}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Client users (people who check in)
CREATE TABLE clients (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    name TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Client subscriptions to campaigns
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(client_id, campaign_id)
);

-- Check-in records
CREATE TABLE checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
    beacon_id UUID REFERENCES beacons(id) ON DELETE SET NULL,
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'expired')),
    -- For duration-based check-ins
    first_detected_at TIMESTAMPTZ DEFAULT NOW(),
    presence_confirmed_at TIMESTAMPTZ,
    -- Form response (if applicable)
    form_response JSONB,
    -- Timestamps
    checked_in_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_campaigns_org ON campaigns(organization_id);
CREATE INDEX idx_beacons_campaign ON beacons(campaign_id);
CREATE INDEX idx_beacons_uuid ON beacons(beacon_uuid);
CREATE INDEX idx_subscriptions_client ON subscriptions(client_id);
CREATE INDEX idx_subscriptions_campaign ON subscriptions(campaign_id);
CREATE INDEX idx_checkins_client ON checkins(client_id);
CREATE INDEX idx_checkins_campaign ON checkins(campaign_id);
CREATE INDEX idx_checkins_status ON checkins(status);
CREATE INDEX idx_checkins_created ON checkins(created_at DESC);

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_campaigns_updated_at
    BEFORE UPDATE ON campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_forms_updated_at
    BEFORE UPDATE ON forms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
