import express from 'express'
import { createServer } from 'http'
import { Server } from 'socket.io'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import compression from 'compression'
import dotenv from 'dotenv'
import rateLimit from 'express-rate-limit'

// Import routes
import authRoutes from './routes/auth.js'
import projectRoutes from './routes/projects.js'
import taskRoutes from './routes/tasks.js'
import teamRoutes from './routes/team.js'
import materialRoutes from './routes/materials.js'
import documentRoutes from './routes/documents.js'
import notificationRoutes from './routes/notifications.js'

// Import middleware
import { errorHandler } from './middleware/errorHandler.js'
import { notFound } from './middleware/notFound.js'

// Import services
import { initializeRedis } from './services/redis.js'
import { initializeDatabase } from './config/database.js'
import { setupSocketHandlers } from './services/socket.js'

dotenv.config()

const app = express()
const httpServer = createServer(app)
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
  }
})

// Security middleware
app.use(helmet())
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
})
app.use('/api/', limiter)

// Body parsing middleware
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Compression middleware
app.use(compression())

// Logging middleware
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'))
} else {
  app.use(morgan('combined'))
}

// Make io accessible to routes
app.set('io', io)

// Health check endpoint
app.get('/healthz', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV
  })
})

// API Routes
app.use('/api/auth', authRoutes)
app.use('/api/projects', projectRoutes)
app.use('/api/tasks', taskRoutes)
app.use('/api/team', teamRoutes)
app.use('/api/materials', materialRoutes)
app.use('/api/documents', documentRoutes)
app.use('/api/notifications', notificationRoutes)

// API info endpoint
app.get('/api', (req, res) => {
  res.json({
    name: 'ProBuild API',
    version: '1.0.0',
    description: 'Architecture & Construction Project Management API',
    endpoints: {
      auth: '/api/auth',
      projects: '/api/projects',
      tasks: '/api/tasks',
      team: '/api/team',
      materials: '/api/materials',
      documents: '/api/documents',
      notifications: '/api/notifications'
    }
  })
})

// Error handling middleware
app.use(notFound)
app.use(errorHandler)

// Initialize services
async function startServer() {
  try {
    // Initialize database
    await initializeDatabase()
    console.log('✅ Database connected successfully')

    // Initialize Redis
    await initializeRedis()
    console.log('✅ Redis connected successfully')

    // Setup Socket.IO handlers
    setupSocketHandlers(io)
    console.log('✅ WebSocket handlers initialized')

    // Start server
    const PORT = process.env.PORT || 4000
    httpServer.listen(PORT, () => {
      console.log(`🚀 ProBuild API Server running on port ${PORT}`)
      console.log(`📊 Environment: ${process.env.NODE_ENV}`)
      console.log(`🔗 Health check: http://localhost:${PORT}/healthz`)
      console.log(`🌐 API documentation: http://localhost:${PORT}/api`)
    })
  } catch (error) {
    console.error('❌ Failed to start server:', error)
    process.exit(1)
  }
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  console.error('Unhandled Promise Rejection:', err)
  httpServer.close(() => process.exit(1))
})

// Handle SIGTERM
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Closing server gracefully...')
  httpServer.close(() => {
    console.log('Server closed')
    process.exit(0)
  })
})

startServer()

export { app, io }
