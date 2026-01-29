import { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Campaign, Beacon, FormSchema, FormField, Checkin, CampaignTimeBlock } from '../types'
import { ArrowLeft, Plus, Trash2, Bluetooth, FileText, ClipboardList, Calendar } from 'lucide-react'
import { format } from 'date-fns'

const DAYS_OF_WEEK = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export default function CampaignDetailPage() {
  const { id } = useParams<{ id: string }>()
  const [campaign, setCampaign] = useState<Campaign | null>(null)
  const [beacons, setBeacons] = useState<Beacon[]>([])
  const [form, setForm] = useState<FormSchema | null>(null)
  const [checkins, setCheckins] = useState<Checkin[]>([])
  const [loading, setLoading] = useState(true)
  const [showBeaconModal, setShowBeaconModal] = useState(false)
  const [showFormModal, setShowFormModal] = useState(false)
  const [groupByFields, setGroupByFields] = useState<string[]>([])

  // Fields that can be used for grouping (select and checkbox only)
  const groupableFields = useMemo(() => {
    if (!form) return []
    return form.schema.fields.filter((f) => f.type === 'select' || f.type === 'checkbox')
  }, [form])

  // Compute grouped check-ins based on selected groupBy fields
  const groupedCheckins = useMemo(() => {
    if (groupByFields.length === 0 || !form) return null

    const groups = new Map<string, { label: string; checkins: Checkin[] }>()

    for (const checkin of checkins) {
      // Build composite key from all selected group fields
      const keyParts: string[] = []
      const labelParts: string[] = []

      for (const fieldId of groupByFields) {
        const field = form.schema.fields.find((f) => f.id === fieldId)
        if (!field) continue

        const rawValue = checkin.form_response?.[fieldId]
        let displayValue: string

        if (field.type === 'checkbox') {
          displayValue = rawValue === true || rawValue === 'true' ? 'Yes' : 'No'
        } else {
          displayValue = rawValue != null ? String(rawValue) : '(empty)'
        }

        keyParts.push(`${fieldId}:${displayValue}`)
        labelParts.push(`${field.label}: ${displayValue}`)
      }

      const key = keyParts.join('|')
      const label = labelParts.join(' / ')

      if (!groups.has(key)) {
        groups.set(key, { label, checkins: [] })
      }
      groups.get(key)!.checkins.push(checkin)
    }

    // Sort groups by label
    return [...groups.values()].sort((a, b) => a.label.localeCompare(b.label))
  }, [checkins, groupByFields, form])

  const toggleGroupByField = (fieldId: string) => {
    setGroupByFields((prev) =>
      prev.includes(fieldId)
        ? prev.filter((id) => id !== fieldId)
        : [...prev, fieldId]
    )
  }

  useEffect(() => {
    if (id) loadCampaign()
  }, [id])

  const loadCampaign = async () => {
    try {
      const [campaignRes, beaconsRes, formRes, checkinsRes] = await Promise.all([
        supabase.from('campaigns').select('*, time_blocks:campaign_time_blocks(*)').eq('id', id).single(),
        supabase.from('beacons').select('*').eq('campaign_id', id),
        supabase.from('forms').select('*').eq('campaign_id', id).maybeSingle(),
        supabase
          .from('checkins')
          .select('*, client:clients(name, email)')
          .eq('campaign_id', id)
          .order('created_at', { ascending: false }),
      ])

      setCampaign(campaignRes.data)
      setBeacons(beaconsRes.data || [])
      setForm(formRes.data)
      setCheckins(checkinsRes.data || [])
    } finally {
      setLoading(false)
    }
  }

  const deleteBeacon = async (beaconId: string) => {
    if (!confirm('Are you sure you want to delete this beacon?')) return
    await supabase.from('beacons').delete().eq('id', beaconId)
    setBeacons(beacons.filter((b) => b.id !== beaconId))
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      </div>
    )
  }

  if (!campaign) {
    return <div>Campaign not found</div>
  }

  return (
    <div>
      <Link
        to="/campaigns"
        className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 mb-6"
      >
        <ArrowLeft size={20} />
        Back to Campaigns
      </Link>

      {/* Campaign Header */}
      <div className="bg-white rounded-lg shadow p-6 mb-6">
        <div className="flex justify-between items-start">
          <div>
            <h1 className="text-2xl font-bold">{campaign.name}</h1>
            {campaign.description && (
              <p className="text-gray-600 mt-1">{campaign.description}</p>
            )}
          </div>
          <span
            className={`px-3 py-1 rounded text-sm font-medium ${
              campaign.is_active
                ? 'bg-green-100 text-green-700'
                : 'bg-gray-100 text-gray-600'
            }`}
          >
            {campaign.is_active ? 'Active' : 'Inactive'}
          </span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 pt-6 border-t">
          <div>
            <p className="text-sm text-gray-500">Type</p>
            <p className="font-medium">
              {campaign.campaign_type === 'instant' ? 'Instant' : 'Duration-based'}
            </p>
          </div>
          {campaign.campaign_type === 'duration' && (
            <>
              <div>
                <p className="text-sm text-gray-500">Duration Required</p>
                <p className="font-medium">{campaign.required_duration_minutes} min</p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Presence Required</p>
                <p className="font-medium">{campaign.required_presence_percentage}%</p>
              </div>
            </>
          )}
          <div>
            <p className="text-sm text-gray-500">Proximity Delay</p>
            <p className="font-medium">{campaign.proximity_delay_seconds}s</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Created</p>
            <p className="font-medium">
              {format(new Date(campaign.created_at), 'MMM d, yyyy')}
            </p>
          </div>
        </div>

        {/* Time Blocks Section */}
        {campaign.time_blocks && campaign.time_blocks.length > 0 && (
          <div className="mt-6 pt-6 border-t">
            <div className="flex items-center gap-2 mb-3">
              <Calendar size={18} className="text-blue-600" />
              <h3 className="font-semibold">Scheduled Times</h3>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {campaign.time_blocks
                .sort((a, b) => a.day_of_week - b.day_of_week)
                .map((block) => (
                  <div key={block.id} className="bg-gray-50 rounded p-3">
                    <div className="flex justify-between items-start">
                      <div>
                        <p className="font-medium text-gray-900">
                          {DAYS_OF_WEEK[block.day_of_week]}
                        </p>
                        <p className="text-sm text-gray-600">
                          {block.start_time.slice(0, 5)} - {block.end_time.slice(0, 5)}
                        </p>
                      </div>
                      {block.presence_percentage && (
                        <span className="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                          {block.presence_percentage}% required
                        </span>
                      )}
                    </div>
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* Legacy time restriction display */}
        {(!campaign.time_blocks || campaign.time_blocks.length === 0) &&
         campaign.time_restriction_enabled &&
         campaign.allowed_start_time &&
         campaign.allowed_end_time && (
          <div className="mt-6 pt-6 border-t">
            <p className="text-sm text-gray-500 mb-1">Time Restriction (Legacy)</p>
            <p className="font-medium">
              {campaign.allowed_start_time.slice(0, 5)} - {campaign.allowed_end_time.slice(0, 5)}
            </p>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Beacons */}
        <div className="bg-white rounded-lg shadow">
          <div className="p-4 border-b flex justify-between items-center">
            <div className="flex items-center gap-2">
              <Bluetooth size={20} className="text-blue-600" />
              <h2 className="font-semibold">Beacons ({beacons.length})</h2>
            </div>
            <button
              onClick={() => setShowBeaconModal(true)}
              className="flex items-center gap-1 text-sm text-blue-600 hover:underline"
            >
              <Plus size={16} />
              Add Beacon
            </button>
          </div>
          <div className="divide-y">
            {beacons.length === 0 ? (
              <div className="p-4 text-gray-500 text-center">
                No beacons configured. Add one to enable check-ins.
              </div>
            ) : (
              beacons.map((beacon) => (
                <div key={beacon.id} className="p-4 flex justify-between items-start">
                  <div>
                    <p className="font-medium">{beacon.name}</p>
                    <p className="text-sm text-gray-500 font-mono">{beacon.beacon_uuid}</p>
                    {(beacon.major != null || beacon.minor != null) && (
                      <p className="text-sm text-gray-500">
                        Major: {beacon.major ?? '-'} / Minor: {beacon.minor ?? '-'}
                      </p>
                    )}
                    {beacon.location_description && (
                      <p className="text-sm text-gray-500">{beacon.location_description}</p>
                    )}
                  </div>
                  <button
                    onClick={() => deleteBeacon(beacon.id)}
                    className="text-red-500 hover:text-red-700"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Form */}
        <div className="bg-white rounded-lg shadow">
          <div className="p-4 border-b flex justify-between items-center">
            <div className="flex items-center gap-2">
              <FileText size={20} className="text-green-600" />
              <h2 className="font-semibold">Check-in Form</h2>
            </div>
            <button
              onClick={() => setShowFormModal(true)}
              className="flex items-center gap-1 text-sm text-blue-600 hover:underline"
            >
              {form ? 'Edit' : <><Plus size={16} /> Add Form</>}
            </button>
          </div>
          <div className="p-4">
            {form ? (
              <div>
                <p className="font-medium">{form.title}</p>
                {form.description && (
                  <p className="text-sm text-gray-500">{form.description}</p>
                )}
                <div className="mt-4 space-y-2">
                  {form.schema.fields.map((field: FormField, index: number) => (
                    <div key={index} className="text-sm flex items-center gap-2">
                      <span className="bg-gray-100 px-2 py-0.5 rounded text-xs">
                        {field.type}
                      </span>
                      <span>{field.label}</span>
                      {field.required && (
                        <span className="text-red-500 text-xs">required</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <p className="text-gray-500 text-center">
                No form configured. Users will only confirm their presence.
              </p>
            )}
          </div>
        </div>
      </div>

      {/* Check-in Responses */}
      <div className="bg-white rounded-lg shadow mt-6">
        <div className="p-4 border-b flex justify-between items-center">
          <div className="flex items-center gap-2">
            <ClipboardList size={20} className="text-orange-600" />
            <h2 className="font-semibold">Check-in Responses ({checkins.length})</h2>
          </div>
        </div>

        {/* Group By controls */}
        {groupableFields.length > 0 && checkins.length > 0 && (
          <div className="p-4 border-b bg-gray-50">
            <div className="flex items-center gap-3 flex-wrap">
              <span className="text-sm font-medium text-gray-600">Group by:</span>
              {groupableFields.map((field) => (
                <button
                  key={field.id}
                  onClick={() => toggleGroupByField(field.id)}
                  className={`text-sm px-3 py-1 rounded-full border transition-colors ${
                    groupByFields.includes(field.id)
                      ? 'bg-blue-600 text-white border-blue-600'
                      : 'bg-white text-gray-700 border-gray-300 hover:border-gray-400'
                  }`}
                >
                  {field.label}
                </button>
              ))}
              {groupByFields.length > 0 && (
                <button
                  onClick={() => setGroupByFields([])}
                  className="text-sm text-gray-500 hover:text-gray-700 underline"
                >
                  Clear
                </button>
              )}
            </div>
          </div>
        )}

        {checkins.length === 0 ? (
          <div className="p-8 text-gray-500 text-center">
            No check-ins yet.
          </div>
        ) : groupedCheckins ? (
          <div className="divide-y">
            {groupedCheckins.map((group) => (
              <div key={group.label}>
                <div className="px-4 py-3 bg-gray-50 border-b">
                  <span className="font-medium">{group.label}</span>
                  <span className="text-sm text-gray-500 ml-2">
                    ({group.checkins.length} {group.checkins.length === 1 ? 'response' : 'responses'})
                  </span>
                </div>
                <CheckinTable checkins={group.checkins} form={form} />
              </div>
            ))}
          </div>
        ) : (
          <CheckinTable checkins={checkins} form={form} />
        )}
      </div>

      {/* Beacon Modal */}
      {showBeaconModal && (
        <BeaconModal
          campaignId={campaign.id}
          onClose={() => setShowBeaconModal(false)}
          onSave={(beacon) => {
            setBeacons([...beacons, beacon])
            setShowBeaconModal(false)
          }}
        />
      )}

      {/* Form Modal */}
      {showFormModal && (
        <FormBuilderModal
          campaignId={campaign.id}
          existingForm={form}
          onClose={() => setShowFormModal(false)}
          onSave={(savedForm) => {
            setForm(savedForm)
            setShowFormModal(false)
          }}
        />
      )}
    </div>
  )
}

function CheckinTable({ checkins, form }: { checkins: Checkin[]; form: FormSchema | null }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b bg-gray-50">
            <th className="text-left p-3 font-medium">Client</th>
            <th className="text-left p-3 font-medium">Email</th>
            <th className="text-left p-3 font-medium">Status</th>
            {form?.schema.fields.map((field) => (
              <th key={field.id} className="text-left p-3 font-medium">
                {field.label}
              </th>
            ))}
            <th className="text-left p-3 font-medium">Checked In</th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {checkins.map((checkin) => (
            <tr key={checkin.id} className="hover:bg-gray-50">
              <td className="p-3">{checkin.client?.name ?? '-'}</td>
              <td className="p-3 text-gray-500">{checkin.client?.email ?? '-'}</td>
              <td className="p-3">
                <span className={`text-xs px-2 py-0.5 rounded ${
                  checkin.status === 'completed'
                    ? 'bg-green-100 text-green-700'
                    : checkin.status === 'confirmed'
                    ? 'bg-blue-100 text-blue-700'
                    : checkin.status === 'expired'
                    ? 'bg-red-100 text-red-700'
                    : 'bg-yellow-100 text-yellow-700'
                }`}>
                  {checkin.status}
                </span>
              </td>
              {form?.schema.fields.map((field) => (
                <td key={field.id} className="p-3">
                  {checkin.form_response
                    ? String(checkin.form_response[field.id] ?? '-')
                    : '-'}
                </td>
              ))}
              <td className="p-3 text-gray-500">
                {checkin.checked_in_at
                  ? format(new Date(checkin.checked_in_at), 'MMM d, yyyy h:mm a')
                  : '-'}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function BeaconModal({
  campaignId,
  onClose,
  onSave,
}: {
  campaignId: string
  onClose: () => void
  onSave: (beacon: Beacon) => void
}) {
  const [name, setName] = useState('')
  const [uuid, setUuid] = useState('')
  const [major, setMajor] = useState('')
  const [minor, setMinor] = useState('')
  const [location, setLocation] = useState('')
  const [saving, setSaving] = useState(false)

  const isValid = () => {
    return !!name && !!uuid
  }

  const handleSave = async () => {
    if (!isValid()) return
    setSaving(true)

    try {
      const beaconData = {
        campaign_id: campaignId,
        name,
        beacon_uuid: uuid,
        major: major ? parseInt(major) : null,
        minor: minor ? parseInt(minor) : null,
        location_description: location || null,
      }

      const { data, error } = await supabase
        .from('beacons')
        .insert(beaconData)
        .select()
        .single()

      if (error) throw error
      onSave(data)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to save beacon')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-lg w-full max-w-md">
        <div className="p-4 border-b">
          <h3 className="font-semibold">Add iBeacon</h3>
        </div>
        <div className="p-4 space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Name *</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 border rounded-md"
              placeholder="e.g., Front Entrance"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Beacon UUID *</label>
            <input
              type="text"
              value={uuid}
              onChange={(e) => setUuid(e.target.value)}
              className="w-full px-3 py-2 border rounded-md font-mono text-sm"
              placeholder="e.g., 550e8400-e29b-41d4-a716-446655440000"
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Major</label>
              <input
                type="number"
                value={major}
                onChange={(e) => setMajor(e.target.value)}
                className="w-full px-3 py-2 border rounded-md"
                placeholder="0-65535"
                min={0}
                max={65535}
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Minor</label>
              <input
                type="number"
                value={minor}
                onChange={(e) => setMinor(e.target.value)}
                className="w-full px-3 py-2 border rounded-md"
                placeholder="0-65535"
                min={0}
                max={65535}
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Location Description</label>
            <input
              type="text"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
              className="w-full px-3 py-2 border rounded-md"
              placeholder="e.g., Near the main door"
            />
          </div>
        </div>
        <div className="p-4 border-t flex gap-2 justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 border rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !isValid()}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  )
}

function FormBuilderModal({
  campaignId,
  existingForm,
  onClose,
  onSave,
}: {
  campaignId: string
  existingForm: FormSchema | null
  onClose: () => void
  onSave: (form: FormSchema) => void
}) {
  const [title, setTitle] = useState(existingForm?.title || '')
  const [description, setDescription] = useState(existingForm?.description || '')
  const [fields, setFields] = useState<FormField[]>(existingForm?.schema.fields || [])
  const [saving, setSaving] = useState(false)

  const addField = () => {
    setFields([
      ...fields,
      {
        id: `field_${Date.now()}`,
        type: 'text',
        label: '',
        required: false,
      },
    ])
  }

  const updateField = (index: number, updates: Partial<FormField>) => {
    setFields(fields.map((f, i) => (i === index ? { ...f, ...updates } : f)))
  }

  const removeField = (index: number) => {
    setFields(fields.filter((_, i) => i !== index))
  }

  const handleSave = async () => {
    if (!title) return
    setSaving(true)

    try {
      const formData = {
        campaign_id: campaignId,
        title,
        description: description || null,
        schema: { fields },
      }

      let result
      if (existingForm) {
        result = await supabase
          .from('forms')
          .update(formData)
          .eq('id', existingForm.id)
          .select()
          .single()
      } else {
        result = await supabase.from('forms').insert(formData).select().single()
      }

      if (result.error) throw result.error
      onSave(result.data)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to save form')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-lg w-full max-w-2xl max-h-[90vh] overflow-auto">
        <div className="p-4 border-b">
          <h3 className="font-semibold">{existingForm ? 'Edit Form' : 'Create Form'}</h3>
        </div>
        <div className="p-4 space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Form Title *</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-3 py-2 border rounded-md"
              placeholder="e.g., Purpose of Visit"
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Description</label>
            <input
              type="text"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full px-3 py-2 border rounded-md"
              placeholder="Instructions for the user..."
            />
          </div>

          <div>
            <div className="flex justify-between items-center mb-2">
              <label className="block text-sm font-medium">Fields</label>
              <button
                onClick={addField}
                className="text-sm text-blue-600 hover:underline flex items-center gap-1"
              >
                <Plus size={16} /> Add Field
              </button>
            </div>

            {fields.length === 0 ? (
              <p className="text-gray-500 text-sm text-center py-4">
                No fields yet. Add fields to create your form.
              </p>
            ) : (
              <div className="space-y-3">
                {fields.map((field, index) => (
                  <div key={field.id} className="border rounded-md p-3">
                    <div className="flex gap-2 mb-2">
                      <select
                        value={field.type}
                        onChange={(e) =>
                          updateField(index, { type: e.target.value as FormField['type'] })
                        }
                        className="px-2 py-1 border rounded text-sm"
                      >
                        <option value="text">Text</option>
                        <option value="textarea">Text Area</option>
                        <option value="number">Number</option>
                        <option value="select">Dropdown</option>
                        <option value="checkbox">Checkbox</option>
                      </select>
                      <input
                        type="text"
                        value={field.label}
                        onChange={(e) => updateField(index, { label: e.target.value })}
                        className="flex-1 px-2 py-1 border rounded text-sm"
                        placeholder="Field label"
                      />
                      <label className="flex items-center gap-1 text-sm">
                        <input
                          type="checkbox"
                          checked={field.required}
                          onChange={(e) => updateField(index, { required: e.target.checked })}
                        />
                        Required
                      </label>
                      <button
                        onClick={() => removeField(index)}
                        className="text-red-500 hover:text-red-700"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                    {field.type === 'select' && (
                      <input
                        type="text"
                        value={field.options?.join(', ') || ''}
                        onChange={(e) =>
                          updateField(index, {
                            options: e.target.value.split(',').map((o) => o.trim()),
                          })
                        }
                        className="w-full px-2 py-1 border rounded text-sm mt-2"
                        placeholder="Options (comma-separated): Option 1, Option 2, Option 3"
                      />
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
        <div className="p-4 border-t flex gap-2 justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 border rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !title}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  )
}
