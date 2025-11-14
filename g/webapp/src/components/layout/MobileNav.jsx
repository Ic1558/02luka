import { NavLink } from 'react-router-dom'
import { FiHome, FiFolder, FiCheckSquare, FiUsers, FiMenu } from 'react-icons/fi'

const MobileNav = () => {
  const navItems = [
    { name: 'Home', icon: FiHome, path: '/dashboard' },
    { name: 'Projects', icon: FiFolder, path: '/projects' },
    { name: 'Tasks', icon: FiCheckSquare, path: '/tasks' },
    { name: 'Team', icon: FiUsers, path: '/team' },
    { name: 'More', icon: FiMenu, path: '/settings' },
  ]

  return (
    <nav className="lg:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 z-40">
      <div className="flex items-center justify-around">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `flex flex-col items-center justify-center py-3 px-3 transition-colors ${
                isActive
                  ? 'text-primary-600'
                  : 'text-gray-500'
              }`
            }
          >
            <item.icon className="w-6 h-6 mb-1" />
            <span className="text-xs font-medium">{item.name}</span>
          </NavLink>
        ))}
      </div>
    </nav>
  )
}

export default MobileNav
