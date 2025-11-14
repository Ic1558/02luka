import express from 'express'

const router = express.Router()

// @route   GET /api/team
// @desc    Get all team members
// @access  Private
router.get('/', async (req, res) => {
  res.json({
    success: true,
    data: [
      { id: 1, name: 'John Architect', role: 'Lead Architect', email: 'john@example.com' },
      { id: 2, name: 'Sarah Designer', role: 'Interior Designer', email: 'sarah@example.com' }
    ]
  })
})

export default router
