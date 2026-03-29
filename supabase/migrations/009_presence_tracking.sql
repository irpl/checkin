-- Migration 009: Add presence tracking support for duration campaigns

-- Add actual presence percentage to checkins (recorded by mobile app)
ALTER TABLE checkins
    ADD COLUMN actual_presence_percentage INTEGER CHECK (
        actual_presence_percentage IS NULL OR (actual_presence_percentage BETWEEN 0 AND 100)
    ),
    ADD COLUMN session_started_at TIMESTAMPTZ,
    ADD COLUMN session_ended_at TIMESTAMPTZ;

-- Server-side validation function for completing duration check-ins
-- Ensures actual_presence_percentage meets the campaign's requirement
CREATE OR REPLACE FUNCTION complete_duration_checkin(
    p_checkin_id UUID,
    p_actual_presence_percentage INTEGER,
    p_form_response JSONB DEFAULT NULL
)
RETURNS TABLE(id UUID, status TEXT, actual_presence_percentage INTEGER) AS $$
DECLARE
    v_campaign_id UUID;
    v_campaign_type TEXT;
    v_required_percentage INTEGER;
    v_checkin_status TEXT;
BEGIN
    -- Get the checkin and its campaign info
    SELECT c.campaign_id, c.status
    INTO v_campaign_id, v_checkin_status
    FROM checkins c
    WHERE c.id = p_checkin_id
      AND c.client_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Checkin not found or not owned by current user';
    END IF;

    IF v_checkin_status NOT IN ('pending', 'confirmed') THEN
        RAISE EXCEPTION 'Checkin is already completed or expired';
    END IF;

    -- Get campaign requirements
    SELECT cam.campaign_type, cam.required_presence_percentage
    INTO v_campaign_type, v_required_percentage
    FROM campaigns cam
    WHERE cam.id = v_campaign_id;

    -- For duration campaigns, check if presence meets the requirement
    -- Also check time-block-specific override
    IF v_campaign_type = 'duration' THEN
        -- Check for time-block-specific presence percentage override
        DECLARE
            v_block_percentage INTEGER;
            v_current_day INTEGER;
            v_current_time TIME;
        BEGIN
            v_current_day := EXTRACT(DOW FROM NOW())::INTEGER;
            v_current_time := NOW()::TIME;

            SELECT tb.presence_percentage
            INTO v_block_percentage
            FROM campaign_time_blocks tb
            WHERE tb.campaign_id = v_campaign_id
              AND tb.day_of_week = v_current_day
              AND v_current_time BETWEEN tb.start_time AND tb.end_time
            LIMIT 1;

            IF v_block_percentage IS NOT NULL THEN
                v_required_percentage := v_block_percentage;
            END IF;
        END;

        IF p_actual_presence_percentage < v_required_percentage THEN
            RAISE EXCEPTION 'Insufficient presence: % actual, % required',
                p_actual_presence_percentage, v_required_percentage;
        END IF;
    END IF;

    -- Update the checkin
    UPDATE checkins
    SET status = 'completed',
        actual_presence_percentage = p_actual_presence_percentage,
        form_response = p_form_response,
        checked_in_at = NOW(),
        session_ended_at = NOW()
    WHERE checkins.id = p_checkin_id
    RETURNING checkins.id, checkins.status, checkins.actual_presence_percentage
    INTO id, status, actual_presence_percentage;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION complete_duration_checkin TO authenticated;
