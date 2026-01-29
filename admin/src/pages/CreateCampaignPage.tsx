import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { supabase } from '../lib/supabase'
import { ArrowLeft, Plus, Trash2 } from 'lucide-react'

interface TimeBlock {
  day_of_week: number
  start_time: string
  end_time: string
  presence_percentage: number | null
}

const campaignSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  description: z.string().optional(),
  campaign_type: z.enum(['instant', 'duration']),
  required_duration_minutes: z.number().min(0).default(0),
  required_presence_percentage: z.number().min(1).max(100).default(100),
  proximity_delay_seconds: z.number().min(0).default(0),
  time_restriction_enabled: z.boolean().default(false),
  allowed_start_time: z.string().optional(),
  allowed_end_time: z.string().optional(),
  is_active: z.boolean().default(true),
})

type CampaignForm = z.infer<typeof campaignSchema>

const DAYS_OF_WEEK = [
  { value: 0, label: 'Sunday' },
  { value: 1, label: 'Monday' },
  { value: 2, label: 'Tuesday' },
  { value: 3, label: 'Wednesday' },
  { value: 4, label: 'Thursday' },
  { value: 5, label: 'Friday' },
  { value: 6, label: 'Saturday' },
]

export default function CreateCampaignPage() {
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const [timeBlocks, setTimeBlocks] = useState<TimeBlock[]>([])
  const [useTimeBlocks, setUseTimeBlocks] = useState(false)

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<CampaignForm>({
    resolver: zodResolver(campaignSchema),
    defaultValues: {
      campaign_type: 'instant',
      required_duration_minutes: 0,
      required_presence_percentage: 100,
      proximity_delay_seconds: 0,
      time_restriction_enabled: false,
      allowed_start_time: '',
      allowed_end_time: '',
      is_active: true,
    },
  })

  const campaignType = watch('campaign_type')
  const requiredPresencePercentage = watch('required_presence_percentage')
  const timeRestrictionEnabled = watch('time_restriction_enabled')

  const addTimeBlock = () => {
    setTimeBlocks([
      ...timeBlocks,
      {
        day_of_week: 1, // Monday
        start_time: '09:00',
        end_time: '11:00',
        presence_percentage: null, // Use campaign default
      },
    ])
  }

  const removeTimeBlock = (index: number) => {
    setTimeBlocks(timeBlocks.filter((_, i) => i !== index))
  }

  const updateTimeBlock = (index: number, field: keyof TimeBlock, value: any) => {
    const updated = [...timeBlocks]
    updated[index] = { ...updated[index], [field]: value }
    setTimeBlocks(updated)
  }

  const onSubmit = async (data: CampaignForm) => {
    try {
      setError(null)

      // Create the campaign first
      const { data: campaign, error: campaignError } = await supabase
        .from('campaigns')
        .insert({
          ...data,
          allowed_start_time: data.time_restriction_enabled && data.allowed_start_time
            ? data.allowed_start_time
            : null,
          allowed_end_time: data.time_restriction_enabled && data.allowed_end_time
            ? data.allowed_end_time
            : null,
          organization_id: (await supabase.rpc('get_admin_org_id')).data,
        })
        .select()
        .single()

      if (campaignError) throw campaignError

      // If using time blocks, save them
      if (useTimeBlocks && timeBlocks.length > 0 && campaign) {
        const timeBlocksToInsert = timeBlocks.map(block => ({
          campaign_id: campaign.id,
          day_of_week: block.day_of_week,
          start_time: block.start_time,
          end_time: block.end_time,
          presence_percentage: block.presence_percentage,
        }))

        const { error: timeBlocksError } = await supabase
          .from('campaign_time_blocks')
          .insert(timeBlocksToInsert)

        if (timeBlocksError) throw timeBlocksError
      }

      navigate('/campaigns')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create campaign')
    }
  }

  return (
    <div className="max-w-2xl">
      <Link
        to="/campaigns"
        className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6"
      >
        <ArrowLeft size={20} />
        Back to Campaigns
      </Link>

      <h1 className="text-2xl font-bold mb-6">Create Campaign</h1>

      {error && (
        <div className="bg-red-50 text-red-600 p-3 rounded mb-4 text-sm">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit(onSubmit)} className="bg-white rounded-lg shadow p-6 space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Campaign Name *
          </label>
          <input
            type="text"
            {...register('name')}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="e.g., Store Pickup, Class Attendance"
          />
          {errors.name && (
            <p className="text-red-500 text-sm mt-1">{errors.name.message}</p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Description
          </label>
          <textarea
            {...register('description')}
            rows={3}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Describe what this campaign is for..."
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Campaign Type *
          </label>
          <select
            {...register('campaign_type')}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="instant">Instant Check-in</option>
            <option value="duration">Duration-based (e.g., attendance)</option>
          </select>
          <p className="text-sm text-gray-500 mt-1">
            {campaignType === 'instant'
              ? 'User checks in immediately upon confirmation'
              : 'User must be present for a specified duration'}
          </p>
        </div>

        {campaignType === 'duration' && (
          <>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Required Duration (minutes)
              </label>
              <input
                type="number"
                {...register('required_duration_minutes', { valueAsNumber: true })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                min={0}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Required Presence Percentage
              </label>
              <input
                type="number"
                {...register('required_presence_percentage', { valueAsNumber: true })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                min={1}
                max={100}
              />
              <p className="text-sm text-gray-500 mt-1">
                What percentage of the duration must the user be present?
              </p>
            </div>
          </>
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Proximity Delay (seconds)
          </label>
          <input
            type="number"
            {...register('proximity_delay_seconds', { valueAsNumber: true })}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            min={0}
          />
          <p className="text-sm text-gray-500 mt-1">
            How long should the user be near the beacon before prompting check-in?
          </p>
        </div>

        <div className="border-t pt-6">
          <div className="flex items-center gap-2 mb-4">
            <input
              type="checkbox"
              checked={useTimeBlocks}
              onChange={(e) => setUseTimeBlocks(e.target.checked)}
              id="use_time_blocks"
              className="rounded border-gray-300"
            />
            <label htmlFor="use_time_blocks" className="text-sm font-medium text-gray-700">
              Schedule specific times for check-in
            </label>
          </div>

          {useTimeBlocks && (
            <div className="ml-6 space-y-4">
              <p className="text-sm text-gray-600">
                Add time blocks for when check-ins are allowed. For example, if a check-in is only allowed on Monday 8-10am and Wednesday 12-2pm, add those as separate time blocks.
              </p>

              {timeBlocks.map((block, index) => (
                <div key={index} className="border border-gray-200 rounded-md p-4 space-y-3">
                  <div className="flex justify-between items-center">
                    <h4 className="font-medium text-gray-700">Time Block {index + 1}</h4>
                    <button
                      type="button"
                      onClick={() => removeTimeBlock(index)}
                      className="text-red-600 hover:text-red-800"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>

                  <div className="grid grid-cols-3 gap-3">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Day of Week
                      </label>
                      <select
                        value={block.day_of_week}
                        onChange={(e) => updateTimeBlock(index, 'day_of_week', parseInt(e.target.value))}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      >
                        {DAYS_OF_WEEK.map(day => (
                          <option key={day.value} value={day.value}>
                            {day.label}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Start Time
                      </label>
                      <input
                        type="time"
                        value={block.start_time}
                        onChange={(e) => updateTimeBlock(index, 'start_time', e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        End Time
                      </label>
                      <input
                        type="time"
                        value={block.end_time}
                        onChange={(e) => updateTimeBlock(index, 'end_time', e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                  </div>

                  {campaignType === 'duration' && (
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Presence Percentage Override (optional)
                      </label>
                      <input
                        type="number"
                        value={block.presence_percentage ?? ''}
                        onChange={(e) => updateTimeBlock(index, 'presence_percentage', e.target.value ? parseInt(e.target.value) : null)}
                        placeholder={`Default: ${requiredPresencePercentage}%`}
                        min={1}
                        max={100}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                      <p className="text-xs text-gray-500 mt-1">
                        Leave empty to use campaign default ({requiredPresencePercentage}%).
                        Set a custom percentage for this time block if needed.
                      </p>
                    </div>
                  )}
                </div>
              ))}

              <button
                type="button"
                onClick={addTimeBlock}
                className="flex items-center gap-2 px-4 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50"
              >
                <Plus size={16} />
                Add Time Block
              </button>

              {timeBlocks.length === 0 && (
                <p className="text-sm text-amber-600">
                  Add at least one time block to enable scheduled check-ins.
                </p>
              )}
            </div>
          )}
        </div>

        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            {...register('is_active')}
            id="is_active"
            className="rounded border-gray-300"
          />
          <label htmlFor="is_active" className="text-sm text-gray-700">
            Campaign is active
          </label>
        </div>

        <div className="flex gap-3 pt-4">
          <button
            type="submit"
            disabled={isSubmitting}
            className="flex-1 bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {isSubmitting ? 'Creating...' : 'Create Campaign'}
          </button>
          <Link
            to="/campaigns"
            className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </Link>
        </div>
      </form>
    </div>
  )
}
