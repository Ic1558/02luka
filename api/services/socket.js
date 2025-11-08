import jwt from 'jsonwebtoken'

export function setupSocketHandlers(io) {
  // Middleware for authentication
  io.use((socket, next) => {
    const token = socket.handshake.auth.token

    if (!token) {
      return next(new Error('Authentication error'))
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET)
      socket.userId = decoded.id
      socket.userRole = decoded.role
      next()
    } catch (err) {
      next(new Error('Authentication error'))
    }
  })

  io.on('connection', (socket) => {
    console.log(`User connected: ${socket.userId}`)

    // Join user's personal room
    socket.join(`user:${socket.userId}`)

    // Join project rooms
    socket.on('join_project', (projectId) => {
      socket.join(`project:${projectId}`)
      console.log(`User ${socket.userId} joined project ${projectId}`)
    })

    // Leave project room
    socket.on('leave_project', (projectId) => {
      socket.leave(`project:${projectId}`)
      console.log(`User ${socket.userId} left project ${projectId}`)
    })

    // Real-time task updates
    socket.on('task_update', (data) => {
      io.to(`project:${data.projectId}`).emit('task_updated', data)
    })

    // Real-time comments
    socket.on('new_comment', (data) => {
      io.to(`project:${data.projectId}`).emit('comment_added', data)
    })

    // Typing indicators
    socket.on('typing_start', (data) => {
      socket.to(`project:${data.projectId}`).emit('user_typing', {
        userId: socket.userId,
        projectId: data.projectId
      })
    })

    socket.on('typing_stop', (data) => {
      socket.to(`project:${data.projectId}`).emit('user_stopped_typing', {
        userId: socket.userId,
        projectId: data.projectId
      })
    })

    // Presence tracking
    socket.on('user_active', (projectId) => {
      io.to(`project:${projectId}`).emit('user_presence', {
        userId: socket.userId,
        status: 'active',
        projectId
      })
    })

    // Disconnect
    socket.on('disconnect', () => {
      console.log(`User disconnected: ${socket.userId}`)
    })
  })

  return io
}

// Helper function to emit events from routes
export function emitToProject(io, projectId, event, data) {
  io.to(`project:${projectId}`).emit(event, data)
}

export function emitToUser(io, userId, event, data) {
  io.to(`user:${userId}`).emit(event, data)
}
