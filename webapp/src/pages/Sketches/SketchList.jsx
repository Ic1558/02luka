import { useState, useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { FiPlus, FiEdit3, FiCopy, FiTrash2, FiClock } from 'react-icons/fi'
import axios from 'axios'
import { toast } from 'react-toastify'

const SketchList = () => {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [sketches, setSketches] = useState([])
  const [loading, setLoading] = useState(true)
  const [filterType, setFilterType] = useState('all')

  useEffect(() => {
    fetchSketches()
  }, [searchParams])

  const fetchSketches = async () => {
    try {
      const params = {}
      if (searchParams.get('contextId')) {
        params.context_id = searchParams.get('contextId')
      }
      if (searchParams.get('projectId')) {
        params.project_id = searchParams.get('projectId')
      }

      const response = await axios.get('/api/sketches', { params })
      setSketches(response.data.data || [])
    } catch (error) {
      toast.error('Failed to load sketches')
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  const duplicateSketch = async (sketchId) => {
    try {
      const response = await axios.post(`/api/sketches/${sketchId}/duplicate`)
      toast.success('Sketch duplicated!')
      fetchSketches()
    } catch (error) {
      toast.error('Failed to duplicate sketch')
    }
  }

  const deleteSketch = async (sketchId) => {
    if (!confirm('Are you sure you want to delete this sketch?')) return

    try {
      await axios.delete(`/api/sketches/${sketchId}`)
      toast.success('Sketch deleted')
      fetchSketches()
    } catch (error) {
      toast.error('Failed to delete sketch')
    }
  }

  const filteredSketches = filterType === 'all'
    ? sketches
    : sketches.filter(s => s.sketch_type === filterType)

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-600">Loading sketches...</div>
      </div>
    )
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
        <div>
          <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">Sketches</h1>
          <p className="text-gray-600 mt-1">2D drawings, concepts, and design sketches</p>
        </div>

        <button
          onClick={() => navigate('/sketches/new')}
          className="btn-primary flex items-center justify-center space-x-2"
        >
          <FiPlus className="w-5 h-5" />
          <span>New Sketch</span>
        </button>
      </div>

      {/* Filters */}
      <div className="flex items-center space-x-2 overflow-x-auto pb-2">
        {['all', 'site_plan', 'floor_plan', 'elevation', 'section', 'detail', 'concept', 'freehand'].map((type) => (
          <button
            key={type}
            onClick={() => setFilterType(type)}
            className={`px-4 py-2 rounded-lg font-medium text-sm whitespace-nowrap transition ${
              filterType === type
                ? 'bg-primary-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {type.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
          </button>
        ))}
      </div>

      {/* Sketches Grid */}
      {filteredSketches.length === 0 ? (
        <div className="card text-center py-12">
          <div className="flex justify-center mb-4">
            <div className="w-16 h-16 rounded-full bg-primary-100 flex items-center justify-center">
              <FiEdit3 className="w-8 h-8 text-primary-600" />
            </div>
          </div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">No Sketches Yet</h3>
          <p className="text-gray-600 mb-6 max-w-md mx-auto">
            Create your first sketch to visualize site plans, floor layouts, or concept designs
          </p>
          <button
            onClick={() => navigate('/sketches/new')}
            className="btn-primary inline-flex items-center space-x-2"
          >
            <FiPlus className="w-5 h-5" />
            <span>Create First Sketch</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {filteredSketches.map((sketch) => (
            <div
              key={sketch.id}
              className="card hover:shadow-lg transition-all group cursor-pointer"
            >
              {/* Thumbnail */}
              <div
                onClick={() => navigate(`/sketches/${sketch.id}`)}
                className="relative h-48 -mx-6 -mt-6 mb-4 rounded-t-lg overflow-hidden bg-gray-100"
              >
                {sketch.thumbnail_url ? (
                  <img
                    src={sketch.thumbnail_url}
                    alt={sketch.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <FiEdit3 className="w-12 h-12 text-gray-300" />
                  </div>
                )}
                <div className="absolute top-3 right-3">
                  <span className={`badge ${
                    sketch.status === 'approved'
                      ? 'badge-success'
                      : sketch.status === 'review'
                      ? 'badge-warning'
                      : 'badge-gray'
                  }`}>
                    {sketch.status}
                  </span>
                </div>
              </div>

              {/* Info */}
              <div onClick={() => navigate(`/sketches/${sketch.id}`)}>
                <h3 className="font-semibold text-gray-900 group-hover:text-primary-600 transition line-clamp-2 mb-1">
                  {sketch.title}
                </h3>
                <p className="text-sm text-gray-500 mb-3">
                  {sketch.sketch_type.replace('_', ' ')} • v{sketch.version}
                </p>
                {sketch.description && (
                  <p className="text-sm text-gray-600 line-clamp-2 mb-3">
                    {sketch.description}
                  </p>
                )}
              </div>

              {/* Actions */}
              <div className="flex items-center justify-between pt-3 border-t">
                <div className="flex items-center text-xs text-gray-500 space-x-1">
                  <FiClock className="w-4 h-4" />
                  <span>{new Date(sketch.updated_at).toLocaleDateString()}</span>
                </div>
                <div className="flex items-center space-x-1">
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      navigate(`/sketches/${sketch.id}`)
                    }}
                    className="p-2 hover:bg-gray-100 rounded transition"
                    title="Edit"
                  >
                    <FiEdit3 className="w-4 h-4 text-gray-600" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      duplicateSketch(sketch.id)
                    }}
                    className="p-2 hover:bg-gray-100 rounded transition"
                    title="Duplicate"
                  >
                    <FiCopy className="w-4 h-4 text-gray-600" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      deleteSketch(sketch.id)
                    }}
                    className="p-2 hover:bg-gray-100 rounded transition"
                    title="Delete"
                  >
                    <FiTrash2 className="w-4 h-4 text-red-600" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default SketchList
