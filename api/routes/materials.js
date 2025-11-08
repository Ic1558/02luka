import express from 'express'

const router = express.Router()

// @route   GET /api/materials
// @desc    Get all materials
// @access  Private
router.get('/', async (req, res) => {
  res.json({
    success: true,
    data: []
  })
})

export default router
