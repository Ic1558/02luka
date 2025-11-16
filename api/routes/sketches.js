import express from 'express'
import { body, validationResult } from 'express-validator'

const router = express.Router()

// Mock sketches database
let sketches = []

// Mock sketch revisions
let sketchRevisions = []

// @route   GET /api/sketches
// @desc    Get all sketches
// @access  Private
router.get('/', async (req, res) => {
  try {
    const { context_id, project_id, sketch_type, status } = req.query

    let filteredSketches = [...sketches]

    if (context_id) {
      filteredSketches = filteredSketches.filter(s =>
        s.context_id === parseInt(context_id)
      )
    }

    if (project_id) {
      filteredSketches = filteredSketches.filter(s =>
        s.project_id === parseInt(project_id)
      )
    }

    if (sketch_type) {
      filteredSketches = filteredSketches.filter(s => s.sketch_type === sketch_type)
    }

    if (status) {
      filteredSketches = filteredSketches.filter(s => s.status === status)
    }

    // Only return latest versions by default
    filteredSketches = filteredSketches.filter(s => s.is_latest === true)

    res.json({
      success: true,
      count: filteredSketches.length,
      data: filteredSketches
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   GET /api/sketches/:id
// @desc    Get single sketch with full canvas data
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const sketch = sketches.find(s => s.id === parseInt(req.params.id))

    if (!sketch) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    res.json({
      success: true,
      data: sketch
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   GET /api/sketches/:id/revisions
// @desc    Get sketch revision history
// @access  Private
router.get('/:id/revisions', async (req, res) => {
  try {
    const sketch = sketches.find(s => s.id === parseInt(req.params.id))

    if (!sketch) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    const revisions = sketchRevisions
      .filter(r => r.sketch_id === sketch.id)
      .sort((a, b) => b.version - a.version)

    res.json({
      success: true,
      count: revisions.length,
      current_version: sketch.version,
      data: revisions
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/sketches
// @desc    Create new sketch
// @access  Private
router.post(
  '/',
  [
    body('title').notEmpty().withMessage('Sketch title is required'),
    body('canvas_data').notEmpty().withMessage('Canvas data is required'),
    body('sketch_type').optional().isIn([
      'site_plan', 'floor_plan', 'elevation', 'section',
      'detail', 'concept', 'freehand', 'annotation'
    ])
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const newSketch = {
        id: sketches.length + 1,
        context_id: req.body.context_id || null,
        project_id: req.body.project_id || null,
        title: req.body.title,
        description: req.body.description || '',
        sketch_type: req.body.sketch_type || 'freehand',
        canvas_data: req.body.canvas_data, // Fabric.js JSON
        thumbnail_url: req.body.thumbnail_url || null,
        full_image_url: req.body.full_image_url || null,
        width: req.body.width || 1920,
        height: req.body.height || 1080,
        scale: req.body.scale || '1:100',
        units: req.body.units || 'ft',
        version: 1,
        parent_sketch_id: null,
        is_latest: true,
        created_by: req.body.created_by || 1, // TODO: Get from JWT
        modified_by: req.body.created_by || 1,
        status: req.body.status || 'draft',
        created_at: new Date(),
        updated_at: new Date()
      }

      sketches.push(newSketch)

      // Emit real-time event
      const io = req.app.get('io')
      if (io && newSketch.project_id) {
        io.to(`project:${newSketch.project_id}`).emit('sketch_created', newSketch)
      }

      res.status(201).json({
        success: true,
        data: newSketch
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

// @route   PUT /api/sketches/:id
// @desc    Update sketch (creates new revision if canvas changed)
// @access  Private
router.put('/:id', async (req, res) => {
  try {
    const sketchIndex = sketches.findIndex(s => s.id === parseInt(req.params.id))

    if (sketchIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    const oldSketch = sketches[sketchIndex]

    // Check if canvas data changed - if so, create revision
    if (req.body.canvas_data &&
        JSON.stringify(req.body.canvas_data) !== JSON.stringify(oldSketch.canvas_data)) {

      // Save old version to revisions
      const revision = {
        id: sketchRevisions.length + 1,
        sketch_id: oldSketch.id,
        version: oldSketch.version,
        canvas_data: oldSketch.canvas_data,
        thumbnail_url: oldSketch.thumbnail_url,
        created_by: oldSketch.modified_by,
        change_description: req.body.change_description || 'Updated sketch',
        created_at: oldSketch.updated_at
      }
      sketchRevisions.push(revision)

      // Increment version
      oldSketch.version += 1
    }

    const updatedSketch = {
      ...oldSketch,
      ...req.body,
      modified_by: req.body.modified_by || oldSketch.modified_by,
      updated_at: new Date()
    }

    sketches[sketchIndex] = updatedSketch

    // Emit real-time event
    const io = req.app.get('io')
    if (io && updatedSketch.project_id) {
      io.to(`project:${updatedSketch.project_id}`).emit('sketch_updated', updatedSketch)
    }

    res.json({
      success: true,
      data: updatedSketch
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/sketches/:id/duplicate
// @desc    Duplicate a sketch
// @access  Private
router.post('/:id/duplicate', async (req, res) => {
  try {
    const originalSketch = sketches.find(s => s.id === parseInt(req.params.id))

    if (!originalSketch) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    const duplicatedSketch = {
      ...originalSketch,
      id: sketches.length + 1,
      title: `${originalSketch.title} (Copy)`,
      version: 1,
      parent_sketch_id: originalSketch.id,
      created_at: new Date(),
      updated_at: new Date()
    }

    sketches.push(duplicatedSketch)

    res.status(201).json({
      success: true,
      data: duplicatedSketch
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/sketches/:id/revert/:version
// @desc    Revert sketch to a previous version
// @access  Private
router.post('/:id/revert/:version', async (req, res) => {
  try {
    const sketchIndex = sketches.findIndex(s => s.id === parseInt(req.params.id))

    if (sketchIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    const targetVersion = parseInt(req.params.version)
    const revision = sketchRevisions.find(r =>
      r.sketch_id === parseInt(req.params.id) && r.version === targetVersion
    )

    if (!revision) {
      return res.status(404).json({
        success: false,
        message: 'Revision not found'
      })
    }

    // Save current as revision before reverting
    const currentSketch = sketches[sketchIndex]
    const newRevision = {
      id: sketchRevisions.length + 1,
      sketch_id: currentSketch.id,
      version: currentSketch.version,
      canvas_data: currentSketch.canvas_data,
      thumbnail_url: currentSketch.thumbnail_url,
      created_by: currentSketch.modified_by,
      change_description: `Reverted to version ${targetVersion}`,
      created_at: new Date()
    }
    sketchRevisions.push(newRevision)

    // Revert to old version
    const revertedSketch = {
      ...currentSketch,
      canvas_data: revision.canvas_data,
      thumbnail_url: revision.thumbnail_url,
      version: currentSketch.version + 1,
      modified_by: req.body.modified_by || currentSketch.modified_by,
      updated_at: new Date()
    }

    sketches[sketchIndex] = revertedSketch

    res.json({
      success: true,
      message: `Reverted to version ${targetVersion}`,
      data: revertedSketch
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   DELETE /api/sketches/:id
// @desc    Delete sketch
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const sketchIndex = sketches.findIndex(s => s.id === parseInt(req.params.id))

    if (sketchIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    const deletedSketch = sketches[sketchIndex]
    sketches.splice(sketchIndex, 1)

    // Also delete all revisions
    sketchRevisions = sketchRevisions.filter(r => r.sketch_id !== deletedSketch.id)

    // Emit real-time event
    const io = req.app.get('io')
    if (io && deletedSketch.project_id) {
      io.to(`project:${deletedSketch.project_id}`).emit('sketch_deleted', { id: deletedSketch.id })
    }

    res.json({
      success: true,
      message: 'Sketch deleted successfully'
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/sketches/:id/thumbnail
// @desc    Generate/update sketch thumbnail
// @access  Private
router.post('/:id/thumbnail', async (req, res) => {
  try {
    const sketchIndex = sketches.findIndex(s => s.id === parseInt(req.params.id))

    if (sketchIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Sketch not found'
      })
    }

    // In production, this would:
    // 1. Render canvas to image using node-canvas or puppeteer
    // 2. Generate thumbnail with sharp
    // 3. Upload to S3/storage
    // 4. Return URL

    const thumbnailUrl = req.body.thumbnail_url || `/thumbnails/sketch-${sketches[sketchIndex].id}.png`

    sketches[sketchIndex].thumbnail_url = thumbnailUrl
    sketches[sketchIndex].updated_at = new Date()

    res.json({
      success: true,
      data: {
        thumbnail_url: thumbnailUrl
      }
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
