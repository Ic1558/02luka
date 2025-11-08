import rateLimit from 'express-rate-limit'
import { logSecurityEvent } from '../middleware/securityLogger.js'

/**
 * Rate limiting configuration for different endpoints
 * Prevents brute force, DDoS, and abuse
 */

/**
 * General API rate limiter
 * 100 requests per 15 minutes per IP
 */
export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logSecurityEvent('RATE_LIMIT_EXCEEDED', {
      ip: req.ip,
      path: req.path,
      method: req.method
    })
    res.status(429).json({
      success: false,
      message: 'Too many requests from this IP, please try again later.',
      retryAfter: req.rateLimit.resetTime
    })
  }
})

/**
 * Strict rate limiter for authentication endpoints
 * 5 requests per 15 minutes per IP (prevents brute force)
 */
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  skipSuccessfulRequests: true, // Don't count successful logins
  message: {
    success: false,
    message: 'Too many login attempts from this IP, please try again after 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logSecurityEvent('AUTH_RATE_LIMIT_EXCEEDED', {
      ip: req.ip,
      path: req.path,
      email: req.body?.email
    })
    res.status(429).json({
      success: false,
      message: 'Too many login attempts. Please try again after 15 minutes.',
      retryAfter: req.rateLimit.resetTime
    })
  }
})

/**
 * Moderate rate limiter for registration
 * 3 registrations per hour per IP
 */
export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3,
  message: {
    success: false,
    message: 'Too many accounts created from this IP, please try again after an hour.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logSecurityEvent('REGISTER_RATE_LIMIT_EXCEEDED', {
      ip: req.ip,
      email: req.body?.email
    })
    res.status(429).json({
      success: false,
      message: 'Too many accounts created from this IP, please try again after an hour.',
      retryAfter: req.rateLimit.resetTime
    })
  }
})

/**
 * AI endpoint rate limiter
 * 20 requests per hour (AI is resource-intensive)
 */
export const aiLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 20,
  message: {
    success: false,
    message: 'AI request quota exceeded. Please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logSecurityEvent('AI_RATE_LIMIT_EXCEEDED', {
      ip: req.ip,
      userId: req.user?.id,
      path: req.path
    })
    res.status(429).json({
      success: false,
      message: 'AI request quota exceeded. Please try again later.',
      retryAfter: req.rateLimit.resetTime
    })
  }
})

/**
 * File upload rate limiter
 * 10 uploads per 15 minutes
 */
export const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: {
    success: false,
    message: 'Too many file uploads. Please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
})

/**
 * Password reset rate limiter
 * 3 requests per hour per IP
 */
export const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3,
  message: {
    success: false,
    message: 'Too many password reset requests. Please try again after an hour.'
  },
  standardHeaders: true,
  legacyHeaders: false
})
