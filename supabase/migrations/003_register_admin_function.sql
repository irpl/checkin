-- Registration helper function
-- This bypasses RLS since the user may not have a valid session yet after signup

CREATE OR REPLACE FUNCTION register_admin(
    admin_user_id UUID,
    admin_email TEXT,
    org_name TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_org_id UUID;
BEGIN
    -- Create organization
    INSERT INTO organizations (name)
    VALUES (org_name)
    RETURNING id INTO new_org_id;

    -- Create admin profile
    INSERT INTO admins (id, organization_id, email)
    VALUES (admin_user_id, new_org_id, admin_email);

    RETURN new_org_id;
END;
$$;
