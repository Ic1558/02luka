import { NavLink } from 'react-router-dom'
import {
  FiHome,
  FiFolder,
  FiCheckSquare,
  FiUsers,
  FiPackage,
  FiFile,
  FiCalendar,
  FiBarChart2,
  FiSettings,
  FiX,
  FiMap,
  FiEdit3
} from 'react-icons/fi'

const Sidebar = ({ mobile, onClose }) => {
  const navItems = [
    { name: 'Dashboard', icon: FiHome, path: '/dashboard' },
    { name: 'Contexts', icon: FiMap, path: '/contexts', badge: 'NEW' },
    { name: 'Sketches', icon: FiEdit3, path: '/sketches', badge: 'NEW' },
    { name: 'Projects', icon: FiFolder, path: '/projects' },
    { name: 'Tasks', icon: FiCheckSquare, path: '/tasks' },
    { name: 'Team', icon: FiUsers, path: '/team' },
    { name: 'Materials', icon: FiPackage, path: '/materials' },
    { name: 'Documents', icon: FiFile, path: '/documents' },
    { name: 'Calendar', icon: FiCalendar, path: '/calendar' },
    { name: 'Reports', icon: FiBarChart2, path: '/reports' },
    { name: 'Settings', icon: FiSettings, path: '/settings' },
  ]

  return (
    <div className={`${mobile ? 'h-full' : 'fixed inset-y-0 left-0'} w-64 bg-white shadow-xl z-50`}>
      <div className="flex flex-col h-full">
        {/* Logo */}
        <div className="flex items-center justify-between p-6 border-b">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-gradient-to-br from-primary-600 to-accent-600 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-xl">PB</span>
            </div>
            <div>
              <h1 className="text-xl font-display font-bold text-gradient">ProBuild</h1>
              <p className="text-xs text-gray-500">Smart Projects</p>
            </div>
          </div>
          {mobile && (
            <button onClick={onClose} className="lg:hidden p-2 hover:bg-gray-100 rounded-lg">
              <FiX className="w-5 h-5" />
            </button>
          )}
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4 space-y-2 custom-scrollbar overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              onClick={mobile ? onClose : undefined}
              className={({ isActive }) =>
                `flex items-center space-x-3 px-4 py-3 rounded-lg transition-all ${
                  isActive
                    ? 'bg-primary-50 text-primary-700 font-medium'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                }`
              }
            >
              <item.icon className="w-5 h-5" />
              <span className="flex-1">{item.name}</span>
              {item.badge && (
                <span className="badge badge-primary text-xs">{item.badge}</span>
              )}
            </NavLink>
          ))}
        </nav>

        {/* User info at bottom */}
        <div className="p-4 border-t">
          <div className="flex items-center space-x-3 p-3 rounded-lg bg-gray-50">
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-400 to-accent-400 flex items-center justify-center text-white font-semibold">
              JD
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">John Doe</p>
              <p className="text-xs text-gray-500 truncate">Architect</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Sidebar
