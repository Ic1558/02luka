import express from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { body, validationResult } from 'express-validator'
import { protect } from '../middleware/auth.js'

const router = express.Router()

// Mock user database (replace with actual database models)
const users = []

// Generate JWT token
function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRE || '7d'
    }
  )
}

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post(
  '/register',
  [
    body('email').isEmail().withMessage('Please provide a valid email'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    body('full_name').notEmpty().withMessage('Full name is required'),
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

      // Check if user exists
      const existingUser = users.find(u => u.email === email)
      if (existingUser) {
        return res.status(400).json({ success: false, message: 'User already exists' })
      }

      // Hash password
      const salt = await bcrypt.genSalt(10)
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

      // Generate token
      const token = generateToken(user)

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
        token
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
    body('email').isEmail().withMessage('Please provide a valid email'),
    body('password').notEmpty().withMessage('Password is required')
  ],
  async (req, res) => {
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() })
    }

    try {
      const { email, password } = req.body

      // Find user
      const user = users.find(u => u.email === email)
      if (!user) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' })
      }

      // Check password
      const isMatch = await bcrypt.compare(password, user.password_hash)
      if (!isMatch) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' })
      }

      // Generate token
      const token = generateToken(user)

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
        token
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

export default router
