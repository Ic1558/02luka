import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { FiPlus, FiFilter, FiGrid, FiList, FiMapPin, FiCalendar, FiDollarSign } from 'react-icons/fi'

const Projects = () => {
  const navigate = useNavigate()
  const [viewMode, setViewMode] = useState('grid') // 'grid' or 'list'
  const [filterStatus, setFilterStatus] = useState('all')

  const projects = [
    {
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
      team: 12,
      image: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400'
    },
    {
      id: 2,
      name: 'Office Renovation',
      code: 'PRJ-2024-002',
      type: 'commercial',
      status: 'design',
      progress: 30,
      client: 'TechCorp Inc',
      location: 'Downtown LA',
      budget: 450000,
      spent: 135000,
      startDate: '2024-02-01',
      endDate: '2024-07-15',
      team: 8,
      image: 'https://images.unsplash.com/photo-1497366216548-37526070297c?w=400'
    },
    {
      id: 3,
      name: 'Residential Complex',
      code: 'PRJ-2024-003',
      type: 'residential',
      status: 'planning',
      progress: 15,
      client: 'Real Estate Group',
      location: 'Santa Monica, CA',
      budget: 2500000,
      spent: 375000,
      startDate: '2024-03-01',
      endDate: '2025-02-28',
      team: 20,
      image: 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400'
    },
    {
      id: 4,
      name: 'Boutique Hotel Interior',
      code: 'PRJ-2024-004',
      type: 'interior',
      status: 'construction',
      progress: 80,
      client: 'Luxury Hospitality',
      location: 'Malibu, CA',
      budget: 680000,
      spent: 544000,
      startDate: '2023-11-01',
      endDate: '2024-05-30',
      team: 15,
      image: 'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=400'
    },
  ]

  const filteredProjects = filterStatus === 'all'
    ? projects
    : projects.filter(p => p.status === filterStatus)

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
        <div>
          <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">Projects</h1>
          <p className="text-gray-600 mt-1">Manage all your architecture and construction projects</p>
        </div>

        <button className="btn-primary flex items-center justify-center space-x-2">
          <FiPlus className="w-5 h-5" />
          <span>New Project</span>
        </button>
      </div>

      {/* Filters and View Toggle */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-4 sm:space-y-0">
        {/* Filter Tabs */}
        <div className="flex items-center space-x-2 overflow-x-auto pb-2 sm:pb-0">
          {['all', 'planning', 'design', 'construction', 'completed'].map((status) => (
            <button
              key={status}
              onClick={() => setFilterStatus(status)}
              className={`px-4 py-2 rounded-lg font-medium text-sm whitespace-nowrap transition ${
                filterStatus === status
                  ? 'bg-primary-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {status.charAt(0).toUpperCase() + status.slice(1)}
            </button>
          ))}
        </div>

        {/* View Toggle */}
        <div className="flex items-center space-x-2">
          <button className="btn-secondary">
            <FiFilter className="w-5 h-5" />
          </button>
          <div className="flex bg-gray-100 rounded-lg p-1">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-2 rounded transition ${
                viewMode === 'grid'
                  ? 'bg-white shadow-sm'
                  : 'text-gray-500'
              }`}
            >
              <FiGrid className="w-5 h-5" />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`p-2 rounded transition ${
                viewMode === 'list'
                  ? 'bg-white shadow-sm'
                  : 'text-gray-500'
              }`}
            >
              <FiList className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Projects Grid/List */}
      {viewMode === 'grid' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {filteredProjects.map((project) => (
            <div
              key={project.id}
              onClick={() => navigate(`/projects/${project.id}`)}
              className="card cursor-pointer hover:shadow-lg transition-all group"
            >
              {/* Project Image */}
              <div className="relative h-48 -mx-6 -mt-6 mb-4 rounded-t-lg overflow-hidden">
                <img
                  src={project.image}
                  alt={project.name}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                />
                <div className="absolute top-3 right-3">
                  <span className={`badge ${
                    project.status === 'construction'
                      ? 'status-construction'
                      : project.status === 'design'
                      ? 'status-design'
                      : project.status === 'completed'
                      ? 'status-completed'
                      : 'status-planning'
                  }`}>
                    {project.status}
                  </span>
                </div>
              </div>

              {/* Project Info */}
              <div className="space-y-3">
                <div>
                  <h3 className="font-semibold text-lg text-gray-900 group-hover:text-primary-600 transition">
                    {project.name}
                  </h3>
                  <p className="text-sm text-gray-500">{project.code}</p>
                </div>

                <div className="flex items-center text-sm text-gray-600 space-x-2">
                  <FiMapPin className="w-4 h-4" />
                  <span>{project.location}</span>
                </div>

                {/* Progress Bar */}
                <div>
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

                {/* Budget */}
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center text-gray-600 space-x-1">
                    <FiDollarSign className="w-4 h-4" />
                    <span>Budget:</span>
                  </div>
                  <span className="font-medium">${(project.budget / 1000).toFixed(0)}K</span>
                </div>

                {/* Team */}
                <div className="flex items-center justify-between pt-3 border-t">
                  <div className="flex -space-x-2">
                    {[1, 2, 3].map((i) => (
                      <div
                        key={i}
                        className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-400 to-accent-400 border-2 border-white flex items-center justify-center text-white text-xs font-semibold"
                      >
                        {i}
                      </div>
                    ))}
                    {project.team > 3 && (
                      <div className="w-8 h-8 rounded-full bg-gray-300 border-2 border-white flex items-center justify-center text-gray-700 text-xs font-semibold">
                        +{project.team - 3}
                      </div>
                    )}
                  </div>
                  <span className="text-xs text-gray-500">{project.team} members</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card divide-y">
          {filteredProjects.map((project) => (
            <div
              key={project.id}
              onClick={() => navigate(`/projects/${project.id}`)}
              className="flex flex-col lg:flex-row lg:items-center justify-between p-4 hover:bg-gray-50 transition cursor-pointer"
            >
              <div className="flex items-start space-x-4 flex-1">
                <img
                  src={project.image}
                  alt={project.name}
                  className="w-20 h-20 rounded-lg object-cover"
                />
                <div className="flex-1">
                  <div className="flex items-start justify-between">
                    <div>
                      <h3 className="font-semibold text-gray-900">{project.name}</h3>
                      <p className="text-sm text-gray-500">{project.code} • {project.client}</p>
                    </div>
                    <span className={`badge ml-4 ${
                      project.status === 'construction'
                        ? 'status-construction'
                        : project.status === 'design'
                        ? 'status-design'
                        : project.status === 'completed'
                        ? 'status-completed'
                        : 'status-planning'
                    }`}>
                      {project.status}
                    </span>
                  </div>

                  <div className="flex items-center space-x-6 mt-3 text-sm text-gray-600">
                    <div className="flex items-center space-x-1">
                      <FiMapPin className="w-4 h-4" />
                      <span>{project.location}</span>
                    </div>
                    <div className="flex items-center space-x-1">
                      <FiCalendar className="w-4 h-4" />
                      <span>{new Date(project.startDate).toLocaleDateString()}</span>
                    </div>
                    <div className="flex items-center space-x-1">
                      <FiDollarSign className="w-4 h-4" />
                      <span>${(project.budget / 1000).toFixed(0)}K</span>
                    </div>
                  </div>

                  <div className="mt-3 w-full lg:w-64">
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
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default Projects
