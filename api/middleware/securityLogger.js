import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const logDir = path.join(__dirname, '../logs')
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true })
}

const securityLogFile = path.join(logDir, 'security.log')
const auditLogFile = path.join(logDir, 'audit.log')

/**
 * Security event logger
 */
export function logSecurityEvent(event, details = {}) {
  const timestamp = new Date().toISOString()
  const logEntry = JSON.stringify({
    timestamp,
    event,
    ...details
  }) + '\n'

  fs.appendFileSync(securityLogFile, logEntry)

  // Also log to console in development
  if (process.env.NODE_ENV === 'development') {
    console.log(`[SECURITY] ${event}:`, details)
  }
}

/**
 * Audit logger for all sensitive operations
 */
export function logAudit(action, userId, details = {}) {
  const timestamp = new Date().toISOString()
  const logEntry = JSON.stringify({
    timestamp,
    action,
    userId,
    ...details
  }) + '\n'

  fs.appendFileSync(auditLogFile, logEntry)
}

/**
 * Security logging middleware
 */
export function securityLoggerMiddleware(req, res, next) {
  // Log authentication attempts
  if (req.path.includes('/auth/login') || req.path.includes('/auth/register')) {
    const originalSend = res.send

    res.send = function (data) {
      const responseData = typeof data === 'string' ? JSON.parse(data) : data

      if (req.path.includes('/auth/login')) {
        if (responseData.success) {
          logSecurityEvent('LOGIN_SUCCESS', {
            email: req.body.email,
            ip: req.ip,
            userAgent: req.get('user-agent')
          })
        } else {
          logSecurityEvent('LOGIN_FAILED', {
            email: req.body.email,
            ip: req.ip,
            userAgent: req.get('user-agent'),
            reason: responseData.message
          })
        }
      }

      if (req.path.includes('/auth/register')) {
        if (responseData.success) {
          logSecurityEvent('REGISTRATION_SUCCESS', {
            email: req.body.email,
            ip: req.ip
          })
        } else {
          logSecurityEvent('REGISTRATION_FAILED', {
            email: req.body.email,
            ip: req.ip,
            reason: responseData.message
          })
        }
      }

      originalSend.call(this, data)
    }
  }

  // Log failed authorization attempts
  const originalStatus = res.status
  res.status = function (code) {
    if (code === 401 || code === 403) {
      logSecurityEvent(code === 401 ? 'UNAUTHORIZED_ACCESS' : 'FORBIDDEN_ACCESS', {
        path: req.path,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('user-agent'),
        userId: req.user?.id
      })
    }
    return originalStatus.call(this, code)
  }

  next()
}

/**
 * Audit logging middleware for sensitive operations
 */
export function auditLoggerMiddleware(req, res, next) {
  // Log all POST, PUT, DELETE operations
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
    const originalSend = res.send

    res.send = function (data) {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        logAudit(
          `${req.method}_${req.path.split('/')[2] || 'unknown'}`,
          req.user?.id,
          {
            path: req.path,
            method: req.method,
            ip: req.ip,
            statusCode: res.statusCode
          }
        )
      }

      originalSend.call(this, data)
    }
  }

  next()
}
