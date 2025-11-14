# PR #237 Security Fixes

**PR:** #237 - Build a web app with Claude  
**Issue:** 🚨 CRITICAL - All API endpoints are unprotected  
**Priority:** P0 - IMMEDIATE  
**Status:** FIXES REQUIRED

---

## 🚨 Critical Security Fixes

### Fix 1: Apply Protect Middleware to All Routes

#### File: `api/routes/projects.js`

**Current (UNPROTECTED):**
```javascript
import { protect } from '../middleware/auth.js'  // ✅ Imported but NOT USED

router.get('/', async (req, res) => {  // ❌ UNPROTECTED
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import { protect } from '../middleware/auth.js'

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Only authenticated users can access
  // req.user is available from JWT
})

router.get('/:id', protect, async (req, res) => {
  // Protected
})

router.post('/', protect, [
  // validation middleware
], async (req, res) => {
  // Protected
})

router.put('/:id', protect, async (req, res) => {
  // Protected
})

router.delete('/:id', protect, async (req, res) => {
  // Protected
})

router.get('/:id/stats', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/tasks.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not even imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected
})

router.get('/:id', protect, async (req, res) => {
  // Protected
})

router.post('/', protect, async (req, res) => {
  // Protected
})

router.put('/:id', protect, async (req, res) => {
  // Protected
})

router.delete('/:id', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/contexts.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { body, validationResult } from 'express-validator'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected
})

router.get('/:id', protect, async (req, res) => {
  // Protected
})

router.get('/:id/overview', protect, async (req, res) => {
  // Protected
})

router.post('/', protect, [
  // validation middleware
], async (req, res) => {
  // Protected
})

router.put('/:id', protect, async (req, res) => {
  // Protected
})

router.delete('/:id', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/ai.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/agents', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { body, validationResult } from 'express-validator'
import axios from 'axios'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/agents', protect, async (req, res) => {
  // Protected
})

router.get('/agents/:id/health', protect, async (req, res) => {
  // Protected
})

router.post('/tasks', protect, [
  // validation middleware
], async (req, res) => {
  // Protected
})

router.get('/tasks', protect, async (req, res) => {
  // Protected
})

router.get('/tasks/:id', protect, async (req, res) => {
  // Protected
})

router.post('/chat', protect, async (req, res) => {
  // Protected
})

router.post('/analyze-context', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/sketches.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { body, validationResult } from 'express-validator'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected
})

router.get('/:id', protect, async (req, res) => {
  // Protected
})

router.get('/:id/revisions', protect, async (req, res) => {
  // Protected
})

router.post('/', protect, [
  // validation middleware
], async (req, res) => {
  // Protected
})

router.put('/:id', protect, async (req, res) => {
  // Protected
})

router.post('/:id/duplicate', protect, async (req, res) => {
  // Protected
})

router.post('/:id/revert/:version', protect, async (req, res) => {
  // Protected
})

router.delete('/:id', protect, async (req, res) => {
  // Protected
})

router.post('/:id/thumbnail', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/team.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/materials.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/documents.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected
})
```

#### File: `api/routes/notifications.js`

**Current (UNPROTECTED):**
```javascript
// ❌ protect not imported

router.get('/', async (req, res) => {
  // Anyone can access
})
```

**Fixed (PROTECTED):**
```javascript
import express from 'express'
import { protect } from '../middleware/auth.js'  // ✅ Add import

const router = express.Router()

// Apply protect to all routes
router.get('/', protect, async (req, res) => {
  // Protected - filter by req.user.id
  // Only return notifications for current user
})

router.patch('/:id/read', protect, async (req, res) => {
  // Protected
})
```

### Fix 2: Fix Auth Endpoint

#### File: `api/routes/auth.js`

**Current (UNPROTECTED):**
```javascript
// @route   GET /api/auth/me
// @access  Private
router.get('/me', async (req, res) => {
  // ❌ Hardcoded demo data, no authentication
  res.json({
    success: true,
    data: {
      id: 1,
      email: 'demo@probuild.com',
      full_name: 'Demo User',
      role: 'architect'
    }
  })
})
```

