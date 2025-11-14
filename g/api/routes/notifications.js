import express from 'express'

const router = express.Router()

// @route   GET /api/notifications
// @desc    Get all notifications for current user
// @access  Private
router.get('/', async (req, res) => {
  res.json({
    success: true,
    data: [
      {
        id: 1,
        type: 'task_assigned',
        title: 'New Task Assigned',
        message: 'You have been assigned to "Review architectural plans"',
        is_read: false,
        created_at: new Date()
      }
    ]
  })
})

// @route   PATCH /api/notifications/:id/read
// @desc    Mark notification as read
// @access  Private
router.patch('/:id/read', async (req, res) => {
  res.json({
    success: true,
    message: 'Notification marked as read'
  })
})

export default router
