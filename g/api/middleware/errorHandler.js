export function errorHandler(err, req, res, next) {
  let error = { ...err }
  error.message = err.message

  // Log error for dev
  if (process.env.NODE_ENV === 'development') {
    console.error(err)
  }

  // Sequelize validation error
  if (err.name === 'SequelizeValidationError') {
    const message = Object.values(err.errors).map(val => val.message)
    error = {
      statusCode: 400,
      message: message
    }
  }

  // Sequelize duplicate key
  if (err.name === 'SequelizeUniqueConstraintError') {
    const message = 'Duplicate field value entered'
    error = {
      statusCode: 400,
      message: message
    }
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    const message = 'Invalid token'
    error = {
      statusCode: 401,
      message: message
    }
  }

  if (err.name === 'TokenExpiredError') {
    const message = 'Token expired'
    error = {
      statusCode: 401,
      message: message
    }
  }

  res.status(error.statusCode || 500).json({
    success: false,
    message: error.message || 'Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  })
}
