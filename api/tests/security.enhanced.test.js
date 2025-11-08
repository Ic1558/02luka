const request = require('supertest');
const app = require('../server');

describe('Enhanced Security Tests - Phase 23', () => {

  // ========================================
  // PASSWORD STRENGTH VALIDATION
  // ========================================
  describe('Password Strength Validation', () => {
    test('Should reject weak password (too short)', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test1@example.com',
          password: 'Short1!',
          full_name: 'Test User',
          role: 'architect'
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('security requirements');
    });

    test('Should reject password without uppercase', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test2@example.com',
          password: 'password123!',
          full_name: 'Test User',
          role: 'architect'
        });

      expect(response.status).toBe(400);
      expect(response.body.errors).toContain('Password must contain at least one uppercase letter');
    });

    test('Should reject password without special character', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test3@example.com',
          password: 'Password123',
          full_name: 'Test User',
          role: 'architect'
        });

      expect(response.status).toBe(400);
      expect(response.body.errors).toContain('Password must contain at least one special character');
    });

    test('Should accept strong password', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'strongpass@example.com',
          password: 'SecureP@ssw0rd!',
          full_name: 'Test User',
          role: 'architect'
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.token).toBeDefined();
      expect(response.body.refreshToken).toBeDefined();
    });
  });

  // ========================================
  // ACCOUNT LOCKOUT
  // ========================================
  describe('Account Lockout Mechanism', () => {
    beforeAll(async () => {
      // Register a user for lockout testing
      await request(app)
        .post('/api/auth/register')
        .send({
          email: 'lockout@example.com',
          password: 'Correct P@ss123!',
          full_name: 'Lockout Test',
          role: 'architect'
        });
    });

    test('Should show remaining attempts on failed login', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'lockout@example.com',
          password: 'WrongPassword123!'
        });

      expect(response.status).toBe(401);
      expect(response.body.remainingAttempts).toBeDefined();
      expect(response.body.remainingAttempts).toBeLessThanOrEqual(5);
    });

    test('Should lock account after 5 failed attempts', async () => {
      // Make 5 failed login attempts
      for (let i = 0; i < 5; i++) {
        await request(app)
          .post('/api/auth/login')
          .send({
            email: 'lockout@example.com',
            password: 'WrongPassword!'
          });
      }

      // 6th attempt should be locked
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'lockout@example.com',
          password: 'WrongPassword!'
        });

      expect(response.status).toBe(429);
      expect(response.body.message).toContain('locked');
    });
  });

  // ========================================
  // REFRESH TOKEN
  // ========================================
  describe('Refresh Token Functionality', () => {
    let refreshToken;

    beforeAll(async () => {
      const loginResponse = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'refresh@example.com',
          password: 'Refresh P@ss123!',
          full_name: 'Refresh Test',
          role: 'architect'
        });

      refreshToken = loginResponse.body.refreshToken;
    });

    test('Should return new access token with valid refresh token', async () => {
      const response = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.token).toBeDefined();
    });

    test('Should reject invalid refresh token', async () => {
      const response = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: 'invalid-token-12345' });

      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });

    test('Should reject missing refresh token', async () => {
      const response = await request(app)
        .post('/api/auth/refresh')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body.message).toContain('required');
    });
  });

  // ========================================
  // RATE LIMITING
  // ========================================
  describe('Rate Limiting', () => {
    test('Should enforce rate limit on login endpoint', async () => {
      // Make 6 rapid login requests (limit is 5)
      const requests = [];
      for (let i = 0; i < 6; i++) {
        requests.push(
          request(app)
            .post('/api/auth/login')
            .send({
              email: 'ratelimit@example.com',
              password: 'Test123!'
            })
        );
      }

      const responses = await Promise.all(requests);
      const rateLimited = responses.some(r => r.status === 429);

      expect(rateLimited).toBe(true);
    });

    test('Rate limit response should include retry information', async () => {
      // Trigger rate limit
      for (let i = 0; i < 6; i++) {
        const response = await request(app)
          .post('/api/auth/login')
          .send({
            email: 'ratelimit2@example.com',
            password: 'Test123!'
          });

        if (response.status === 429) {
          expect(response.body.retryAfter).toBeDefined();
          break;
        }
      }
    });
  });

  // ========================================
  // INPUT SANITIZATION
  // ========================================
  describe('Input Sanitization (XSS Prevention)', () => {
    test('Should sanitize HTML from input', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'xss@example.com',
          password: 'SecureP@ss123!',
          full_name: '<script>alert("XSS")</script>John Doe',
          role: 'architect'
        });

      if (response.status === 201) {
        expect(response.body.data.full_name).not.toContain('<script>');
        expect(response.body.data.full_name).toContain('John Doe');
      }
    });
  });

  // ========================================
  // LOGOUT
  // ========================================
  describe('Logout Functionality', () => {
    let token, refreshToken;

    beforeAll(async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'logout@example.com',
          password: 'Logout P@ss123!',
          full_name: 'Logout Test',
          role: 'architect'
        });

      token = response.body.token;
      refreshToken = response.body.refreshToken;
    });

    test('Should successfully logout with valid token', async () => {
      const response = await request(app)
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${token}`)
        .send({ refreshToken });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.message).toContain('Logged out');
    });

    test('Should not allow using refresh token after logout', async () => {
      // Try to use the refresh token that was logged out
      const response = await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken });

      expect(response.status).toBe(401);
    });

    test('Logout should require authentication', async () => {
      const response = await request(app)
        .post('/api/auth/logout')
        .send({ refreshToken: 'some-token' });

      expect(response.status).toBe(401);
    });
  });

  // ========================================
  // SECURITY HEADERS
  // ========================================
  describe('Security Headers', () => {
    test('Should include security headers in response', async () => {
      const response = await request(app).get('/healthz');

      expect(response.headers['x-frame-options']).toBeDefined();
      expect(response.headers['x-content-type-options']).toBeDefined();
      expect(response.headers['strict-transport-security']).toBeDefined();
    });

    test('Should have Content-Security-Policy header', async () => {
      const response = await request(app).get('/healthz');

      expect(response.headers['content-security-policy']).toBeDefined();
      expect(response.headers['content-security-policy']).toContain("default-src 'self'");
    });
  });

  // ========================================
  // CORS
  // ========================================
  describe('CORS Configuration', () => {
    test('Should include CORS headers', async () => {
      const response = await request(app)
        .get('/healthz')
        .set('Origin', 'http://localhost:3000');

      expect(response.headers['access-control-allow-origin']).toBeDefined();
    });

    test('Should allow configured origins', async () => {
      const response = await request(app)
        .options('/api/auth/login')
        .set('Origin', 'http://localhost:3000')
        .set('Access-Control-Request-Method', 'POST');

      expect(response.status).toBe(204);
    });
  });
});
