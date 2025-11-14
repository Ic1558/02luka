import express from 'express'
import { body, validationResult } from 'express-validator'
import { protect } from '../middleware/auth.js'

const router = express.Router()

// Mock projects database
let projects = [
  {
    id: 1,
    project_name: 'Modern Villa - Phase 2',
    project_code: 'PRJ-2024-001',
    project_type: 'residential',
    description: 'Luxury modern villa with sustainable design features',
    status: 'construction',
    priority: 'high',
    address: '123 Beverly Drive',
    city: 'Beverly Hills',
    state: 'CA',
    zip_code: '90210',
    start_date: '2024-01-15',
    estimated_completion: '2024-08-30',
    total_budget: 850000,
    spent_amount: 552500,
    currency: 'USD',
    floor_area: 5000,
    floor_area_unit: 'sqft',
    floors_count: 2,
    created_at: new Date(),
    updated_at: new Date()
  }
]

// @route   GET /api/projects
// @desc    Get all projects
// @access  Private
router.get('/', async (req, res) => {
  try {
    const { status, type, search } = req.query

    let filteredProjects = [...projects]

    if (status) {
      filteredProjects = filteredProjects.filter(p => p.status === status)
    }

    if (type) {
      filteredProjects = filteredProjects.filter(p => p.project_type === type)
    }

    if (search) {
      const searchLower = search.toLowerCase()
      filteredProjects = filteredProjects.filter(p =>
        p.project_name.toLowerCase().includes(searchLower) ||
        p.project_code.toLowerCase().includes(searchLower) ||
        p.description.toLowerCase().includes(searchLower)
      )
    }

    res.json({
      success: true,
      count: filteredProjects.length,
      data: filteredProjects
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   GET /api/projects/:id
// @desc    Get single project
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const project = projects.find(p => p.id === parseInt(req.params.id))

    if (!project) {
      return res.status(404).json({ success: false, message: 'Project not found' })
    }

    res.json({
      success: true,
      data: project
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   POST /api/projects
// @desc    Create new project
// @access  Private
router.post(
  '/',
  [
    body('project_name').notEmpty().withMessage('Project name is required'),
    body('project_code').notEmpty().withMessage('Project code is required'),
    body('project_type').isIn(['residential', 'commercial', 'industrial', 'renovation', 'interior', 'landscape'])
      .withMessage('Invalid project type')
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const newProject = {
        id: projects.length + 1,
        ...req.body,
        spent_amount: 0,
        status: req.body.status || 'planning',
        priority: req.body.priority || 'medium',
        currency: req.body.currency || 'USD',
        created_at: new Date(),
        updated_at: new Date()
      }

      projects.push(newProject)

      // Emit real-time event
      const io = req.app.get('io')
      io.emit('project_created', newProject)

      res.status(201).json({
        success: true,
        data: newProject
      })
    } catch (error) {
      res.status(500).json({ success: false, message: 'Server error', error: error.message })
    }
  }
)

// @route   PUT /api/projects/:id
// @desc    Update project
// @access  Private
router.put('/:id', async (req, res) => {
  try {
    const projectIndex = projects.findIndex(p => p.id === parseInt(req.params.id))

    if (projectIndex === -1) {
      return res.status(404).json({ success: false, message: 'Project not found' })
    }

    const updatedProject = {
      ...projects[projectIndex],
      ...req.body,
      updated_at: new Date()
    }

    projects[projectIndex] = updatedProject

    // Emit real-time event
    const io = req.app.get('io')
    io.to(`project:${updatedProject.id}`).emit('project_updated', updatedProject)

    res.json({
      success: true,
      data: updatedProject
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   DELETE /api/projects/:id
// @desc    Delete project
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const projectIndex = projects.findIndex(p => p.id === parseInt(req.params.id))

    if (projectIndex === -1) {
      return res.status(404).json({ success: false, message: 'Project not found' })
    }

    const deletedProject = projects[projectIndex]
    projects.splice(projectIndex, 1)

    // Emit real-time event
    const io = req.app.get('io')
    io.emit('project_deleted', { id: deletedProject.id })

    res.json({
      success: true,
      message: 'Project deleted successfully'
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   GET /api/projects/:id/stats
// @desc    Get project statistics
// @access  Private
router.get('/:id/stats', async (req, res) => {
  try {
    const project = projects.find(p => p.id === parseInt(req.params.id))

    if (!project) {
      return res.status(404).json({ success: false, message: 'Project not found' })
    }

    // Mock statistics
    const stats = {
      budget_used_percentage: ((project.spent_amount / project.total_budget) * 100).toFixed(2),
      days_remaining: Math.ceil((new Date(project.estimated_completion) - new Date()) / (1000 * 60 * 60 * 24)),
      tasks_completed: 12,
      tasks_total: 25,
      team_members: 8,
      documents: 45,
      photos: 120
    }

    res.json({
      success: true,
      data: stats
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

export default router
