-- Add Eddystone beacon support

-- Add beacon_type column to distinguish between iBeacon and Eddystone
ALTER TABLE beacons ADD COLUMN beacon_type TEXT NOT NULL DEFAULT 'ibeacon'
    CHECK (beacon_type IN ('ibeacon', 'eddystone'));

-- Add Eddystone-UID fields
-- Eddystone-UID uses: 10-byte namespace ID + 6-byte instance ID
ALTER TABLE beacons ADD COLUMN eddystone_namespace TEXT; -- 10 bytes as hex (20 chars)
ALTER TABLE beacons ADD COLUMN eddystone_instance TEXT;  -- 6 bytes as hex (12 chars)

-- Make beacon_uuid nullable since Eddystone doesn't use it
ALTER TABLE beacons ALTER COLUMN beacon_uuid DROP NOT NULL;

-- Add constraint: ibeacon requires uuid, eddystone requires namespace+instance
ALTER TABLE beacons ADD CONSTRAINT beacon_type_fields_check CHECK (
    (beacon_type = 'ibeacon' AND beacon_uuid IS NOT NULL) OR
    (beacon_type = 'eddystone' AND eddystone_namespace IS NOT NULL AND eddystone_instance IS NOT NULL)
);

-- Add index for Eddystone lookups
CREATE INDEX idx_beacons_eddystone ON beacons(eddystone_namespace, eddystone_instance);
