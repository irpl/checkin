-- Invite-only campaigns: users can only join via unique, single-use invitation links

-- Create campaign_invitations table
CREATE TABLE campaign_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES admins(id) ON DELETE SET NULL,
    redeemed_by UUID REFERENCES clients(id) ON DELETE SET NULL,
    redeemed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_campaign_invitations_token ON campaign_invitations(token);
CREATE INDEX idx_campaign_invitations_campaign ON campaign_invitations(campaign_id);

-- Enable RLS
ALTER TABLE campaign_invitations ENABLE ROW LEVEL SECURITY;

-- Admins can manage invitations for their org's campaigns
CREATE POLICY "Admins can select invitations"
    ON campaign_invitations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = campaign_invitations.campaign_id
        )
    );

CREATE POLICY "Admins can insert invitations"
    ON campaign_invitations FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = campaign_invitations.campaign_id
        )
    );

CREATE POLICY "Admins can delete invitations"
    ON campaign_invitations FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = campaign_invitations.campaign_id
        )
    );

-- Clients can look up invitations by token (for redemption)
CREATE POLICY "Clients can view invitations by token"
    ON campaign_invitations FOR SELECT
    TO authenticated
    USING (true);

-- Clients can redeem invitations (update redeemed_by and redeemed_at)
CREATE POLICY "Clients can redeem invitations"
    ON campaign_invitations FOR UPDATE
    TO authenticated
    USING (redeemed_by IS NULL)
    WITH CHECK (redeemed_by = auth.uid());

-- Remove public campaign visibility
DROP POLICY IF EXISTS "Anyone can view active campaigns" ON campaigns;

-- Clients can only view campaigns they are subscribed to
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
