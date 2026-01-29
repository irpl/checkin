export interface Organization {
  id: string
  name: string
  created_at: string
  updated_at: string
}

export interface CampaignTimeBlock {
  id: string
  campaign_id: string
  day_of_week: number  // 0=Sunday, 1=Monday, ..., 6=Saturday
  start_time: string   // TIME format: "HH:MM:SS"
  end_time: string     // TIME format: "HH:MM:SS"
  presence_percentage: number | null  // Override for this block, null = use campaign default
  created_at: string
  updated_at: string
}

export interface Campaign {
  id: string
  organization_id: string
  name: string
  description: string | null
  campaign_type: 'instant' | 'duration'
  required_duration_minutes: number
  required_presence_percentage: number
  proximity_delay_seconds: number
  // Time restrictions (legacy - kept for backward compatibility)
  time_restriction_enabled: boolean
  allowed_start_time: string | null  // TIME format: "HH:MM:SS"
  allowed_end_time: string | null    // TIME format: "HH:MM:SS"
  // New time blocks system
  time_blocks?: CampaignTimeBlock[]
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface Beacon {
  id: string
  campaign_id: string
  name: string
  beacon_uuid: string | null
  major: number | null
  minor: number | null
  location_description: string | null
  is_active: boolean
  created_at: string
}

export interface FormSchema {
  id: string
  campaign_id: string
  title: string
  description: string | null
  schema: {
    fields: FormField[]
  }
  created_at: string
  updated_at: string
}

export interface FormField {
  id: string
  type: 'text' | 'textarea' | 'number' | 'select' | 'checkbox'
  label: string
  placeholder?: string
  required: boolean
  options?: string[]
  default_value?: unknown
}

export interface Checkin {
  id: string
  client_id: string
  campaign_id: string
  beacon_id: string | null
  status: 'pending' | 'confirmed' | 'completed' | 'expired'
  first_detected_at: string
  presence_confirmed_at: string | null
  form_response: Record<string, unknown> | null
  checked_in_at: string | null
  created_at: string
  client?: {
    name: string
    email: string
  }
}

export interface Subscription {
  id: string
  client_id: string
  campaign_id: string
  subscribed_at: string
  is_active: boolean
}
