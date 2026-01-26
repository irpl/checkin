-- Add time-of-day restrictions for campaigns
-- Allows admins to specify when check-ins are allowed (e.g., 9:00 AM to 11:00 AM)

-- Add time restriction fields to campaigns
ALTER TABLE campaigns ADD COLUMN time_restriction_enabled BOOLEAN DEFAULT false;
ALTER TABLE campaigns ADD COLUMN allowed_start_time TIME;
ALTER TABLE campaigns ADD COLUMN allowed_end_time TIME;

-- Add constraint to ensure both times are set if restriction is enabled
ALTER TABLE campaigns ADD CONSTRAINT time_restriction_check CHECK (
    (time_restriction_enabled = false) OR
    (time_restriction_enabled = true AND allowed_start_time IS NOT NULL AND allowed_end_time IS NOT NULL)
);

-- Add comment for documentation
COMMENT ON COLUMN campaigns.time_restriction_enabled IS 'When true, check-ins are only allowed between allowed_start_time and allowed_end_time';
COMMENT ON COLUMN campaigns.allowed_start_time IS 'Start time for allowed check-in window (local time)';
COMMENT ON COLUMN campaigns.allowed_end_time IS 'End time for allowed check-in window (local time)';
