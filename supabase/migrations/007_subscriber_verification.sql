-- Add subscriber verification feature
-- Allows admins to optionally require manual verification of subscribers before they can check in

-- Add verification flag to campaigns
ALTER TABLE campaigns
    ADD COLUMN requires_subscriber_verification BOOLEAN NOT NULL DEFAULT false;

-- Add verified status to subscriptions
ALTER TABLE subscriptions
    ADD COLUMN verified BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN verified_at TIMESTAMPTZ;

-- Allow admins to update subscriptions (for verification)
CREATE POLICY "Admins can update campaign subscriptions"
    ON subscriptions FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admins
            JOIN campaigns ON campaigns.organization_id = admins.organization_id
            WHERE admins.id = auth.uid()
            AND campaigns.id = subscriptions.campaign_id
        )
    );

-- Admins can view client profiles for subscribers to their campaigns
CREATE POLICY "Admins can view clients subscribed to their campaigns"
    ON clients FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions
            JOIN campaigns ON campaigns.id = subscriptions.campaign_id
            JOIN admins ON admins.organization_id = campaigns.organization_id
            WHERE admins.id = auth.uid()
            AND subscriptions.client_id = clients.id
        )
    );
