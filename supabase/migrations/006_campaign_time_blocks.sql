-- Migration: Add campaign_time_blocks table for multiple scheduled sessions per campaign
-- This allows campaigns to have different time slots (e.g., Monday 8-10am, Wednesday 12-2pm)
-- with optional per-time-block presence percentage overrides

-- Create function to update updated_at timestamp (if it doesn't exist)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create campaign_time_blocks table
CREATE TABLE campaign_time_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday, 6=Saturday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    presence_percentage INTEGER CHECK (presence_percentage IS NULL OR (presence_percentage >= 1 AND presence_percentage <= 100)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_time_range CHECK (start_time < end_time)
);

-- Add index for efficient campaign lookups
CREATE INDEX idx_campaign_time_blocks_campaign_id ON campaign_time_blocks(campaign_id);

-- Add index for day/time lookups
CREATE INDEX idx_campaign_time_blocks_day_time ON campaign_time_blocks(day_of_week, start_time, end_time);

-- Add updated_at trigger
CREATE TRIGGER update_campaign_time_blocks_updated_at
    BEFORE UPDATE ON campaign_time_blocks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Migrate existing time restrictions to time blocks
-- For campaigns with time_restriction_enabled, we'll create a time block for each day of the week
-- since the old system didn't specify which days, we assume all days
INSERT INTO campaign_time_blocks (campaign_id, day_of_week, start_time, end_time, presence_percentage)
SELECT
    id as campaign_id,
    generate_series(0, 6) as day_of_week, -- Create block for each day of week
    allowed_start_time,
    allowed_end_time,
    NULL as presence_percentage -- Use campaign default
FROM campaigns
WHERE time_restriction_enabled = true
  AND allowed_start_time IS NOT NULL
  AND allowed_end_time IS NOT NULL;

-- Row Level Security Policies for campaign_time_blocks

-- Enable RLS
ALTER TABLE campaign_time_blocks ENABLE ROW LEVEL SECURITY;

-- Admins can view time blocks for campaigns in their organization
CREATE POLICY "Admins can view time blocks for their organization's campaigns"
    ON campaign_time_blocks
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns c
            JOIN admins a ON a.organization_id = c.organization_id
            WHERE c.id = campaign_time_blocks.campaign_id
              AND a.id = auth.uid()
        )
    );

-- Admins can insert time blocks for campaigns in their organization
CREATE POLICY "Admins can insert time blocks for their organization's campaigns"
    ON campaign_time_blocks
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM campaigns c
            JOIN admins a ON a.organization_id = c.organization_id
            WHERE c.id = campaign_time_blocks.campaign_id
              AND a.id = auth.uid()
        )
    );

-- Admins can update time blocks for campaigns in their organization
CREATE POLICY "Admins can update time blocks for their organization's campaigns"
    ON campaign_time_blocks
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns c
            JOIN admins a ON a.organization_id = c.organization_id
            WHERE c.id = campaign_time_blocks.campaign_id
              AND a.id = auth.uid()
        )
    );

-- Admins can delete time blocks for campaigns in their organization
CREATE POLICY "Admins can delete time blocks for their organization's campaigns"
    ON campaign_time_blocks
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns c
            JOIN admins a ON a.organization_id = c.organization_id
            WHERE c.id = campaign_time_blocks.campaign_id
              AND a.id = auth.uid()
        )
    );

-- Clients can view time blocks for active campaigns
CREATE POLICY "Clients can view time blocks for active campaigns"
    ON campaign_time_blocks
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM campaigns c
            WHERE c.id = campaign_time_blocks.campaign_id
              AND c.is_active = true
        )
    );
