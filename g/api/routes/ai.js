import express from 'express'
import { body, validationResult } from 'express-validator'
import axios from 'axios'

const router = express.Router()

// Mock AI agents (replace with database in production)
let aiAgents = [
  {
    id: 1,
    name: 'Ollama Local LLM',
    agent_type: 'local_llm',
    endpoint_url: process.env.OLLAMA_ENDPOINT || 'http://localhost:11434',
    model_name: process.env.OLLAMA_MODEL || 'llama3.2',
    capabilities: ['context_analysis', 'material_recommendation', 'chat_completion', 'document_parsing'],
    is_active: true,
    is_online: false,
    config: { stream: false, temperature: 0.7, top_p: 0.9 }
  }
]

// Mock AI tasks queue
let aiTasks = []
let aiConversations = []
let aiMessages = []
let aiInsights = []

// Helper: Call local LLM (Ollama-compatible)
async function callLocalLLM(agent, prompt, systemPrompt = null) {
  try {
    const messages = []

    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt })
    }

    messages.push({ role: 'user', content: prompt })

    const response = await axios.post(`${agent.endpoint_url}/api/chat`, {
      model: agent.model_name,
      messages: messages,
      stream: false,
      options: {
        temperature: agent.config.temperature || 0.7,
        top_p: agent.config.top_p || 0.9
      }
    }, {
      timeout: 60000 // 60 second timeout
    })

    return {
      success: true,
      content: response.data.message?.content || response.data.response,
      model: agent.model_name,
      tokens: response.data.eval_count || 0
    }
  } catch (error) {
    console.error('Local LLM call failed:', error.message)
    return {
      success: false,
      error: error.message
    }
  }
}

