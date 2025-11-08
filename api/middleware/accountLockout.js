import { logSecurityEvent } from './securityLogger.js'

/**
 * Account lockout tracking
 * Prevents brute force attacks by locking accounts after failed attempts
 */

// In-memory storage (replace with Redis in production for distributed systems)
const failedAttempts = new Map()
const lockedAccounts = new Map()

const MAX_FAILED_ATTEMPTS = 5
const LOCKOUT_DURATION = 15 * 60 * 1000 // 15 minutes
const ATTEMPT_WINDOW = 15 * 60 * 1000 // 15 minutes

/**
 * Record a failed login attempt
 */
export function recordFailedAttempt(email, ip) {
  const key = `${email}:${ip}`
  const now = Date.now()

  let attempts = failedAttempts.get(key) || []

  // Remove attempts older than the window
  attempts = attempts.filter(timestamp => now - timestamp < ATTEMPT_WINDOW)

  // Add new attempt
  attempts.push(now)
  failedAttempts.set(key, attempts)

  // Check if should lock account
  if (attempts.length >= MAX_FAILED_ATTEMPTS) {
    const lockUntil = now + LOCKOUT_DURATION
    lockedAccounts.set(key, lockUntil)

    logSecurityEvent('ACCOUNT_LOCKED', {
      email,
      ip,
      attempts: attempts.length,
      lockUntil: new Date(lockUntil).toISOString()
    })

    return {
      locked: true,
      remainingAttempts: 0,
      lockUntil: new Date(lockUntil)
    }
  }

  const remainingAttempts = MAX_FAILED_ATTEMPTS - attempts.length

  logSecurityEvent('FAILED_LOGIN_ATTEMPT', {
    email,
    ip,
    attemptCount: attempts.length,
    remainingAttempts
  })

  return {
    locked: false,
    remainingAttempts,
    lockUntil: null
  }
}

/**
 * Check if account is locked
 */
export function isAccountLocked(email, ip) {
  const key = `${email}:${ip}`
  const lockUntil = lockedAccounts.get(key)

  if (!lockUntil) {
    return { locked: false }
  }

  const now = Date.now()

  // Check if lock has expired
  if (now >= lockUntil) {
    // Unlock account
    lockedAccounts.delete(key)
    failedAttempts.delete(key)

    logSecurityEvent('ACCOUNT_UNLOCKED', {
      email,
      ip,
      reason: 'lockout_expired'
    })

    return { locked: false }
  }

  // Account is still locked
  const remainingTime = lockUntil - now

  return {
    locked: true,
    lockUntil: new Date(lockUntil),
    remainingMinutes: Math.ceil(remainingTime / 60000)
  }
}

/**
 * Clear failed attempts (on successful login)
 */
export function clearFailedAttempts(email, ip) {
  const key = `${email}:${ip}`
  failedAttempts.delete(key)
  lockedAccounts.delete(key)
}

/**
 * Manually unlock account (admin function)
 */
export function unlockAccount(email, ip, adminId) {
  const key = `${email}:${ip}`
  failedAttempts.delete(key)
  lockedAccounts.delete(key)

  logSecurityEvent('ACCOUNT_MANUALLY_UNLOCKED', {
    email,
    ip,
    adminId
  })
}

/**
 * Get failed attempt count
 */
export function getFailedAttemptCount(email, ip) {
  const key = `${email}:${ip}`
  const attempts = failedAttempts.get(key) || []
  const now = Date.now()

  // Filter recent attempts
  const recentAttempts = attempts.filter(timestamp => now - timestamp < ATTEMPT_WINDOW)

  return {
    count: recentAttempts.length,
    maxAttempts: MAX_FAILED_ATTEMPTS,
    remaining: Math.max(0, MAX_FAILED_ATTEMPTS - recentAttempts.length)
  }
}

/**
 * Cleanup expired locks (run periodically)
 */
export function cleanupExpiredLocks() {
  const now = Date.now()

  for (const [key, lockUntil] of lockedAccounts.entries()) {
    if (now >= lockUntil) {
      lockedAccounts.delete(key)
      failedAttempts.delete(key)
    }
  }
}

// Run cleanup every 5 minutes
setInterval(cleanupExpiredLocks, 5 * 60 * 1000)
