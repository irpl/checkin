-- Secure the admins table by enabling RLS and using SECURITY DEFINER helpers
-- to avoid recursive policy checks.

-- Step 1: Create SECURITY DEFINER helper functions
-- These bypass RLS when called, breaking the recursion cycle.

CREATE OR REPLACE FUNCTION public.is_admin_of(org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM admins
        WHERE admins.id = auth.uid()
        AND admins.organization_id = org_id
    );
$$;

CREATE OR REPLACE FUNCTION public.get_admin_org_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT organization_id FROM admins
    WHERE id = auth.uid()
    LIMIT 1;
$$;

-- Grant execute to authenticated role (needed for RLS policy evaluation)
GRANT EXECUTE ON FUNCTION public.is_admin_of(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_org_id() TO authenticated;

-- Revoke from anon — these should never be callable without auth
REVOKE EXECUTE ON FUNCTION public.is_admin_of(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_admin_org_id() FROM anon;

-- Step 2: Enable RLS on admins
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- Step 3: Replace admins table policies
DROP POLICY IF EXISTS "Admins can view own profile" ON admins;
DROP POLICY IF EXISTS "Users can create own admin profile" ON admins;

CREATE POLICY "Admins can view own record"
    ON admins FOR SELECT
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Admins can update own record"
    ON admins FOR UPDATE
    TO authenticated
    USING (id = auth.uid());

-- Step 4: Drop and recreate all policies that reference the admins table
-- to use the new SECURITY DEFINER functions instead.

-- ============================================
-- ORGANIZATIONS
-- ============================================
DROP POLICY IF EXISTS "Admins can view own organization" ON organizations;
CREATE POLICY "Admins can view own organization"
    ON organizations FOR SELECT
    TO authenticated
    USING (public.is_admin_of(id));

DROP POLICY IF EXISTS "Admins can update own organization" ON organizations;
CREATE POLICY "Admins can update own organization"
    ON organizations FOR UPDATE
    TO authenticated
    USING (public.is_admin_of(id));

-- ============================================
-- CAMPAIGNS
-- ============================================
DROP POLICY IF EXISTS "Admins can select campaigns" ON campaigns;
CREATE POLICY "Admins can select campaigns"
    ON campaigns FOR SELECT
    TO authenticated
    USING (public.is_admin_of(organization_id));

DROP POLICY IF EXISTS "Admins can insert campaigns" ON campaigns;
CREATE POLICY "Admins can insert campaigns"
    ON campaigns FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin_of(organization_id));

DROP POLICY IF EXISTS "Admins can update campaigns" ON campaigns;
CREATE POLICY "Admins can update campaigns"
    ON campaigns FOR UPDATE
    TO authenticated
    USING (public.is_admin_of(organization_id));

DROP POLICY IF EXISTS "Admins can delete campaigns" ON campaigns;
CREATE POLICY "Admins can delete campaigns"
    ON campaigns FOR DELETE
    TO authenticated
    USING (public.is_admin_of(organization_id));

-- ============================================
-- BEACONS
-- ============================================
DROP POLICY IF EXISTS "Admins can manage beacons" ON beacons;

CREATE POLICY "Admins can select beacons"
    ON beacons FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = beacons.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

CREATE POLICY "Admins can insert beacons"
    ON beacons FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = beacons.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

CREATE POLICY "Admins can update beacons"
    ON beacons FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = beacons.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

CREATE POLICY "Admins can delete beacons"
    ON beacons FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = beacons.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

-- ============================================
-- FORMS
-- ============================================
DROP POLICY IF EXISTS "Admins can manage forms" ON forms;

CREATE POLICY "Admins can select forms"
    ON forms FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = forms.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

CREATE POLICY "Admins can insert forms"
    ON forms FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = forms.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

CREATE POLICY "Admins can update forms"
    ON forms FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = forms.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

CREATE POLICY "Admins can delete forms"
    ON forms FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = forms.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

-- ============================================
-- SUBSCRIPTIONS
-- ============================================
DROP POLICY IF EXISTS "Admins can view campaign subscriptions" ON subscriptions;
CREATE POLICY "Admins can view campaign subscriptions"
    ON subscriptions FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = subscriptions.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

DROP POLICY IF EXISTS "Admins can update campaign subscriptions" ON subscriptions;
CREATE POLICY "Admins can update campaign subscriptions"
    ON subscriptions FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = subscriptions.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

-- ============================================
-- CHECKINS
-- ============================================
DROP POLICY IF EXISTS "Admins can view campaign checkins" ON checkins;
CREATE POLICY "Admins can view campaign checkins"
    ON checkins FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = checkins.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

-- ============================================
-- CAMPAIGN TIME BLOCKS
-- ============================================
-- Drop old names (from 006) and truncated variants from prior DB state
DROP POLICY IF EXISTS "Admins can view org campaign time blocks" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can view time blocks for their organization's campaigns" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can view time blocks for their organization's campaign" ON campaign_time_blocks;
CREATE POLICY "Admins can view org campaign time blocks"
    ON campaign_time_blocks FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = campaign_time_blocks.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

DROP POLICY IF EXISTS "Admins can insert org campaign time blocks" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can insert time blocks for their organization's campaigns" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can insert time blocks for their organization's campaign" ON campaign_time_blocks;
CREATE POLICY "Admins can insert org campaign time blocks"
    ON campaign_time_blocks FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = campaign_time_blocks.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

DROP POLICY IF EXISTS "Admins can update org campaign time blocks" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can update time blocks for their organization's campaigns" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can update time blocks for their organization's campaign" ON campaign_time_blocks;
CREATE POLICY "Admins can update org campaign time blocks"
    ON campaign_time_blocks FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = campaign_time_blocks.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

DROP POLICY IF EXISTS "Admins can delete org campaign time blocks" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can delete time blocks for their organization's campaigns" ON campaign_time_blocks;
DROP POLICY IF EXISTS "Admins can delete time blocks for their organization's campaign" ON campaign_time_blocks;
CREATE POLICY "Admins can delete org campaign time blocks"
    ON campaign_time_blocks FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns
            WHERE campaigns.id = campaign_time_blocks.campaign_id
            AND public.is_admin_of(campaigns.organization_id)
        )
    );

-- ============================================
-- CLIENTS (admin viewing subscribers)
-- ============================================
DROP POLICY IF EXISTS "Admins can view clients subscribed to their campaigns" ON clients;
CREATE POLICY "Admins can view clients subscribed to their campaigns"
    ON clients FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions
            JOIN campaigns ON campaigns.id = subscriptions.campaign_id
            WHERE public.is_admin_of(campaigns.organization_id)
            AND subscriptions.client_id = clients.id
        )
    );