// @route   GET /api/ai/agents
// @desc    Get all AI agents
// @access  Private
router.get('/agents', async (req, res) => {
  try {
    res.json({
      success: true,
      count: aiAgents.length,
      data: aiAgents.map(agent => ({
        ...agent,
        api_key: undefined // Don't expose API keys
      }))
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   GET /api/ai/agents/:id/health
// @desc    Check AI agent health
// @access  Private
router.get('/agents/:id/health', async (req, res) => {
  try {
    const agent = aiAgents.find(a => a.id === parseInt(req.params.id))

    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' })
    }

    // Check if agent is reachable
    let isOnline = false
    let latency = null

    try {
      const startTime = Date.now()

      if (agent.agent_type === 'local_llm') {
        await axios.get(`${agent.endpoint_url}/api/tags`, { timeout: 5000 })
      }

      latency = Date.now() - startTime
      isOnline = true
    } catch (error) {
      isOnline = false
    }

    // Update agent status
    const agentIndex = aiAgents.findIndex(a => a.id === agent.id)
    aiAgents[agentIndex].is_online = isOnline
    aiAgents[agentIndex].last_health_check = new Date()

    res.json({
      success: true,
      data: {
        agent_id: agent.id,
        name: agent.name,
        is_online: isOnline,
        latency_ms: latency,
        last_check: new Date()
      }
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   POST /api/ai/tasks
// @desc    Create new AI task
// @access  Private
router.post(
  '/tasks',
  [
    body('task_type').isIn([
      'context_analysis', 'zoning_extraction', 'material_recommendation',
      'cost_estimation', 'sketch_analysis', 'document_parsing',
      'report_generation', 'chat_completion', 'code_generation'
    ]),
    body('prompt').notEmpty()
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const {
        agent_id = 1,
        task_type,
        prompt,
        input_data,
        instructions,
        project_id,
        context_id,
        sketch_id,
        priority = 5
      } = req.body

      const newTask = {
        id: aiTasks.length + 1,
        agent_id,
        task_type,
        prompt,
        input_data: input_data || {},
        instructions,
        project_id,
        context_id,
        sketch_id,
        status: 'pending',
        priority,
        requested_by: req.body.requested_by || 1,
        created_at: new Date(),
        updated_at: new Date()
      }

      aiTasks.push(newTask)

      // Emit real-time event
      const io = req.app.get('io')
      if (io) {
        io.emit('ai_task_created', newTask)
      }

      // Process task asynchronously
      processAITask(newTask.id, req.app.get('io'))

      res.status(201).json({
        success: true,
        data: newTask
      })
    } catch (error) {
      res.status(500).json({ success: false, message: 'Server error', error: error.message })
    }
  }
)

// Background task processor
async function processAITask(taskId, io) {
  const taskIndex = aiTasks.findIndex(t => t.id === taskId)
  if (taskIndex === -1) return

  const task = aiTasks[taskIndex]
  const agent = aiAgents.find(a => a.id === task.agent_id)

  if (!agent) {
    task.status = 'failed'
    task.error_message = 'Agent not found'
    task.updated_at = new Date()
    return
  }

  // Update status to processing
  task.status = 'processing'
  task.started_at = new Date()
  task.updated_at = new Date()

  if (io) {
    io.emit('ai_task_updated', task)
  }

  const startTime = Date.now()

  try {
    // Build system prompt based on task type
    let systemPrompt = 'You are an expert AI assistant for architecture and construction projects.'

    switch (task.task_type) {
      case 'context_analysis':
        systemPrompt = 'You are an expert site analyst. Analyze the given site context and provide insights about buildability, constraints, and opportunities.'
        break
      case 'material_recommendation':
        systemPrompt = 'You are a materials expert for construction. Recommend suitable materials based on project requirements, budget, and sustainability.'
        break
      case 'cost_estimation':
        systemPrompt = 'You are a construction cost estimator. Provide accurate cost estimates based on project details.'
        break
      case 'document_parsing':
        systemPrompt = 'You are a document analysis expert. Extract structured information from the provided text.'
        break
    }

    // Call AI
    const result = await callLocalLLM(agent, task.prompt, systemPrompt)

    if (result.success) {
      task.status = 'completed'
      task.result = result.content
      task.result_data = {
        model: result.model,
        tokens: result.tokens
      }
    } else {
      task.status = 'failed'
      task.error_message = result.error
    }
  } catch (error) {
    task.status = 'failed'
    task.error_message = error.message
  }

  task.completed_at = new Date()
  task.processing_time_ms = Date.now() - startTime
  task.updated_at = new Date()

  aiTasks[taskIndex] = task

  if (io) {
    io.emit('ai_task_completed', task)
  }
}

// @route   GET /api/ai/tasks
// @desc    Get all AI tasks
// @access  Private
router.get('/tasks', async (req, res) => {
  try {
    const { status, task_type, project_id } = req.query

    let filteredTasks = [...aiTasks]

    if (status) {
      filteredTasks = filteredTasks.filter(t => t.status === status)
    }

    if (task_type) {
      filteredTasks = filteredTasks.filter(t => t.task_type === task_type)
    }

    if (project_id) {
      filteredTasks = filteredTasks.filter(t => t.project_id === parseInt(project_id))
    }

    // Sort by priority and created date
    filteredTasks.sort((a, b) => {
      if (b.priority !== a.priority) return b.priority - a.priority
      return new Date(b.created_at) - new Date(a.created_at)
    })

    res.json({
      success: true,
      count: filteredTasks.length,
      data: filteredTasks
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   GET /api/ai/tasks/:id
// @desc    Get single AI task
// @access  Private
router.get('/tasks/:id', async (req, res) => {
  try {
    const task = aiTasks.find(t => t.id === parseInt(req.params.id))

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

// @route   POST /api/ai/chat
// @desc    Chat completion with AI
// @access  Private
router.post('/chat', async (req, res) => {
  try {
    const { message, conversation_id, agent_id = 1, context } = req.body

    if (!message) {
      return res.status(400).json({ success: false, message: 'Message is required' })
    }

    const agent = aiAgents.find(a => a.id === agent_id)
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' })
    }

    // Build context-aware prompt
    let fullPrompt = message
    if (context) {
      fullPrompt = `Context: ${JSON.stringify(context)}\n\nUser: ${message}`
    }

    const result = await callLocalLLM(agent, fullPrompt)

    if (!result.success) {
      return res.status(500).json({
        success: false,
        message: 'AI call failed',
        error: result.error
      })
    }

    res.json({
      success: true,
      data: {
        message: result.content,
        model: result.model,
        tokens: result.tokens
      }
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

// @route   POST /api/ai/analyze-context
// @desc    Analyze design context with AI
// @access  Private
router.post('/analyze-context', async (req, res) => {
  try {
    const { context_id, context_data } = req.body

    const prompt = `Analyze this construction site context and provide insights:

Site: ${context_data.name}
Location: ${context_data.city}, ${context_data.state}
Lot Size: ${context_data.lot_size} ${context_data.lot_size_unit}
Zoning: ${context_data.zoning_code}
${context_data.zoning_description ? `Zoning Details: ${context_data.zoning_description}` : ''}
Topography: ${context_data.topography}
${context_data.floor_area_ratio ? `FAR: ${context_data.floor_area_ratio}` : ''}

Provide:
1. Key opportunities for this site
2. Potential constraints or challenges
3. Design recommendations
4. Regulatory compliance considerations
5. Sustainability suggestions

Be concise and practical.`

    const task = {
      agent_id: 1,
      task_type: 'context_analysis',
      prompt,
      context_id,
      input_data: context_data,
      priority: 7
    }

    // Create task and return immediately
    const newTask = {
      id: aiTasks.length + 1,
      ...task,
      status: 'pending',
      requested_by: req.body.requested_by || 1,
      created_at: new Date(),
      updated_at: new Date()
    }

    aiTasks.push(newTask)
    processAITask(newTask.id, req.app.get('io'))

    res.json({
      success: true,
      message: 'Analysis started',
      task_id: newTask.id
    })
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message })
  }
})

export default router
