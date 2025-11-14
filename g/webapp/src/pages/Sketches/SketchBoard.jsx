import { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate, useSearchParams } from 'react-router-dom'
import { fabric } from 'fabric'
import {
  FiSave, FiArrowLeft, FiSquare, FiCircle, FiEdit3,
  FiType, FiTrash2, FiRotateCcw, FiRotateCw, FiMove,
  FiZoomIn, FiZoomOut, FiGrid, FiLayers, FiClock
} from 'react-icons/fi'
import axios from 'axios'
import { toast } from 'react-toastify'

const SketchBoard = () => {
  const { id } = useParams()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const canvasRef = useRef(null)
  const fabricCanvasRef = useRef(null)

  const [sketch, setSketch] = useState(null)
  const [tool, setTool] = useState('select')
  const [color, setColor] = useState('#000000')
  const [strokeWidth, setStrokeWidth] = useState(2)
  const [showGrid, setShowGrid] = useState(true)
  const [saving, setSaving] = useState(false)
  const [title, setTitle] = useState('Untitled Sketch')
  const [sketchType, setSketchType] = useState('freehand')

  useEffect(() => {
    initializeCanvas()
    if (id) {
      loadSketch()
    }

    return () => {
      if (fabricCanvasRef.current) {
        fabricCanvasRef.current.dispose()
      }
    }
  }, [])

  const initializeCanvas = () => {
    const canvas = new fabric.Canvas(canvasRef.current, {
      width: window.innerWidth < 768 ? window.innerWidth - 40 : 1200,
      height: window.innerHeight < 768 ? 500 : 600,
      backgroundColor: '#ffffff',
      selection: true
    })

    fabricCanvasRef.current = canvas

    // Enable object selection and modification
    canvas.on('selection:created', () => setTool('select'))
    canvas.on('selection:updated', () => setTool('select'))
  }

  const loadSketch = async () => {
    try {
      const response = await axios.get(`/api/sketches/${id}`)
      const sketchData = response.data.data
      setSketch(sketchData)
      setTitle(sketchData.title)
      setSketchType(sketchData.sketch_type)

      // Load canvas data
      if (sketchData.canvas_data) {
        fabricCanvasRef.current.loadFromJSON(sketchData.canvas_data, () => {
          fabricCanvasRef.current.renderAll()
        })
      }
    } catch (error) {
      toast.error('Failed to load sketch')
      console.error(error)
    }
  }

  const saveSketch = async () => {
    setSaving(true)
    try {
      const canvasData = fabricCanvasRef.current.toJSON()

      const sketchData = {
        title,
        sketch_type: sketchType,
        canvas_data: canvasData,
        context_id: searchParams.get('contextId') ? parseInt(searchParams.get('contextId')) : null,
        project_id: searchParams.get('projectId') ? parseInt(searchParams.get('projectId')) : null,
        width: fabricCanvasRef.current.width,
        height: fabricCanvasRef.current.height
      }

      if (id) {
        await axios.put(`/api/sketches/${id}`, sketchData)
        toast.success('Sketch saved!')
      } else {
        const response = await axios.post('/api/sketches', sketchData)
        toast.success('Sketch created!')
        navigate(`/sketches/${response.data.data.id}`)
      }
    } catch (error) {
      toast.error('Failed to save sketch')
      console.error(error)
    } finally {
      setSaving(false)
    }
  }

  const addShape = (shapeType) => {
    let shape
    const canvas = fabricCanvasRef.current

    switch (shapeType) {
      case 'rectangle':
        shape = new fabric.Rect({
          left: 100,
          top: 100,
          width: 150,
          height: 100,
          fill: 'transparent',
          stroke: color,
          strokeWidth: strokeWidth
        })
        break
      case 'circle':
        shape = new fabric.Circle({
          left: 100,
          top: 100,
          radius: 50,
          fill: 'transparent',
          stroke: color,
          strokeWidth: strokeWidth
        })
        break
      case 'line':
        shape = new fabric.Line([50, 50, 200, 200], {
          stroke: color,
          strokeWidth: strokeWidth
        })
        break
      case 'text':
        shape = new fabric.Textbox('Double-click to edit', {
          left: 100,
          top: 100,
          width: 200,
          fontSize: 20,
          fill: color
        })
        break
    }

    if (shape) {
      canvas.add(shape)
      canvas.setActiveObject(shape)
      canvas.renderAll()
    }
  }

  const enableDrawing = () => {
    const canvas = fabricCanvasRef.current
    canvas.isDrawingMode = true
    canvas.freeDrawingBrush.color = color
    canvas.freeDrawingBrush.width = strokeWidth
    setTool('draw')
  }

  const disableDrawing = () => {
    const canvas = fabricCanvasRef.current
    canvas.isDrawingMode = false
    setTool('select')
  }

  const deleteSelected = () => {
    const canvas = fabricCanvasRef.current
    const activeObjects = canvas.getActiveObjects()
    if (activeObjects.length) {
      activeObjects.forEach(obj => canvas.remove(obj))
      canvas.discardActiveObject()
      canvas.renderAll()
    }
  }

  const clearCanvas = () => {
    if (confirm('Are you sure you want to clear the canvas?')) {
      fabricCanvasRef.current.clear()
      fabricCanvasRef.current.backgroundColor = '#ffffff'
      fabricCanvasRef.current.renderAll()
    }
  }

  const undo = () => {
    // Simple undo - remove last object
    const canvas = fabricCanvasRef.current
    const objects = canvas.getObjects()
    if (objects.length > 0) {
      canvas.remove(objects[objects.length - 1])
      canvas.renderAll()
    }
  }

  const zoomIn = () => {
    const canvas = fabricCanvasRef.current
    const zoom = canvas.getZoom()
    canvas.setZoom(zoom * 1.1)
  }

  const zoomOut = () => {
    const canvas = fabricCanvasRef.current
    const zoom = canvas.getZoom()
    canvas.setZoom(zoom * 0.9)
  }

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b px-4 py-3 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <button
            onClick={() => navigate(-1)}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
          >
            <FiArrowLeft className="w-5 h-5" />
          </button>

          <div>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="text-lg font-semibold border-none focus:outline-none focus:ring-2 focus:ring-primary-500 rounded px-2"
              placeholder="Sketch title..."
            />
            <div className="flex items-center space-x-2 mt-1">
              <select
                value={sketchType}
                onChange={(e) => setSketchType(e.target.value)}
                className="text-sm border rounded px-2 py-1"
              >
                <option value="freehand">Freehand</option>
                <option value="site_plan">Site Plan</option>
                <option value="floor_plan">Floor Plan</option>
                <option value="elevation">Elevation</option>
                <option value="section">Section</option>
                <option value="detail">Detail</option>
                <option value="concept">Concept</option>
              </select>
              {sketch && (
                <span className="text-xs text-gray-500">v{sketch.version}</span>
              )}
            </div>
          </div>
        </div>

        <button
          onClick={saveSketch}
          disabled={saving}
          className="btn-primary flex items-center space-x-2"
        >
          <FiSave className="w-5 h-5" />
          <span>{saving ? 'Saving...' : 'Save'}</span>
        </button>
      </div>

      {/* Toolbar */}
      <div className="bg-white border-b px-4 py-2 flex items-center space-x-2 overflow-x-auto">
        {/* Tools */}
        <div className="flex items-center space-x-1 border-r pr-3">
          <button
            onClick={() => {
              disableDrawing()
              setTool('select')
            }}
            className={`p-2 rounded ${tool === 'select' ? 'bg-primary-100 text-primary-600' : 'hover:bg-gray-100'}`}
            title="Select (V)"
          >
            <FiMove className="w-5 h-5" />
          </button>

          <button
            onClick={enableDrawing}
            className={`p-2 rounded ${tool === 'draw' ? 'bg-primary-100 text-primary-600' : 'hover:bg-gray-100'}`}
            title="Draw (D)"
          >
            <FiEdit3 className="w-5 h-5" />
          </button>
        </div>

        {/* Shapes */}
        <div className="flex items-center space-x-1 border-r pr-3">
          <button
            onClick={() => addShape('rectangle')}
            className="p-2 hover:bg-gray-100 rounded"
            title="Rectangle (R)"
          >
            <FiSquare className="w-5 h-5" />
          </button>

          <button
            onClick={() => addShape('circle')}
            className="p-2 hover:bg-gray-100 rounded"
            title="Circle (C)"
          >
            <FiCircle className="w-5 h-5" />
          </button>

          <button
            onClick={() => addShape('text')}
            className="p-2 hover:bg-gray-100 rounded"
            title="Text (T)"
          >
            <FiType className="w-5 h-5" />
          </button>
        </div>

        {/* Color & Stroke */}
        <div className="flex items-center space-x-2 border-r pr-3">
          <input
            type="color"
            value={color}
            onChange={(e) => {
              setColor(e.target.value)
              if (fabricCanvasRef.current.isDrawingMode) {
                fabricCanvasRef.current.freeDrawingBrush.color = e.target.value
              }
            }}
            className="w-8 h-8 border rounded cursor-pointer"
          />

          <select
            value={strokeWidth}
            onChange={(e) => {
              setStrokeWidth(parseInt(e.target.value))
              if (fabricCanvasRef.current.isDrawingMode) {
                fabricCanvasRef.current.freeDrawingBrush.width = parseInt(e.target.value)
              }
            }}
            className="text-sm border rounded px-2 py-1"
          >
            <option value="1">1px</option>
            <option value="2">2px</option>
            <option value="3">3px</option>
            <option value="5">5px</option>
            <option value="8">8px</option>
            <option value="12">12px</option>
          </select>
        </div>

        {/* Actions */}
        <div className="flex items-center space-x-1 border-r pr-3">
          <button
            onClick={undo}
            className="p-2 hover:bg-gray-100 rounded"
            title="Undo (Ctrl+Z)"
          >
            <FiRotateCcw className="w-5 h-5" />
          </button>

          <button
            onClick={deleteSelected}
            className="p-2 hover:bg-gray-100 rounded text-red-600"
            title="Delete (Del)"
          >
            <FiTrash2 className="w-5 h-5" />
          </button>
        </div>

        {/* View */}
        <div className="flex items-center space-x-1">
          <button
            onClick={zoomIn}
            className="p-2 hover:bg-gray-100 rounded"
            title="Zoom In (+)"
          >
            <FiZoomIn className="w-5 h-5" />
          </button>

          <button
            onClick={zoomOut}
            className="p-2 hover:bg-gray-100 rounded"
            title="Zoom Out (-)"
          >
            <FiZoomOut className="w-5 h-5" />
          </button>

          <button
            onClick={() => setShowGrid(!showGrid)}
            className={`p-2 rounded ${showGrid ? 'bg-primary-100 text-primary-600' : 'hover:bg-gray-100'}`}
            title="Toggle Grid (G)"
          >
            <FiGrid className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Canvas */}
      <div className="flex-1 overflow-auto p-4 flex items-center justify-center">
        <div className="shadow-lg">
          <canvas ref={canvasRef} />
        </div>
      </div>

      {/* Status Bar */}
      <div className="bg-white border-t px-4 py-2 text-sm text-gray-600 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <span>Tool: {tool}</span>
          {sketch && (
            <span className="flex items-center space-x-1">
              <FiClock className="w-4 h-4" />
              <span>Last saved: {new Date(sketch.updated_at).toLocaleTimeString()}</span>
            </span>
          )}
        </div>
        <div>
          Press Ctrl+S to save
        </div>
      </div>
    </div>
  )
}

export default SketchBoard
