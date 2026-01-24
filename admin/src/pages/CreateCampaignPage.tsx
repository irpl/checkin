import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { supabase } from '../lib/supabase'
import { ArrowLeft } from 'lucide-react'

const campaignSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  description: z.string().optional(),
  campaign_type: z.enum(['instant', 'duration']),
  required_duration_minutes: z.number().min(0).default(0),
  required_presence_percentage: z.number().min(1).max(100).default(100),
  proximity_delay_seconds: z.number().min(0).default(0),
  is_active: z.boolean().default(true),
})

type CampaignForm = z.infer<typeof campaignSchema>

export default function CreateCampaignPage() {
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)

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
      is_active: true,
    },
  })

  const campaignType = watch('campaign_type')

  const onSubmit = async (data: CampaignForm) => {
    try {
      setError(null)
      const { error } = await supabase.from('campaigns').insert({
        ...data,
        organization_id: (await supabase.rpc('get_admin_org_id')).data,
      })
      if (error) throw error
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
