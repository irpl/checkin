-- Row Level Security Policies

-- Enable RLS on all tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE beacons ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;

-- Note: admins table has RLS DISABLED to avoid recursion issues
-- It only contains admin-to-org mappings and is protected by auth
ALTER TABLE admins DISABLE ROW LEVEL SECURITY;

-- ============================================
-- ORGANIZATIONS
-- ============================================
CREATE POLICY "Admins can view own organization"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            WHERE admins.id = auth.uid()
            AND admins.organization_id = organizations.id
        )
    );

CREATE POLICY "Admins can update own organization"
    ON organizations FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            WHERE admins.id = auth.uid()
            AND admins.organization_id = organizations.id
        )
    );

-- ============================================
-- CAMPAIGNS
-- ============================================
CREATE POLICY "Admins can select campaigns"
    ON campaigns FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            WHERE admins.id = auth.uid()
            AND admins.organization_id = campaigns.organization_id
        )
    );

CREATE POLICY "Admins can insert campaigns"
    ON campaigns FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admins
            WHERE admins.id = auth.uid()
            AND admins.organization_id = campaigns.organization_id
        )
    );

CREATE POLICY "Admins can update campaigns"
    ON campaigns FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            WHERE admins.id = auth.uid()
            AND admins.organization_id = campaigns.organization_id
        )
    );

CREATE POLICY "Admins can delete campaigns"
    ON campaigns FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            WHERE admins.id = auth.uid()
            AND admins.organization_id = campaigns.organization_id
        )
    );

-- Clients can view active campaigns for subscription browsing
CREATE POLICY "Anyone can view active campaigns"
    ON campaigns FOR SELECT
    TO authenticated
    USING (is_active = true);

-- ============================================
-- BEACONS
-- ============================================
CREATE POLICY "Admins can select beacons"
    ON beacons FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = beacons.campaign_id
        )
    );

CREATE POLICY "Admins can insert beacons"
    ON beacons FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = beacons.campaign_id
        )
    );

CREATE POLICY "Admins can update beacons"
    ON beacons FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = beacons.campaign_id
        )
    );

CREATE POLICY "Admins can delete beacons"
    ON beacons FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = beacons.campaign_id
        )
    );

-- Clients can view beacons for subscribed campaigns
CREATE POLICY "Clients can view beacons for subscribed campaigns"
    ON beacons FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions
            WHERE subscriptions.client_id = auth.uid()
            AND subscriptions.campaign_id = beacons.campaign_id
            AND subscriptions.is_active = true
        )
    );

-- ============================================
-- FORMS
-- ============================================
CREATE POLICY "Admins can select forms"
    ON forms FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = forms.campaign_id
        )
    );

CREATE POLICY "Admins can insert forms"
    ON forms FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = forms.campaign_id
        )
    );

CREATE POLICY "Admins can update forms"
    ON forms FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = forms.campaign_id
        )
    );

CREATE POLICY "Admins can delete forms"
    ON forms FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = forms.campaign_id
        )
    );

-- Clients can view forms for subscribed campaigns
CREATE POLICY "Clients can view forms for subscribed campaigns"
    ON forms FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions
            WHERE subscriptions.client_id = auth.uid()
            AND subscriptions.campaign_id = forms.campaign_id
            AND subscriptions.is_active = true
        )
    );

-- ============================================
-- CLIENTS
-- ============================================
CREATE POLICY "Clients can view own profile"
    ON clients FOR SELECT
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Clients can update own profile"
    ON clients FOR UPDATE
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Clients can insert own profile"
    ON clients FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

-- ============================================
-- SUBSCRIPTIONS
-- ============================================
CREATE POLICY "Clients can manage own subscriptions"
    ON subscriptions FOR ALL
    TO authenticated
    USING (client_id = auth.uid());

-- Admins can view subscriptions for their campaigns
CREATE POLICY "Admins can view campaign subscriptions"
    ON subscriptions FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = subscriptions.campaign_id
        )
    );

-- ============================================
-- CHECKINS
-- ============================================
CREATE POLICY "Clients can manage own checkins"
    ON checkins FOR ALL
    TO authenticated
    USING (client_id = auth.uid());

-- Admins can view checkins for their campaigns
CREATE POLICY "Admins can view campaign checkins"
    ON checkins FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = checkins.campaign_id
        )
    );