**Fixed (PROTECTED):**
```javascript
import { protect } from '../middleware/auth.js'

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', protect, async (req, res) => {
  try {
    // req.user is set by protect middleware
    // Fetch actual user from database
    const user = await getUserById(req.user.id)
    
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
```

### Fix 3: Fix Authorize Middleware

#### File: `api/middleware/auth.js`

**Current (BROKEN):**
```javascript
export function authorize(...roles) {
  return (req, res, next) => {  // ❌ Missing check for req.user
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `User role ${req.user.role} is not authorized to access this route`
      })
    }
    next()
  }
}
```

**Fixed (CORRECT):**
```javascript
export function authorize(...roles) {
  return (req, res, next) => {
    // Ensure protect middleware was called first
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized to access this route'
      })
    }
    
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `User role ${req.user.role} is not authorized to access this route`
      })
    }
    next()
  }
}
```

### Fix 4: Apply Role-Based Authorization

#### Example: `api/routes/projects.js`

**Add role-based authorization:**
```javascript
import { protect, authorize } from '../middleware/auth.js'

// Only admins can delete
router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  // Only admins can delete projects
})

// Admins and architects can update
router.put('/:id', protect, authorize('admin', 'architect'), async (req, res) => {
  // Only admins and architects can update
})

// All authenticated users can read
router.get('/', protect, async (req, res) => {
  // All authenticated users can read
})
```

---

## 📋 Implementation Checklist

### Critical Fixes (IMMEDIATE)
- [ ] Apply `protect` to `api/routes/projects.js`
- [ ] Apply `protect` to `api/routes/tasks.js`
- [ ] Apply `protect` to `api/routes/contexts.js`
- [ ] Apply `protect` to `api/routes/ai.js`
- [ ] Apply `protect` to `api/routes/sketches.js`
- [ ] Apply `protect` to `api/routes/team.js`
- [ ] Apply `protect` to `api/routes/materials.js`
- [ ] Apply `protect` to `api/routes/documents.js`
- [ ] Apply `protect` to `api/routes/notifications.js`
- [ ] Fix `/api/auth/me` endpoint
- [ ] Fix `authorize` middleware
- [ ] Test all endpoints with/without authentication

### High Priority (This Week)
- [ ] Add role-based authorization
- [ ] Add security tests
- [ ] Add enhanced security headers
- [ ] Add per-endpoint rate limiting
- [ ] Add input validation

### Medium Priority (This Month)
- [ ] Add comprehensive tests
- [ ] Add API documentation
- [ ] Add security documentation
- [ ] Replace mock data with database
- [ ] Add error logging

---

## 🧪 Testing

### Test Authentication

```javascript
// Test unprotected endpoint (should fail)
const response = await request(app)
  .get('/api/projects')
  .expect(401)

expect(response.body.success).toBe(false)
expect(response.body.message).toContain('Not authorized')

// Test protected endpoint (should pass)
const token = generateTestToken()
const response = await request(app)
  .get('/api/projects')
  .set('Authorization', `Bearer ${token}`)
  .expect(200)

expect(response.body.success).toBe(true)
```

### Test Authorization

```javascript
// Test unauthorized role (should fail)
const token = generateTestToken({ role: 'user' })
const response = await request(app)
  .delete('/api/projects/1')
  .set('Authorization', `Bearer ${token}`)
  .expect(403)

expect(response.body.success).toBe(false)
expect(response.body.message).toContain('not authorized')

// Test authorized role (should pass)
const token = generateTestToken({ role: 'admin' })
const response = await request(app)
  .delete('/api/projects/1')
  .set('Authorization', `Bearer ${token}`)
  .expect(200)
```

---

## 📝 Summary

**Status:** 🚨 **CRITICAL SECURITY VULNERABILITY**

**Required Actions:**
1. Apply `protect` middleware to ALL private routes
2. Fix `/api/auth/me` endpoint
3. Fix `authorize` middleware
4. Test all endpoints
5. Add security tests

**Expected Score After Fixes:**
- **Before:** 60/100 (D+) - Fails due to security
- **After:** 75/100 (C+) - Security fixed

**DO NOT USE IN PRODUCTION** until all fixes are applied.

---

**Last Updated:** 2025-11-09  
**Status:** 🚨 CRITICAL FIXES REQUIRED
