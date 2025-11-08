import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  FiArrowLeft, FiEdit, FiMapPin, FiGrid, FiLayers,
  FiWind, FiSun, FiDroplet, FiAlertTriangle, FiPlus
} from 'react-icons/fi'
import axios from 'axios'
import { toast } from 'react-toastify'
import AIInsights from '../../components/AI/AIInsights'

const ContextDetail = () => {
  const { id } = useParams()
  const navigate = useNavigate()
  const [context, setContext] = useState(null)
  const [overview, setOverview] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchContext()
    fetchOverview()
  }, [id])

  const fetchContext = async () => {
    try {
      const response = await axios.get(`/api/contexts/${id}`)
      setContext(response.data.data)
    } catch (error) {
      toast.error('Failed to load context')
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  const fetchOverview = async () => {
    try {
      const response = await axios.get(`/api/contexts/${id}/overview`)
      setOverview(response.data.data)
    } catch (error) {
      console.error('Failed to load overview:', error)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-600">Loading context...</div>
      </div>
    )
  }

  if (!context) {
    return (
      <div className="card text-center py-12">
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Context Not Found</h3>
        <p className="text-gray-600 mb-6">The context you're looking for doesn't exist</p>
        <button onClick={() => navigate('/contexts')} className="btn-primary">
          Back to Contexts
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <button
          onClick={() => navigate('/contexts')}
          className="flex items-center space-x-2 text-gray-600 hover:text-gray-900 mb-4"
        >
          <FiArrowLeft className="w-5 h-5" />
          <span>Back to Contexts</span>
        </button>

        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">
              {context.name}
            </h1>
            {context.site_name && (
              <p className="text-gray-600 mt-1">{context.site_name}</p>
            )}
          </div>

          <div className="flex items-center space-x-3 mt-4 lg:mt-0">
            <button
              onClick={() => navigate(`/sketches/new?contextId=${context.id}`)}
              className="btn-secondary flex items-center space-x-2"
            >
              <FiPlus className="w-5 h-5" />
              <span>New Sketch</span>
            </button>
            <button
              onClick={() => navigate(`/contexts/${context.id}/edit`)}
              className="btn-primary flex items-center space-x-2"
            >
              <FiEdit className="w-5 h-5" />
              <span>Edit</span>
            </button>
          </div>
        </div>
      </div>

      {/* Quick Stats */}
      {overview && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="card">
            <div className="flex items-center space-x-3 text-primary-600 mb-2">
              <FiGrid className="w-5 h-5" />
              <span className="text-sm font-medium">Lot Size</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {overview.site_data.lot_size}
            </p>
          </div>

          <div className="card">
            <div className="flex items-center space-x-3 text-green-600 mb-2">
              <FiLayers className="w-5 h-5" />
              <span className="text-sm font-medium">Buildable Area</span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {overview.buildable_area.toLocaleString()} sqft
            </p>
          </div>

          <div className="card">
            <div className="flex items-center space-x-3 text-orange-600 mb-2">
              <FiMapPin className="w-5 h-5" />
              <span className="text-sm font-medium">Zoning</span>
            </div>
            <p className="text-xl font-bold text-gray-900">
              {overview.zoning.code}
            </p>
          </div>

          <div className="card">
            <div className="flex items-center space-x-3 text-purple-600 mb-2">
              <FiSun className="w-5 h-5" />
              <span className="text-sm font-medium">Orientation</span>
            </div>
            <p className="text-sm font-bold text-gray-900">
              {overview.site_data.orientation || 'N/A'}
            </p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Content */}
        <div className="lg:col-span-2 space-y-6">
          {/* Location */}
          <div className="card">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center space-x-2">
              <FiMapPin className="w-5 h-5 text-primary-600" />
              <span>Location</span>
            </h3>
            <div className="space-y-3">
              <div>
                <p className="text-sm text-gray-500">Address</p>
                <p className="text-gray-900">{context.address || 'Not specified'}</p>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-gray-500">City</p>
                  <p className="text-gray-900">{context.city || 'N/A'}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-500">State</p>
                  <p className="text-gray-900">{context.state || 'N/A'}</p>
                </div>
              </div>
              {context.latitude && context.longitude && (
                <div>
                  <p className="text-sm text-gray-500">Coordinates</p>
                  <p className="text-gray-900 font-mono text-sm">
                    {context.latitude}, {context.longitude}
                  </p>
                </div>
              )}
            </div>
          </div>

          {/* Zoning & Regulations */}
          <div className="card">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Zoning & Regulations</h3>
            <div className="space-y-4">
              <div>
                <p className="text-sm text-gray-500">Zoning Code</p>
                <p className="text-lg font-medium text-gray-900">{context.zoning_code || 'N/A'}</p>
                {context.zoning_description && (
                  <p className="text-sm text-gray-600 mt-1">{context.zoning_description}</p>
                )}
              </div>

              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                {context.floor_area_ratio && (
                  <div>
                    <p className="text-sm text-gray-500">Floor Area Ratio</p>
                    <p className="text-gray-900 font-semibold">{context.floor_area_ratio}</p>
                  </div>
                )}
                {context.max_height && (
                  <div>
                    <p className="text-sm text-gray-500">Max Height</p>
                    <p className="text-gray-900 font-semibold">
                      {context.max_height} {context.max_height_unit}
                    </p>
                  </div>
                )}
                {context.setback_front && (
                  <div>
                    <p className="text-sm text-gray-500">Front Setback</p>
                    <p className="text-gray-900 font-semibold">{context.setback_front} ft</p>
                  </div>
                )}
                {context.setback_rear && (
                  <div>
                    <p className="text-sm text-gray-500">Rear Setback</p>
                    <p className="text-gray-900 font-semibold">{context.setback_rear} ft</p>
                  </div>
                )}
                {context.setback_side && (
                  <div>
                    <p className="text-sm text-gray-500">Side Setback</p>
                    <p className="text-gray-900 font-semibold">{context.setback_side} ft</p>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Site Characteristics */}
          <div className="card">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Site Characteristics</h3>
            <div className="grid grid-cols-2 gap-4">
              {context.topography && (
                <div className="flex items-start space-x-3">
                  <FiLayers className="w-5 h-5 text-gray-400 mt-0.5" />
                  <div>
                    <p className="text-sm text-gray-500">Topography</p>
                    <p className="text-gray-900">{context.topography}</p>
                  </div>
                </div>
              )}
              {context.soil_type && (
                <div className="flex items-start space-x-3">
                  <FiDroplet className="w-5 h-5 text-gray-400 mt-0.5" />
                  <div>
                    <p className="text-sm text-gray-500">Soil Type</p>
                    <p className="text-gray-900">{context.soil_type}</p>
                  </div>
                </div>
              )}
              {context.solar_orientation && (
                <div className="flex items-start space-x-3">
                  <FiSun className="w-5 h-5 text-gray-400 mt-0.5" />
                  <div>
                    <p className="text-sm text-gray-500">Solar Orientation</p>
                    <p className="text-gray-900">{context.solar_orientation}</p>
                  </div>
                </div>
              )}
              {context.prevailing_wind && (
                <div className="flex items-start space-x-3">
                  <FiWind className="w-5 h-5 text-gray-400 mt-0.5" />
                  <div>
                    <p className="text-sm text-gray-500">Prevailing Wind</p>
                    <p className="text-gray-900">{context.prevailing_wind}</p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Description */}
          {context.description && (
            <div className="card">
              <h3 className="text-lg font-semibold text-gray-900 mb-3">Description</h3>
              <p className="text-gray-600 whitespace-pre-wrap">{context.description}</p>
            </div>
          )}
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* AI Insights */}
          {context && <AIInsights contextData={context} />}

          {/* Environmental Constraints */}
          <div className="card">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center space-x-2">
              <FiAlertTriangle className="w-5 h-5 text-orange-600" />
              <span>Constraints</span>
            </h3>
            <div className="space-y-3">
              {context.flood_zone && (
                <div>
                  <p className="text-sm text-gray-500">Flood Zone</p>
                  <p className="text-gray-900">{context.flood_zone}</p>
                </div>
              )}
              {context.seismic_zone && (
                <div>
                  <p className="text-sm text-gray-500">Seismic Zone</p>
                  <p className="text-gray-900">{context.seismic_zone}</p>
                </div>
              )}
              {context.climate_zone && (
                <div>
                  <p className="text-sm text-gray-500">Climate Zone</p>
                  <p className="text-gray-900">{context.climate_zone}</p>
                </div>
              )}
            </div>
          </div>

          {/* Quick Actions */}
          <div className="card">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
            <div className="space-y-2">
              <button
                onClick={() => navigate(`/projects/new?contextId=${context.id}`)}
                className="btn-secondary w-full justify-center"
              >
                Create Project from Context
              </button>
              <button
                onClick={() => navigate(`/sketches/new?contextId=${context.id}`)}
                className="btn-secondary w-full justify-center"
              >
                Start New Sketch
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default ContextDetail
