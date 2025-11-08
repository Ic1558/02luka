import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  FiArrowLeft, FiEdit, FiUsers, FiDollarSign, FiCalendar,
  FiCheckSquare, FiFile, FiImage, FiMessageSquare, FiAlertCircle
} from 'react-icons/fi'

const ProjectDetail = () => {
  const { id } = useParams()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState('overview')

  // Mock project data
  const project = {
    id: 1,
    name: 'Modern Villa - Phase 2',
    code: 'PRJ-2024-001',
    type: 'residential',
    status: 'construction',
    progress: 65,
    client: 'Johnson Family',
    location: 'Beverly Hills, CA',
    budget: 850000,
    spent: 552500,
    startDate: '2024-01-15',
    endDate: '2024-08-30',
    description: 'Luxury modern villa with sustainable design features, smart home integration, and contemporary architecture.',
    team: [
      { id: 1, name: 'John Architect', role: 'Lead Architect', avatar: 'JA' },
      { id: 2, name: 'Sarah Designer', role: 'Interior Designer', avatar: 'SD' },
      { id: 3, name: 'Mike Contractor', role: 'Project Manager', avatar: 'MC' },
    ],
    tasks: [
      { id: 1, name: 'Foundation completion', status: 'completed', dueDate: '2024-02-15' },
      { id: 2, name: 'Structural framing', status: 'completed', dueDate: '2024-03-20' },
      { id: 3, name: 'Electrical installation', status: 'in_progress', dueDate: '2024-05-10' },
      { id: 4, name: 'Interior finishing', status: 'pending', dueDate: '2024-07-15' },
    ],
    milestones: [
      { name: 'Foundation', date: '2024-02-15', status: 'completed' },
      { name: 'Structure', date: '2024-04-30', status: 'completed' },
      { name: 'MEP Installation', date: '2024-06-15', status: 'in_progress' },
      { name: 'Finishing', date: '2024-08-30', status: 'pending' },
    ],
    recentActivity: [
      { id: 1, user: 'Mike Contractor', action: 'uploaded new progress photos', time: '2 hours ago' },
      { id: 2, user: 'Sarah Designer', action: 'completed task: Material selection', time: '5 hours ago' },
      { id: 3, user: 'John Architect', action: 'updated project timeline', time: '1 day ago' },
    ]
  }

  const tabs = [
    { id: 'overview', name: 'Overview', icon: FiCheckSquare },
    { id: 'tasks', name: 'Tasks', icon: FiCheckSquare },
    { id: 'team', name: 'Team', icon: FiUsers },
    { id: 'files', name: 'Files', icon: FiFile },
    { id: 'photos', name: 'Photos', icon: FiImage },
    { id: 'activity', name: 'Activity', icon: FiMessageSquare },
  ]

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <button
            onClick={() => navigate('/projects')}
            className="flex items-center space-x-2 text-gray-600 hover:text-gray-900 mb-4"
          >
            <FiArrowLeft className="w-5 h-5" />
            <span>Back to Projects</span>
          </button>

          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="flex items-center space-x-3">
                <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">
                  {project.name}
                </h1>
                <span className={`badge ${
                  project.status === 'construction' ? 'status-construction' : 'status-planning'
                }`}>
                  {project.status}
                </span>
              </div>
              <p className="text-gray-600 mt-1">{project.code} • {project.client}</p>
            </div>

            <button className="btn-primary mt-4 lg:mt-0 flex items-center space-x-2">
              <FiEdit className="w-5 h-5" />
              <span>Edit Project</span>
            </button>
          </div>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="card">
          <div className="flex items-center space-x-3 text-primary-600">
            <FiCheckSquare className="w-6 h-6" />
            <span className="text-sm font-medium">Progress</span>
          </div>
          <p className="text-2xl font-bold text-gray-900 mt-2">{project.progress}%</p>
          <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
            <div
              className="bg-primary-600 h-2 rounded-full"
              style={{ width: `${project.progress}%` }}
            ></div>
          </div>
        </div>

        <div className="card">
          <div className="flex items-center space-x-3 text-green-600">
            <FiDollarSign className="w-6 h-6" />
            <span className="text-sm font-medium">Budget</span>
          </div>
          <p className="text-2xl font-bold text-gray-900 mt-2">
            ${(project.budget / 1000).toFixed(0)}K
          </p>
          <p className="text-sm text-gray-600 mt-1">
            ${(project.spent / 1000).toFixed(0)}K spent ({((project.spent / project.budget) * 100).toFixed(0)}%)
          </p>
        </div>

        <div className="card">
          <div className="flex items-center space-x-3 text-orange-600">
            <FiCalendar className="w-6 h-6" />
            <span className="text-sm font-medium">Timeline</span>
          </div>
          <p className="text-lg font-bold text-gray-900 mt-2">
            {new Date(project.endDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
          </p>
          <p className="text-sm text-gray-600 mt-1">Due date</p>
        </div>

        <div className="card">
          <div className="flex items-center space-x-3 text-purple-600">
            <FiUsers className="w-6 h-6" />
            <span className="text-sm font-medium">Team</span>
          </div>
          <p className="text-2xl font-bold text-gray-900 mt-2">{project.team.length}</p>
          <p className="text-sm text-gray-600 mt-1">Active members</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200 overflow-x-auto">
        <div className="flex space-x-6">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center space-x-2 pb-3 px-1 border-b-2 font-medium text-sm whitespace-nowrap transition ${
                activeTab === tab.id
                  ? 'border-primary-600 text-primary-600'
                  : 'border-transparent text-gray-600 hover:text-gray-900'
              }`}
            >
              <tab.icon className="w-5 h-5" />
              <span>{tab.name}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div>
        {activeTab === 'overview' && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Main Content */}
            <div className="lg:col-span-2 space-y-6">
              {/* Description */}
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Project Description</h3>
                <p className="text-gray-600">{project.description}</p>
              </div>

              {/* Milestones */}
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Milestones</h3>
                <div className="space-y-4">
                  {project.milestones.map((milestone, index) => (
                    <div key={index} className="flex items-center space-x-4">
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                        milestone.status === 'completed'
                          ? 'bg-green-100 text-green-600'
                          : milestone.status === 'in_progress'
                          ? 'bg-orange-100 text-orange-600'
                          : 'bg-gray-100 text-gray-400'
                      }`}>
                        {milestone.status === 'completed' ? '✓' : index + 1}
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center justify-between">
                          <h4 className="font-medium text-gray-900">{milestone.name}</h4>
                          <span className={`badge ${
                            milestone.status === 'completed'
                              ? 'badge-success'
                              : milestone.status === 'in_progress'
                              ? 'badge-warning'
                              : 'badge-gray'
                          }`}>
                            {milestone.status}
                          </span>
                        </div>
                        <p className="text-sm text-gray-500 mt-1">
                          {new Date(milestone.date).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Recent Tasks */}
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Tasks</h3>
                <div className="space-y-3">
                  {project.tasks.map((task) => (
                    <div key={task.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <input
                          type="checkbox"
                          checked={task.status === 'completed'}
                          className="w-5 h-5 text-primary-600 rounded"
                          readOnly
                        />
                        <div>
                          <p className={`font-medium ${task.status === 'completed' ? 'line-through text-gray-500' : 'text-gray-900'}`}>
                            {task.name}
                          </p>
                          <p className="text-sm text-gray-500">Due: {new Date(task.dueDate).toLocaleDateString()}</p>
                        </div>
                      </div>
                      <span className={`badge ${
                        task.status === 'completed'
                          ? 'badge-success'
                          : task.status === 'in_progress'
                          ? 'badge-warning'
                          : 'badge-gray'
                      }`}>
                        {task.status}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Sidebar */}
            <div className="space-y-6">
              {/* Team Members */}
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Team Members</h3>
                <div className="space-y-3">
                  {project.team.map((member) => (
                    <div key={member.id} className="flex items-center space-x-3">
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary-400 to-accent-400 flex items-center justify-center text-white font-semibold">
                        {member.avatar}
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">{member.name}</p>
                        <p className="text-sm text-gray-500">{member.role}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Recent Activity */}
              <div className="card">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h3>
                <div className="space-y-4">
                  {project.recentActivity.map((activity) => (
                    <div key={activity.id} className="flex space-x-3">
                      <div className="w-2 h-2 mt-2 rounded-full bg-primary-600"></div>
                      <div className="flex-1">
                        <p className="text-sm text-gray-900">
                          <span className="font-medium">{activity.user}</span>{' '}
                          {activity.action}
                        </p>
                        <p className="text-xs text-gray-500 mt-1">{activity.time}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'tasks' && (
          <div className="card">
            <p className="text-gray-600">Tasks management view coming soon...</p>
          </div>
        )}

        {activeTab === 'team' && (
          <div className="card">
            <p className="text-gray-600">Team management view coming soon...</p>
          </div>
        )}

        {activeTab === 'files' && (
          <div className="card">
            <p className="text-gray-600">File management view coming soon...</p>
          </div>
        )}

        {activeTab === 'photos' && (
          <div className="card">
            <p className="text-gray-600">Photo gallery coming soon...</p>
          </div>
        )}

        {activeTab === 'activity' && (
          <div className="card">
            <p className="text-gray-600">Activity feed coming soon...</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default ProjectDetail
