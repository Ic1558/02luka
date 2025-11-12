// API Service
// Handles all API communications with Cloudflare Workers backend

const API = {
    // Base URL - will be replaced with actual Cloudflare Worker URL
    baseURL: window.location.hostname === 'localhost'
        ? 'http://localhost:8787'
        : 'https://formwork-api.theedges.work',

    // Chat with AI
    async chat(message, context = {}) {
        try {
            const response = await fetch(`${this.baseURL}/api/ai/chat`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message,
                    context,
                    provider: AIService.config.provider || 'openrouter'
                })
            });

            if (!response.ok) {
                throw new Error(`API Error: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Chat API Error:', error);
            throw error;
        }
    },

    // Save calculation to database
    async saveCalculation(data) {
        try {
            const response = await fetch(`${this.baseURL}/api/calculations`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data)
            });

            if (!response.ok) {
                throw new Error(`Save Error: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Save API Error:', error);
            // Don't throw - saving is optional
            return null;
        }
    },

    // Get calculation history
    async getCalculations(limit = 10) {
        try {
            const response = await fetch(`${this.baseURL}/api/calculations?limit=${limit}`);

            if (!response.ok) {
                throw new Error(`Get Error: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Get API Error:', error);
            return [];
        }
    },

    // Health check
    async healthCheck() {
        try {
            const response = await fetch(`${this.baseURL}/health`);
            return response.ok;
        } catch (error) {
            console.error('Health Check Error:', error);
            return false;
        }
    }
};

// Initialize API on page load
document.addEventListener('DOMContentLoaded', async () => {
    const healthy = await API.healthCheck();
    if (!healthy) {
        console.warn('Backend API is not available. Some features may not work.');
    }
});
