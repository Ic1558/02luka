import { FiFolder, FiCheckSquare, FiUsers, FiDollarSign, FiTrendingUp, FiAlertCircle } from 'react-icons/fi'
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

const Dashboard = () => {
  const stats = [
    { name: 'Active Projects', value: '12', icon: FiFolder, color: 'primary', trend: '+2' },
    { name: 'Pending Tasks', value: '47', icon: FiCheckSquare, color: 'orange', trend: '-5' },
    { name: 'Team Members', value: '28', icon: FiUsers, color: 'green', trend: '+3' },
    { name: 'Budget Used', value: '68%', icon: FiDollarSign, color: 'purple', trend: '+12%' },
  ]

  const projectData = [
    { name: 'Jan', projects: 4, completed: 2 },
    { name: 'Feb', projects: 6, completed: 3 },
    { name: 'Mar', projects: 8, completed: 5 },
    { name: 'Apr', projects: 12, completed: 7 },
    { name: 'May', projects: 10, completed: 8 },
    { name: 'Jun', projects: 14, completed: 10 },
  ]

  const recentProjects = [
    { id: 1, name: 'Modern Villa - Phase 2', status: 'construction', progress: 65, client: 'Johnson Family' },
    { id: 2, name: 'Office Renovation', status: 'design', progress: 30, client: 'TechCorp Inc' },
    { id: 3, name: 'Residential Complex', status: 'planning', progress: 15, client: 'Real Estate Group' },
  ]

  const alerts = [
    { id: 1, type: 'weather', message: 'Heavy rain expected tomorrow - Construction delay possible', severity: 'warning' },
    { id: 2, type: 'budget', message: 'Modern Villa project approaching budget limit (85%)', severity: 'danger' },
    { id: 3, type: 'deadline', message: '3 tasks due today for Office Renovation', severity: 'info' },
  ]

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-600 mt-1">Welcome back! Here's what's happening with your projects.</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <div key={stat.name} className="card">
            <div className="flex items-start justify-between">
              <div className={`w-12 h-12 rounded-lg bg-${stat.color}-100 flex items-center justify-center`}>
                <stat.icon className={`w-6 h-6 text-${stat.color}-600`} />
              </div>
              <div className={`flex items-center space-x-1 text-sm ${stat.trend.startsWith('+') ? 'text-green-600' : 'text-red-600'}`}>
                <FiTrendingUp className="w-4 h-4" />
                <span className="font-medium">{stat.trend}</span>
              </div>
            </div>
            <div className="mt-4">
              <p className="text-2xl lg:text-3xl font-bold text-gray-900">{stat.value}</p>
              <p className="text-sm text-gray-600 mt-1">{stat.name}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Alerts */}
      {alerts.length > 0 && (
        <div className="space-y-3">
          {alerts.map((alert) => (
            <div
              key={alert.id}
              className={`p-4 rounded-lg border-l-4 ${
                alert.severity === 'danger'
                  ? 'bg-red-50 border-red-500'
                  : alert.severity === 'warning'
                  ? 'bg-yellow-50 border-yellow-500'
                  : 'bg-blue-50 border-blue-500'
              }`}
            >
              <div className="flex items-start space-x-3">
                <FiAlertCircle className={`w-5 h-5 mt-0.5 ${
                  alert.severity === 'danger'
                    ? 'text-red-600'
                    : alert.severity === 'warning'
                    ? 'text-yellow-600'
                    : 'text-blue-600'
                }`} />
                <p className="flex-1 text-sm font-medium text-gray-800">{alert.message}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Project Overview Chart */}
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Project Overview</h3>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={projectData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="projects" fill="#3b82f6" name="Total Projects" />
              <Bar dataKey="completed" fill="#10b981" name="Completed" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Progress Trend */}
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Completion Trend</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={projectData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="completed" stroke="#10b981" strokeWidth={2} name="Completed Projects" />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Recent Projects */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Active Projects</h3>
          <button className="text-primary-600 hover:text-primary-700 font-medium text-sm">View All</button>
        </div>

        <div className="space-y-4">
          {recentProjects.map((project) => (
            <div key={project.id} className="flex flex-col lg:flex-row lg:items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition cursor-pointer">
              <div className="flex-1">
                <h4 className="font-medium text-gray-900">{project.name}</h4>
                <p className="text-sm text-gray-600 mt-1">Client: {project.client}</p>
              </div>

              <div className="mt-3 lg:mt-0 lg:ml-4 flex items-center space-x-4">
                <div className="flex-1 lg:w-48">
                  <div className="flex items-center justify-between text-xs text-gray-600 mb-1">
                    <span>Progress</span>
                    <span className="font-medium">{project.progress}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-primary-600 h-2 rounded-full transition-all"
                      style={{ width: `${project.progress}%` }}
                    ></div>
                  </div>
                </div>

                <span className={`badge ${
                  project.status === 'construction'
                    ? 'status-construction'
                    : project.status === 'design'
                    ? 'status-design'
                    : 'status-planning'
                }`}>
                  {project.status}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default Dashboard
