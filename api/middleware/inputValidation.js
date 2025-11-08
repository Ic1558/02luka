import { body, param, query, validationResult } from 'express-validator'

/**
 * Validation middleware and rules
 */

/**
 * Handle validation errors
 */
export function handleValidationErrors(req, res, next) {
  const errors = validationResult(req)
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    })
  }
  next()
}

/**
 * Common validation rules
 */

// Email validation
export const validateEmail = body('email')
  .isEmail()
  .normalizeEmail()
  .withMessage('Please provide a valid email address')

// Strong password validation
export const validatePassword = body('password')
  .isLength({ min: 8 })
  .withMessage('Password must be at least 8 characters long')
  .matches(/[A-Z]/)
  .withMessage('Password must contain at least one uppercase letter')
  .matches(/[a-z]/)
  .withMessage('Password must contain at least one lowercase letter')
  .matches(/[0-9]/)
  .withMessage('Password must contain at least one number')
  .matches(/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/)
  .withMessage('Password must contain at least one special character')

// ID parameter validation
export const validateId = param('id')
  .isInt({ min: 1 })
  .withMessage('Invalid ID parameter')

// Project validation
export const validateProject = [
  body('project_name')
    .trim()
    .isLength({ min: 3, max: 255 })
    .withMessage('Project name must be between 3 and 255 characters'),
  body('project_code')
    .trim()
    .matches(/^[A-Z0-9-]+$/)
    .withMessage('Project code must contain only uppercase letters, numbers, and hyphens'),
  body('project_type')
    .isIn(['residential', 'commercial', 'industrial', 'renovation', 'interior', 'landscape'])
    .withMessage('Invalid project type'),
  body('total_budget')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Budget must be a positive number'),
  body('start_date')
    .optional()
    .isISO8601()
    .withMessage('Invalid start date format'),
  body('estimated_completion')
    .optional()
    .isISO8601()
    .withMessage('Invalid completion date format')
]

// Task validation
export const validateTask = [
  body('task_name')
    .trim()
    .isLength({ min: 3, max: 255 })
    .withMessage('Task name must be between 3 and 255 characters'),
  body('priority')
    .optional()
    .isIn(['low', 'medium', 'high', 'critical'])
    .withMessage('Invalid priority level'),
  body('status')
    .optional()
    .isIn(['pending', 'in_progress', 'completed', 'on_hold', 'cancelled'])
    .withMessage('Invalid task status'),
  body('due_date')
    .optional()
    .isISO8601()
    .withMessage('Invalid due date format')
]

// Context validation
export const validateContext = [
  body('site_name')
    .trim()
    .isLength({ min: 3, max: 255 })
    .withMessage('Site name must be between 3 and 255 characters'),
  body('site_area')
    .isFloat({ min: 0 })
    .withMessage('Site area must be a positive number'),
  body('site_area_unit')
    .isIn(['sqm', 'sqft', 'acres', 'hectares'])
    .withMessage('Invalid area unit'),
  body('zoning_type')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Zoning type must not exceed 100 characters'),
  body('location_lat')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude must be between -90 and 90'),
  body('location_lng')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180')
]

// Sketch validation
export const validateSketch = [
  body('title')
    .trim()
    .isLength({ min: 3, max: 255 })
    .withMessage('Sketch title must be between 3 and 255 characters'),
  body('sketch_type')
    .isIn(['site_plan', 'floor_plan', 'elevation', 'section', 'detail', 'concept', 'freehand', 'annotation'])
    .withMessage('Invalid sketch type'),
  body('canvas_data')
    .isObject()
    .withMessage('Canvas data must be a valid object')
]

// User profile validation
export const validateUserProfile = [
  body('full_name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 255 })
    .withMessage('Full name must be between 2 and 255 characters'),
  body('phone')
    .optional()
    .matches(/^[\d\s\-\+\(\)]+$/)
    .withMessage('Invalid phone number format'),
  body('company')
    .optional()
    .trim()
    .isLength({ max: 255 })
    .withMessage('Company name must not exceed 255 characters')
]

// AI chat validation
export const validateAIChat = [
  body('message')
    .trim()
    .isLength({ min: 1, max: 5000 })
    .withMessage('Message must be between 1 and 5000 characters'),
  body('context')
    .optional()
    .isObject()
    .withMessage('Context must be a valid object')
]

// Query pagination validation
export const validatePagination = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
]

// Sanitization middleware (prevent XSS)
export function sanitizeInput(req, res, next) {
  // Remove any HTML tags from string inputs
  const sanitize = (obj) => {
    if (typeof obj === 'string') {
      return obj.replace(/<[^>]*>/g, '')
    }
    if (typeof obj === 'object' && obj !== null) {
      for (const key in obj) {
        obj[key] = sanitize(obj[key])
      }
    }
    return obj
  }

  if (req.body) {
    req.body = sanitize(req.body)
  }

  next()
}
