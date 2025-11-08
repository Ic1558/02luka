import express from 'express'

const router = express.Router()

// @route   GET /api/documents
// @desc    Get all documents
// @access  Private
router.get('/', async (req, res) => {
  res.json({
    success: true,
    data: []
  })
})

export default router
