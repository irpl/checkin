import { useEffect, useState, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import { Checkin, Campaign } from '../types'
import { format } from 'date-fns'
import { RefreshCw, Eye } from 'lucide-react'

export default function CheckinsPage() {
  const [checkins, setCheckins] = useState<(Checkin & { campaign?: Campaign })[]>([])
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedCampaign, setSelectedCampaign] = useState<string>('')
  const [selectedStatus, setSelectedStatus] = useState<string>('')
  const [selectedCheckin, setSelectedCheckin] = useState<Checkin | null>(null)

  const loadCheckins = useCallback(async () => {
    setLoading(true)
    try {
      let query = supabase
        .from('checkins')
        .select('*, client:clients(name, email), campaign:campaigns(name)')
        .order('created_at', { ascending: false })
        .limit(100)

      if (selectedCampaign) {
        query = query.eq('campaign_id', selectedCampaign)
      }
      if (selectedStatus) {
        query = query.eq('status', selectedStatus)
      }

      const { data } = await query
      setCheckins(data || [])
    } finally {
      setLoading(false)
    }
  }, [selectedCampaign, selectedStatus])

  useEffect(() => {
    loadCampaigns()
  }, [])

  useEffect(() => {
    loadCheckins()
  }, [loadCheckins])

  const loadCampaigns = async () => {
    const { data } = await supabase
      .from('campaigns')
      .select('*')
      .order('name')
    setCampaigns(data || [])
  }

  // Real-time subscription
  useEffect(() => {
    const channel = supabase
      .channel('checkins-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'checkins' },
        () => {
          loadCheckins()
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [loadCheckins])

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'bg-green-100 text-green-700'
      case 'confirmed':
        return 'bg-blue-100 text-blue-700'
      case 'pending':
        return 'bg-yellow-100 text-yellow-700'
      case 'expired':
        return 'bg-gray-100 text-gray-600'
      default:
        return 'bg-gray-100 text-gray-600'
    }
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Check-ins</h1>
        <button
          onClick={loadCheckins}
          className="flex items-center gap-2 text-gray-600 hover:text-gray-900"
        >
          <RefreshCw size={20} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow p-4 mb-6 flex gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Campaign
          </label>
          <select
            value={selectedCampaign}
            onChange={(e) => setSelectedCampaign(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-md"
          >
            <option value="">All Campaigns</option>
            {campaigns.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Status
          </label>
          <select
            value={selectedStatus}
            onChange={(e) => setSelectedStatus(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-md"
          >
            <option value="">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="confirmed">Confirmed</option>
            <option value="completed">Completed</option>
            <option value="expired">Expired</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
          </div>
        ) : checkins.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            No check-ins found
          </div>
        ) : (
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Campaign
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Time
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {checkins.map((checkin) => (
                <tr key={checkin.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div>
                      <p className="font-medium text-gray-900">
                        {checkin.client?.name || 'Unknown'}
                      </p>
                      <p className="text-sm text-gray-500">
                        {checkin.client?.email}
                      </p>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                    {(checkin.campaign as unknown as { name: string })?.name || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span
                      className={`inline-flex px-2 py-1 text-xs font-medium rounded ${getStatusColor(
                        checkin.status
                      )}`}
                    >
                      {checkin.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {format(new Date(checkin.created_at), 'MMM d, yyyy h:mm a')}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
                    {checkin.form_response && (
                      <button
                        onClick={() => setSelectedCheckin(checkin)}
                        className="text-blue-600 hover:underline flex items-center gap-1 ml-auto"
                      >
                        <Eye size={16} />
                        View Response
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Response Modal */}
      {selectedCheckin && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-md">
            <div className="p-4 border-b">
              <h3 className="font-semibold">Form Response</h3>
            </div>
            <div className="p-4">
              <div className="space-y-3">
                {Object.entries(selectedCheckin.form_response || {}).map(
                  ([key, value]) => (
                    <div key={key}>
                      <p className="text-sm text-gray-500">{key}</p>
                      <p className="font-medium">{String(value)}</p>
                    </div>
                  )
                )}
              </div>
            </div>
            <div className="p-4 border-t">
              <button
                onClick={() => setSelectedCheckin(null)}
                className="w-full px-4 py-2 bg-gray-100 rounded-md hover:bg-gray-200"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
