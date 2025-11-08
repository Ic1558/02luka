import express from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { body, validationResult } from 'express-validator'
import { protect } from '../middleware/auth.js'
import { validatePasswordStrength } from '../utils/passwordValidator.js'
import {
  recordFailedAttempt,
  isAccountLocked,
  clearFailedAttempts
} from '../middleware/accountLockout.js'

const router = express.Router()

// Mock user database (replace with actual database models)
const users = []

// Refresh token storage (replace with Redis in production)
const refreshTokens = new Map()

// Generate Access JWT token (short-lived)
function generateAccessToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRE || '1h' // Changed to 1 hour for better security
    }
  )
}

// Generate Refresh token (long-lived)
function generateRefreshToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      type: 'refresh'
    },
    process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
    {
      expiresIn: '7d'
    }
  )
}

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post(
  '/register',
  [
    body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
    body('full_name').trim().isLength({ min: 2, max: 255 }).withMessage('Full name must be between 2 and 255 characters'),
    body('role').isIn(['admin', 'architect', 'interior_designer', 'contractor', 'project_manager', 'client'])
      .withMessage('Invalid role')
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const { email, password, full_name, role, phone, company } = req.body

      // Validate password strength
      const passwordValidation = validatePasswordStrength(password)
      if (!passwordValidation.isValid) {
        return res.status(400).json({
          success: false,
          message: 'Password does not meet security requirements',
          errors: passwordValidation.errors
        })
      }

      // Check if user exists
      const existingUser = users.find(u => u.email === email)
      if (existingUser) {
        return res.status(400).json({ success: false, message: 'User already exists' })
      }

      // Hash password
      const salt = await bcrypt.genSalt(12) // Increased from 10 to 12 for better security
      const password_hash = await bcrypt.hash(password, salt)

      // Create user
      const user = {
        id: users.length + 1,
        email,
        password_hash,
        full_name,
        role,
        phone: phone || null,
        company: company || null,
        avatar_url: null,
        is_active: true,
        created_at: new Date()
      }

      users.push(user)

      // Generate tokens
      const accessToken = generateAccessToken(user)
      const refreshToken = generateRefreshToken(user)

      // Store refresh token
      refreshTokens.set(refreshToken, {
        userId: user.id,
        createdAt: new Date()
      })

      res.status(201).json({
        success: true,
        data: {
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          role: user.role,
          phone: user.phone,
          company: user.company
        },
        token: accessToken,
        refreshToken
      })
    } catch (error) {
      res.status(500).json({ success: false, message: 'Server error', error: error.message })
    }
  }
)

// @route   POST /api/auth/login
// @desc    Login user
// @access  Public
router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail().withMessage('Please provide a valid email'),
    body('password').notEmpty().withMessage('Password is required')
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const { email, password } = req.body
      const ip = req.ip

      // Check if account is locked
      const lockStatus = isAccountLocked(email, ip)
      if (lockStatus.locked) {
        return res.status(429).json({
          success: false,
          message: `Account temporarily locked due to too many failed login attempts. Please try again in ${lockStatus.remainingMinutes} minutes.`,
          lockUntil: lockStatus.lockUntil
        })
      }

      // Find user
      const user = users.find(u => u.email === email)
      if (!user) {
        // Record failed attempt
        const attemptResult = recordFailedAttempt(email, ip)
        return res.status(401).json({
          success: false,
          message: 'Invalid credentials',
          remainingAttempts: attemptResult.remainingAttempts
        })
      }

      // Check password
      const isMatch = await bcrypt.compare(password, user.password_hash)
      if (!isMatch) {
        // Record failed attempt
        const attemptResult = recordFailedAttempt(email, ip)
        if (attemptResult.locked) {
          return res.status(429).json({
            success: false,
            message: `Too many failed login attempts. Account locked for 15 minutes.`,
            lockUntil: attemptResult.lockUntil
          })
        }
        return res.status(401).json({
          success: false,
          message: 'Invalid credentials',
          remainingAttempts: attemptResult.remainingAttempts
        })
      }

      // Check if user is active
      if (!user.is_active) {
        return res.status(403).json({
          success: false,
          message: 'Account has been deactivated. Please contact support.'
        })
      }

      // Clear failed attempts on successful login
      clearFailedAttempts(email, ip)

      // Generate tokens
      const accessToken = generateAccessToken(user)
      const refreshToken = generateRefreshToken(user)

      // Store refresh token
      refreshTokens.set(refreshToken, {
        userId: user.id,
        createdAt: new Date()
      })

      res.json({
        success: true,
        data: {
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          role: user.role,
          phone: user.phone,
          company: user.company
        },
        token: accessToken,
        refreshToken
      })
    } catch (error) {
      res.status(500).json({ success: false, message: 'Server error', error: error.message })
    }
  }
)

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', protect, async (req, res) => {
  try {
    // In production, fetch user from database using req.user.id
    // For now, return the user data from the JWT token
    const user = users.find(u => u.id === req.user.id)

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      })
    }

    res.json({
      success: true,
      data: {
        id: user.id,
        email: user.email,
        full_name: user.full_name,
        role: user.role,
        phone: user.phone,
        company: user.company
      }
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/auth/refresh
// @desc    Refresh access token using refresh token
// @access  Public
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token is required'
      })
    }

    // Check if refresh token exists in storage
    if (!refreshTokens.has(refreshToken)) {
      return res.status(401).json({
        success: false,
        message: 'Invalid refresh token'
      })
    }

    // Verify refresh token
    try {
      const decoded = jwt.verify(
        refreshToken,
        process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET
      )

      if (decoded.type !== 'refresh') {
        return res.status(401).json({
          success: false,
          message: 'Invalid token type'
        })
      }

      // Find user
      const user = users.find(u => u.id === decoded.id)
      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        })
      }

      // Generate new access token
      const accessToken = generateAccessToken(user)

      res.json({
        success: true,
        token: accessToken
      })
    } catch (error) {
      // Remove invalid refresh token
      refreshTokens.delete(refreshToken)

      return res.status(401).json({
        success: false,
        message: 'Invalid or expired refresh token'
      })
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

// @route   POST /api/auth/logout
// @desc    Logout user and invalidate refresh token
// @access  Private
router.post('/logout', protect, async (req, res) => {
  try {
    const { refreshToken } = req.body

    if (refreshToken) {
      // Remove refresh token from storage
      refreshTokens.delete(refreshToken)
    }

    res.json({
      success: true,
      message: 'Logged out successfully'
    })
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    })
  }
})

export default router
