import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { Campaign, Checkin } from '../types'
import { Megaphone, Users, CheckCircle } from 'lucide-react'
import { format } from 'date-fns'

export default function DashboardPage() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [recentCheckins, setRecentCheckins] = useState<Checkin[]>([])
  const [stats, setStats] = useState({
    totalCampaigns: 0,
    activeSubscribers: 0,
    todayCheckins: 0,
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    try {
      // Load campaigns
      const { data: campaignsData } = await supabase
        .from('campaigns')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5)

      setCampaigns(campaignsData || [])

      // Load recent check-ins
      const { data: checkinsData } = await supabase
        .from('checkins')
        .select('*, client:clients(name, email)')
        .order('created_at', { ascending: false })
        .limit(10)

      setRecentCheckins(checkinsData || [])

      // Calculate stats
      const { count: totalCampaigns } = await supabase
        .from('campaigns')
        .select('*', { count: 'exact', head: true })

      const { count: activeSubscribers } = await supabase
        .from('subscriptions')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)

      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const { count: todayCheckins } = await supabase
        .from('checkins')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', today.toISOString())

      setStats({
        totalCampaigns: totalCampaigns || 0,
        activeSubscribers: activeSubscribers || 0,
        todayCheckins: todayCheckins || 0,
      })
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Dashboard</h1>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <div className="bg-blue-100 p-3 rounded-full">
              <Megaphone className="text-blue-600" size={24} />
            </div>
            <div>
              <p className="text-sm text-gray-500">Total Campaigns</p>
              <p className="text-2xl font-bold">{stats.totalCampaigns}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <div className="bg-green-100 p-3 rounded-full">
              <Users className="text-green-600" size={24} />
            </div>
            <div>
              <p className="text-sm text-gray-500">Active Subscribers</p>
              <p className="text-2xl font-bold">{stats.activeSubscribers}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <div className="bg-purple-100 p-3 rounded-full">
              <CheckCircle className="text-purple-600" size={24} />
            </div>
            <div>
              <p className="text-sm text-gray-500">Today's Check-ins</p>
              <p className="text-2xl font-bold">{stats.todayCheckins}</p>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Campaigns */}
        <div className="bg-white rounded-lg shadow">
          <div className="p-4 border-b flex justify-between items-center">
            <h2 className="font-semibold">Recent Campaigns</h2>
            <Link to="/campaigns" className="text-blue-600 text-sm hover:underline">
              View all
            </Link>
          </div>
          <div className="divide-y">
            {campaigns.length === 0 ? (
              <div className="p-4 text-gray-500 text-center">
                No campaigns yet.{' '}
                <Link to="/campaigns/new" className="text-blue-600 hover:underline">
                  Create one
                </Link>
              </div>
            ) : (
              campaigns.map((campaign) => (
                <Link
                  key={campaign.id}
                  to={`/campaigns/${campaign.id}`}
                  className="block p-4 hover:bg-gray-50"
                >
                  <div className="flex justify-between items-start">
                    <div>
                      <p className="font-medium">{campaign.name}</p>
                      <p className="text-sm text-gray-500">
                        {campaign.campaign_type === 'instant' ? 'Instant' : 'Duration-based'}
                      </p>
                    </div>
                    <span
                      className={`text-xs px-2 py-1 rounded ${
                        campaign.is_active
                          ? 'bg-green-100 text-green-700'
                          : 'bg-gray-100 text-gray-600'
                      }`}
                    >
                      {campaign.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                </Link>
              ))
            )}
          </div>
        </div>

        {/* Recent Check-ins */}
        <div className="bg-white rounded-lg shadow">
          <div className="p-4 border-b flex justify-between items-center">
            <h2 className="font-semibold">Recent Check-ins</h2>
            <Link to="/checkins" className="text-blue-600 text-sm hover:underline">
              View all
            </Link>
          </div>
          <div className="divide-y">
            {recentCheckins.length === 0 ? (
              <div className="p-4 text-gray-500 text-center">No check-ins yet</div>
            ) : (
              recentCheckins.map((checkin) => (
                <div key={checkin.id} className="p-4">
                  <div className="flex justify-between items-start">
                    <div>
                      <p className="font-medium">
                        {checkin.client?.name || checkin.client?.email || 'Unknown'}
                      </p>
                      <p className="text-sm text-gray-500">
                        {format(new Date(checkin.created_at), 'MMM d, yyyy h:mm a')}
                      </p>
                    </div>
                    <span
                      className={`text-xs px-2 py-1 rounded ${
                        checkin.status === 'completed'
                          ? 'bg-green-100 text-green-700'
                          : checkin.status === 'confirmed'
                          ? 'bg-blue-100 text-blue-700'
                          : checkin.status === 'pending'
                          ? 'bg-yellow-100 text-yellow-700'
                          : 'bg-gray-100 text-gray-600'
                      }`}
                    >
                      {checkin.status}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
