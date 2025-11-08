const request = require('supertest');
const app = require('../server');

describe('Authentication Security Tests', () => {
  describe('Protected Routes', () => {
    const protectedEndpoints = [
      { method: 'get', path: '/api/projects' },
      { method: 'get', path: '/api/tasks' },
      { method: 'get', path: '/api/team' },
      { method: 'get', path: '/api/materials' },
      { method: 'get', path: '/api/documents' },
      { method: 'get', path: '/api/notifications' },
      { method: 'get', path: '/api/contexts' },
      { method: 'get', path: '/api/sketches' },
      { method: 'get', path: '/api/ai/agents' },
    ];

    protectedEndpoints.forEach(({ method, path }) => {
      test(`${method.toUpperCase()} ${path} should return 401 without token`, async () => {
        const response = await request(app)[method](path);
        expect(response.status).toBe(401);
        expect(response.body.success).toBe(false);
      });

      test(`${method.toUpperCase()} ${path} should return 401 with invalid token`, async () => {
        const response = await request(app)
          [method](path)
          .set('Authorization', 'Bearer invalid-token-12345');
        expect(response.status).toBe(401);
        expect(response.body.success).toBe(false);
      });
    });

    test('GET /api/auth/me should return 401 without token', async () => {
      const response = await request(app).get('/api/auth/me');
      expect(response.status).toBe(401);
      expect(response.body.success).toBe(false);
    });
  });

  describe('Public Routes', () => {
    test('POST /api/auth/login should be accessible without token', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({ email: 'test@example.com', password: 'password' });

      // Should not return 401 (authentication error)
      expect(response.status).not.toBe(401);
    });

    test('POST /api/auth/register should be accessible without token', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'new@example.com',
          password: 'password123',
          full_name: 'Test User',
          role: 'architect'
        });

      // Should not return 401 (authentication error)
      expect(response.status).not.toBe(401);
    });

    test('GET /healthz should be accessible without token', async () => {
      const response = await request(app).get('/healthz');
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('healthy');
    });
  });

  describe('Valid Authentication', () => {
    let validToken;

    beforeAll(async () => {
      // Register and login to get a valid token
      await request(app)
        .post('/api/auth/register')
        .send({
          email: 'testuser@probuild.com',
          password: 'SecurePass123!',
          full_name: 'Test User',
          role: 'architect'
        });

      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'testuser@probuild.com',
          password: 'SecurePass123!'
        });

      validToken = loginResponse.body.token;
    });

    test('GET /api/projects should succeed with valid token', async () => {
      const response = await request(app)
        .get('/api/projects')
        .set('Authorization', `Bearer ${validToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('GET /api/auth/me should return user data with valid token', async () => {
      const response = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${validToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('email');
      expect(response.body.data).toHaveProperty('role');
    });
  });
});
