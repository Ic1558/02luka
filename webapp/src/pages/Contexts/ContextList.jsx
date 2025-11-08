import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  FiPlus, FiMapPin, FiGrid, FiFileText, FiTrendingUp,
  FiMap, FiLayers
} from 'react-icons/fi'
import axios from 'axios'
import { toast } from 'react-toastify'

const ContextList = () => {
  const navigate = useNavigate()
  const [contexts, setContexts] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchContexts()
  }, [])

  const fetchContexts = async () => {
    try {
      const response = await axios.get('/api/contexts')
      setContexts(response.data.data || [])
    } catch (error) {
      toast.error('Failed to load contexts')
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-600">Loading contexts...</div>
      </div>
    )
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
        <div>
          <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">
            Design Contexts
          </h1>
          <p className="text-gray-600 mt-1">
            Site analysis, zoning, and environmental context for your projects
          </p>
        </div>

        <button
          onClick={() => navigate('/contexts/new')}
          className="btn-primary flex items-center justify-center space-x-2"
        >
          <FiPlus className="w-5 h-5" />
          <span>New Context</span>
        </button>
      </div>

      {/* Context Cards Grid */}
      {contexts.length === 0 ? (
        <div className="card text-center py-12">
          <div className="flex justify-center mb-4">
            <div className="w-16 h-16 rounded-full bg-primary-100 flex items-center justify-center">
              <FiMap className="w-8 h-8 text-primary-600" />
            </div>
          </div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">No Contexts Yet</h3>
          <p className="text-gray-600 mb-6 max-w-md mx-auto">
            Start by creating a design context with site information, zoning data, and environmental factors
          </p>
          <button
            onClick={() => navigate('/contexts/new')}
            className="btn-primary inline-flex items-center space-x-2"
          >
            <FiPlus className="w-5 h-5" />
            <span>Create First Context</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {contexts.map((context) => (
            <div
              key={context.id}
              onClick={() => navigate(`/contexts/${context.id}`)}
              className="card cursor-pointer hover:shadow-lg transition-all group"
            >
              {/* Header */}
              <div className="flex items-start justify-between mb-4">
                <div className="flex-1">
                  <h3 className="font-semibold text-lg text-gray-900 group-hover:text-primary-600 transition">
                    {context.name}
                  </h3>
                  {context.site_name && (
                    <p className="text-sm text-gray-500 mt-1">{context.site_name}</p>
                  )}
                </div>
                <div className="w-10 h-10 rounded-lg bg-primary-100 flex items-center justify-center">
                  <FiMapPin className="w-5 h-5 text-primary-600" />
                </div>
              </div>

              {/* Location */}
              <div className="flex items-start space-x-2 text-sm text-gray-600 mb-3">
                <FiMapPin className="w-4 h-4 mt-0.5 flex-shrink-0" />
                <span className="line-clamp-2">
                  {context.address || `${context.city}, ${context.state}`}
                </span>
              </div>

              {/* Key Metrics */}
              <div className="grid grid-cols-2 gap-3 mb-4">
                {context.zoning_code && (
                  <div className="flex items-center space-x-2">
                    <FiFileText className="w-4 h-4 text-gray-400" />
                    <div>
                      <p className="text-xs text-gray-500">Zoning</p>
                      <p className="text-sm font-medium text-gray-900">{context.zoning_code}</p>
                    </div>
                  </div>
                )}
                {context.lot_size && (
                  <div className="flex items-center space-x-2">
                    <FiGrid className="w-4 h-4 text-gray-400" />
                    <div>
                      <p className="text-xs text-gray-500">Lot Size</p>
                      <p className="text-sm font-medium text-gray-900">
                        {context.lot_size.toLocaleString()} {context.lot_size_unit}
                      </p>
                    </div>
                  </div>
                )}
                {context.floor_area_ratio && (
                  <div className="flex items-center space-x-2">
                    <FiTrendingUp className="w-4 h-4 text-gray-400" />
                    <div>
                      <p className="text-xs text-gray-500">FAR</p>
                      <p className="text-sm font-medium text-gray-900">{context.floor_area_ratio}</p>
                    </div>
                  </div>
                )}
                {context.topography && (
                  <div className="flex items-center space-x-2">
                    <FiLayers className="w-4 h-4 text-gray-400" />
                    <div>
                      <p className="text-xs text-gray-500">Topography</p>
                      <p className="text-sm font-medium text-gray-900">{context.topography}</p>
                    </div>
                  </div>
                )}
              </div>

              {/* Description */}
              {context.description && (
                <p className="text-sm text-gray-600 line-clamp-2 mb-3">
                  {context.description}
                </p>
              )}

              {/* Footer */}
              <div className="pt-3 border-t flex items-center justify-between text-xs text-gray-500">
                <span>Created {new Date(context.created_at).toLocaleDateString()}</span>
                <div className="flex items-center space-x-3">
                  {context.images?.length > 0 && (
                    <span>{context.images.length} photos</span>
                  )}
                  {context.files?.length > 0 && (
                    <span>{context.files.length} files</span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default ContextList
