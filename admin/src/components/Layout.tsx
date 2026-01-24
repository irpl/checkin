import { Outlet, Link, useLocation } from 'react-router-dom'
import { useAuthStore } from '../stores/auth'
import { LayoutDashboard, Megaphone, ClipboardCheck, LogOut } from 'lucide-react'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/campaigns', label: 'Campaigns', icon: Megaphone },
  { to: '/checkins', label: 'Check-ins', icon: ClipboardCheck },
]

export default function Layout() {
  const location = useLocation()
  const { signOut } = useAuthStore()

  return (
    <div className="min-h-screen flex">
      {/* Sidebar */}
      <aside className="w-64 bg-gray-900 text-white">
        <div className="p-6">
          <h1 className="text-xl font-bold">Checkin Admin</h1>
        </div>
        <nav className="mt-6">
          {navItems.map((item) => {
            const isActive = location.pathname === item.to ||
              (item.to !== '/' && location.pathname.startsWith(item.to))
            return (
              <Link
                key={item.to}
                to={item.to}
                className={`flex items-center gap-3 px-6 py-3 text-sm transition-colors ${
                  isActive
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-300 hover:bg-gray-800'
                }`}
              >
                <item.icon size={20} />
                {item.label}
              </Link>
            )
          })}
        </nav>
        <div className="absolute bottom-0 w-64 p-4">
          <button
            onClick={signOut}
            className="flex items-center gap-3 px-6 py-3 text-sm text-gray-300 hover:bg-gray-800 w-full rounded"
          >
            <LogOut size={20} />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="p-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
