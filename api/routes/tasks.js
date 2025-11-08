import express from 'express'

const router = express.Router()

let tasks = [
  {
    id: 1,
    project_id: 1,
    task_name: 'Foundation completion',
    description: 'Complete foundation work and inspection',
    category: 'construction',
    status: 'completed',
    priority: 'high',
    start_date: '2024-01-20',
    due_date: '2024-02-15',
    completed_date: '2024-02-14',
    progress_percentage: 100,
    created_at: new Date()
  }
]

// @route   GET /api/tasks
// @desc    Get all tasks
// @access  Private
router.get('/', async (req, res) => {
  try {
    const { project_id, status, priority, assigned_to } = req.query

    let filteredTasks = [...tasks]

    if (project_id) {
      filteredTasks = filteredTasks.filter(t => t.project_id === parseInt(project_id))
    }

    if (status) {
      filteredTasks = filteredTasks.filter(t => t.status === status)
    }

    if (priority) {
      filteredTasks = filteredTasks.filter(t => t.priority === priority)
    }

    res.json({
      success: true,
      count: filteredTasks.length,
      data: filteredTasks
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   GET /api/tasks/:id
// @desc    Get single task
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const task = tasks.find(t => t.id === parseInt(req.params.id))

    if (!task) {
      return res.status(404).json({ success: false, message: 'Task not found' })
    }

    res.json({
      success: true,
      data: task
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   POST /api/tasks
// @desc    Create new task
// @access  Private
router.post('/', async (req, res) => {
  try {
    const newTask = {
      id: tasks.length + 1,
      ...req.body,
      progress_percentage: req.body.progress_percentage || 0,
      status: req.body.status || 'pending',
      priority: req.body.priority || 'medium',
      created_at: new Date(),
      updated_at: new Date()
    }

    tasks.push(newTask)

    // Emit real-time event
    const io = req.app.get('io')
    io.to(`project:${newTask.project_id}`).emit('task_created', newTask)

    res.status(201).json({
      success: true,
      data: newTask
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   PUT /api/tasks/:id
// @desc    Update task
// @access  Private
router.put('/:id', async (req, res) => {
  try {
    const taskIndex = tasks.findIndex(t => t.id === parseInt(req.params.id))

    if (taskIndex === -1) {
      return res.status(404).json({ success: false, message: 'Task not found' })
    }

    const updatedTask = {
      ...tasks[taskIndex],
      ...req.body,
      updated_at: new Date()
    }

    tasks[taskIndex] = updatedTask

    // Emit real-time event
    const io = req.app.get('io')
    io.to(`project:${updatedTask.project_id}`).emit('task_updated', updatedTask)

    res.json({
      success: true,
      data: updatedTask
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   DELETE /api/tasks/:id
// @desc    Delete task
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const taskIndex = tasks.findIndex(t => t.id === parseInt(req.params.id))

    if (taskIndex === -1) {
      return res.status(404).json({ success: false, message: 'Task not found' })
    }

    const deletedTask = tasks[taskIndex]
    tasks.splice(taskIndex, 1)

    // Emit real-time event
    const io = req.app.get('io')
    io.to(`project:${deletedTask.project_id}`).emit('task_deleted', { id: deletedTask.id })

    res.json({
      success: true,
      message: 'Task deleted successfully'
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

export default router
