import express from 'express'
import { body, validationResult } from 'express-validator'

const router = express.Router()

// Mock contexts database (replace with actual DB in production)
let contexts = [
  {
    id: 1,
    name: 'Beverly Hills Residential Site',
    site_name: 'Hillside Lot 42',
    address: '9875 Benedict Canyon Dr',
    city: 'Beverly Hills',
    state: 'CA',
    country: 'USA',
    zip_code: '90210',
    latitude: 34.1016,
    longitude: -118.4105,
    zoning_code: 'R1-H',
    zoning_description: 'Single Family Residential - Hillside',
    lot_size: 15000,
    lot_size_unit: 'sqft',
    floor_area_ratio: 0.45,
    max_height: 35,
    max_height_unit: 'ft',
    setback_front: 25,
    setback_rear: 15,
    setback_side: 10,
    topography: 'Sloped',
    soil_type: 'Clay/Sandy mix',
    flood_zone: 'Zone X',
    seismic_zone: 'Zone 4',
    solar_orientation: 'South-facing slope',
    climate_zone: 'Mediterranean',
    description: 'Premium hillside lot with panoramic city views. Moderate slope requiring terracing.',
    files: [],
    images: [],
    created_by: 1,
    created_at: new Date(),
    updated_at: new Date()
  }
]

// @route   GET /api/contexts
// @desc    Get all design contexts
// @access  Private
router.get('/', async (req, res) => {
  try {
    const { city, state, zoning_code, created_by } = req.query

    let filteredContexts = [...contexts]

    if (city) {
      filteredContexts = filteredContexts.filter(c =>
        c.city?.toLowerCase().includes(city.toLowerCase())
      )
    }

    if (state) {
      filteredContexts = filteredContexts.filter(c => c.state === state)
    }

    if (zoning_code) {
      filteredContexts = filteredContexts.filter(c =>
        c.zoning_code?.includes(zoning_code)
      )
    }

    if (created_by) {
      filteredContexts = filteredContexts.filter(c =>
        c.created_by === parseInt(created_by)
      )
    }

    res.json({
      success: true,
      count: filteredContexts.length,
      data: filteredContexts
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   GET /api/contexts/:id
// @desc    Get single context
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const context = contexts.find(c => c.id === parseInt(req.params.id))

    if (!context) {
      return res.status(404).json({
        success: false,
        message: 'Context not found'
      })
    }

    res.json({
      success: true,
      data: context
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   GET /api/contexts/:id/overview
// @desc    Get context overview with summarized data
// @access  Private
router.get('/:id/overview', async (req, res) => {
  try {
    const context = contexts.find(c => c.id === parseInt(req.params.id))

    if (!context) {
      return res.status(404).json({
        success: false,
        message: 'Context not found'
      })
    }

    // Generate overview summary
    const overview = {
      id: context.id,
      name: context.name,
      location: {
        address: context.address,
        city: context.city,
        state: context.state,
        coordinates: {
          lat: context.latitude,
          lng: context.longitude
        }
      },
      site_data: {
        lot_size: `${context.lot_size} ${context.lot_size_unit}`,
        topography: context.topography,
        orientation: context.solar_orientation
      },
      zoning: {
        code: context.zoning_code,
        description: context.zoning_description,
        far: context.floor_area_ratio,
        max_height: `${context.max_height} ${context.max_height_unit}`,
        setbacks: {
          front: context.setback_front,
          rear: context.setback_rear,
          side: context.setback_side
        }
      },
      constraints: {
        flood_zone: context.flood_zone,
        seismic_zone: context.seismic_zone,
        soil_type: context.soil_type
      },
      buildable_area: Math.round(context.lot_size * (context.floor_area_ratio || 0.5)),
      media: {
        images_count: context.images?.length || 0,
        files_count: context.files?.length || 0
      }
    }

    res.json({
      success: true,
      data: overview
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/contexts
// @desc    Create new context
// @access  Private
router.post(
  '/',
  [
    body('name').notEmpty().withMessage('Context name is required'),
    body('address').optional(),
    body('zoning_code').optional()
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const newContext = {
        id: contexts.length + 1,
        ...req.body,
        files: req.body.files || [],
        images: req.body.images || [],
        created_by: req.body.created_by || 1, // TODO: Get from JWT token
        created_at: new Date(),
        updated_at: new Date()
      }

      contexts.push(newContext)

      // Emit real-time event
      const io = req.app.get('io')
      if (io) {
        io.emit('context_created', newContext)
      }

      res.status(201).json({
        success: true,
        data: newContext
      })
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Server error',
        error: error.message
      })
    }
  }
)

// @route   PUT /api/contexts/:id
// @desc    Update context
// @access  Private
router.put('/:id', async (req, res) => {
  try {
    const contextIndex = contexts.findIndex(c => c.id === parseInt(req.params.id))

    if (contextIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Context not found'
      })
    }

    const updatedContext = {
      ...contexts[contextIndex],
      ...req.body,
      updated_at: new Date()
    }

    contexts[contextIndex] = updatedContext

    // Emit real-time event
    const io = req.app.get('io')
    if (io) {
      io.emit('context_updated', updatedContext)
    }

    res.json({
      success: true,
      data: updatedContext
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   DELETE /api/contexts/:id
// @desc    Delete context
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const contextIndex = contexts.findIndex(c => c.id === parseInt(req.params.id))

    if (contextIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Context not found'
      })
    }

    const deletedContext = contexts[contextIndex]
    contexts.splice(contextIndex, 1)

    // Emit real-time event
    const io = req.app.get('io')
    if (io) {
      io.emit('context_deleted', { id: deletedContext.id })
    }

    res.json({
      success: true,
      message: 'Context deleted successfully'
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

export default router
