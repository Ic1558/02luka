/**
 * Password strength validator
 * Requirements for 95/100 security score:
 * - Minimum 8 characters
 * - At least one uppercase letter
 * - At least one lowercase letter
 * - At least one number
 * - At least one special character
 */

export function validatePasswordStrength(password) {
  const minLength = 8
  const errors = []

  if (!password || password.length < minLength) {
    errors.push(`Password must be at least ${minLength} characters long`)
  }

  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter')
  }

  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter')
  }

  if (!/[0-9]/.test(password)) {
    errors.push('Password must contain at least one number')
  }

  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    errors.push('Password must contain at least one special character (!@#$%^&*...)')
  }

  // Check for common weak passwords
  const weakPasswords = [
    'password', 'password123', '12345678', 'qwerty123',
    'admin123', 'welcome123', 'letmein123', 'passw0rd'
  ]

  if (weakPasswords.includes(password.toLowerCase())) {
    errors.push('This password is too common. Please choose a stronger password')
  }

  return {
    isValid: errors.length === 0,
    errors,
    strength: calculatePasswordStrength(password)
  }
}

/**
 * Calculate password strength score (0-100)
 */
function calculatePasswordStrength(password) {
  if (!password) return 0

  let score = 0

  // Length score (up to 25 points)
  if (password.length >= 8) score += 10
  if (password.length >= 12) score += 10
  if (password.length >= 16) score += 5

  // Character variety (up to 40 points)
  if (/[a-z]/.test(password)) score += 10
  if (/[A-Z]/.test(password)) score += 10
  if (/[0-9]/.test(password)) score += 10
  if (/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) score += 10

  // Complexity (up to 35 points)
  const uniqueChars = new Set(password).size
  if (uniqueChars >= 5) score += 10
  if (uniqueChars >= 10) score += 10
  if (uniqueChars >= 15) score += 15

  return Math.min(score, 100)
}

/**
 * Get password strength label
 */
export function getPasswordStrengthLabel(score) {
  if (score < 40) return 'Weak'
  if (score < 60) return 'Fair'
  if (score < 80) return 'Good'
  return 'Strong'
}
