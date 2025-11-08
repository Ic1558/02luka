import { Outlet } from 'react-router-dom'

const AuthLayout = () => {
  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-50 via-white to-accent-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-gradient-to-br from-primary-600 to-accent-600 rounded-2xl mb-4">
            <span className="text-white font-bold text-2xl">PB</span>
          </div>
          <h1 className="text-3xl font-display font-bold text-gradient">ProBuild</h1>
          <p className="text-gray-600 mt-2">Smart Project Management</p>
        </div>

        <Outlet />
      </div>
    </div>
  )
}

export default AuthLayout
