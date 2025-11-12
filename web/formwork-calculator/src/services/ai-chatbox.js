// AI Chatbox Service
// Handles communication with multiple LLM providers (OpenRouter, Ollama, Kimi, etc.)

const AIService = {
    // Configuration for multiple LLM providers
    config: {
        provider: 'openrouter', // 'openrouter', 'ollama', 'kimi', 'gpt4o', 'claude'
        models: {
            openrouter: {
                endpoint: 'https://openrouter.ai/api/v1/chat/completions',
                model: 'deepseek/deepseek-chat', // Free model, good for Thai
                apiKey: '' // Will be set from Cloudflare Workers
            },
            ollama: {
                endpoint: 'http://localhost:11434/api/generate',
                model: 'qwen2.5:latest' // Good for Thai language
            },
            kimi: {
                endpoint: 'https://api.moonshot.cn/v1/chat/completions',
                model: 'moonshot-v1-8k',
                apiKey: ''
            },
            glm: {
                endpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
                model: 'glm-4-flash',
                apiKey: ''
            }
        }
    },

    // Chat history
    chatHistory: [],

    // Send message to AI
    async sendMessage(message, context = {}) {
        try {
            // Add user message to chat
            this.addMessageToUI('user', message);
            this.chatHistory.push({ role: 'user', content: message });

            // Show typing indicator
            this.showTyping();

            // Prepare system prompt
            const systemPrompt = this.buildSystemPrompt(context);

            // Call AI based on provider
            const response = await this.callAI(systemPrompt, message);

            // Remove typing indicator
            this.hideTyping();

            // Add AI response to chat
            this.addMessageToUI('ai', response.message);
            this.chatHistory.push({ role: 'assistant', content: response.message });

            // If AI extracted data, populate form
            if (response.data) {
                populateForm(response.data);
            }

            // If AI has insights, show them
            if (response.insights) {
                showInsights(response.insights);
            }

            return response;
        } catch (error) {
            this.hideTyping();
            console.error('AI Error:', error);
            this.addMessageToUI('ai', 'ขอโทษครับ เกิดข้อผิดพลาด: ' + error.message);
            return null;
        }
    },

    // Build system prompt for construction context
    buildSystemPrompt(context) {
        return `คุณคือ AI Assistant ผู้เชี่ยวชาญด้านงานก่อสร้างและแบบหล่อคอนกรีต (Formwork)

ความสามารถของคุณ:
1. แยกข้อมูลจากข้อความภาษาไทยหรืออังกฤษ
2. คำนวณปริมาณวัสดุและค่าใช้จ่าย
3. ให้คำแนะนำตามมาตรฐาน ACI 318 และ TIS
4. วิเคราะห์ความเหมาะสมของการใช้วัสดุ

ข้อมูลบริบท:
${JSON.stringify(context, null, 2)}

กรุณาตอบเป็นภาษาไทยที่เข้าใจง่าย และให้ข้อมูลในรูปแบบ JSON หากพบข้อมูลที่สามารถแยกได้

รูปแบบ JSON ที่ต้องการ:
{
    "message": "ข้อความตอบกลับ",
    "data": {
        "floorLevel": 1,
        "columnWidth": 40,
        "columnLength": 40,
        "columnHeight": 3.5,
        "columnCount": 24,
        ...
    },
    "insights": ["ข้อแนะนำ 1", "ข้อแนะนำ 2"]
}`;
    },

    // Call AI based on configured provider
    async callAI(systemPrompt, userMessage) {
        const provider = this.config.provider;
        const modelConfig = this.config.models[provider];

        if (provider === 'openrouter' || provider === 'kimi' || provider === 'glm') {
            return await this.callOpenAICompatibleAPI(modelConfig, systemPrompt, userMessage);
        } else if (provider === 'ollama') {
            return await this.callOllama(modelConfig, systemPrompt, userMessage);
        } else {
            throw new Error('Unsupported provider: ' + provider);
        }
    },

    // Call OpenAI-compatible APIs (OpenRouter, Kimi, GLM, etc.)
    async callOpenAICompatibleAPI(config, systemPrompt, userMessage) {
        try {
            // Use Cloudflare Worker as proxy to hide API keys
            const workerEndpoint = '/api/ai/chat';

            const response = await fetch(workerEndpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    provider: this.config.provider,
                    messages: [
                        { role: 'system', content: systemPrompt },
                        ...this.chatHistory.slice(-5), // Last 5 messages for context
                        { role: 'user', content: userMessage }
                    ]
                })
            });

            if (!response.ok) {
                throw new Error('API request failed: ' + response.statusText);
            }

            const result = await response.json();

            // Try to extract JSON from response
            const jsonMatch = result.message.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                try {
                    const parsed = JSON.parse(jsonMatch[0]);
                    return parsed;
                } catch (e) {
                    // If JSON parsing fails, return as plain message
                    return { message: result.message };
                }
            }

            return { message: result.message };
        } catch (error) {
            console.error('API Error:', error);
            // Fallback to pattern matching if API fails
            return this.fallbackExtraction(userMessage);
        }
    },

    // Call Ollama (local LLM)
    async callOllama(config, systemPrompt, userMessage) {
        try {
            const response = await fetch(config.endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: config.model,
                    prompt: `${systemPrompt}\n\nUser: ${userMessage}\nAssistant:`,
                    stream: false
                })
            });

            const result = await response.json();
            return { message: result.response };
        } catch (error) {
            console.error('Ollama Error:', error);
            return this.fallbackExtraction(userMessage);
        }
    },

    // Fallback extraction using regex patterns
    fallbackExtraction(message) {
        const data = {};
        const insights = [];

        // Extract numbers and dimensions from Thai/English text
        const patterns = {
            floor: /ชั้น\s*(\d+)|Floor\s*(\d+)/i,
            column: /เสา.*?(\d+)\s*[xX×]\s*(\d+)|Column.*?(\d+)\s*[xX×]\s*(\d+)/i,
            height: /สูง\s*([\d.]+)\s*ม|height\s*([\d.]+)/i,
            count: /(\d+)\s*ต้น|(\d+)\s*columns/i,
            area: /([\d.]+)\s*ตร\.?ม|area\s*([\d.]+)/i
        };

        // Floor
        const floorMatch = message.match(patterns.floor);
        if (floorMatch) {
            data.floorLevel = parseInt(floorMatch[1] || floorMatch[2]);
            insights.push(`✓ พบข้อมูลชั้น: ${data.floorLevel}`);
        }

        // Column dimensions
        const columnMatch = message.match(patterns.column);
        if (columnMatch) {
            data.columnWidth = parseInt(columnMatch[1] || columnMatch[3]);
            data.columnLength = parseInt(columnMatch[2] || columnMatch[4]);
            insights.push(`✓ พบขนาดเสา: ${data.columnWidth}x${data.columnLength} ซม.`);
        }

        // Height
        const heightMatch = message.match(patterns.height);
        if (heightMatch) {
            data.columnHeight = parseFloat(heightMatch[1] || heightMatch[2]);
            insights.push(`✓ พบความสูง: ${data.columnHeight} ม.`);
        }

        // Count
        const countMatch = message.match(patterns.count);
        if (countMatch) {
            data.columnCount = parseInt(countMatch[1] || countMatch[2]);
            insights.push(`✓ พบจำนวน: ${data.columnCount} ต้น`);
        }

        // Area
        const areaMatch = message.match(patterns.area);
        if (areaMatch) {
            data.slabArea = parseFloat(areaMatch[1] || areaMatch[2]);
            insights.push(`✓ พบพื้นที่: ${data.slabArea} ตร.ม.`);
        }

        const responseMessage = Object.keys(data).length > 0
            ? `เข้าใจแล้วครับ! ผมพบข้อมูล:\n${insights.join('\n')}\n\nต้องการให้คำนวณต่อหรือไม่?`
            : 'ขอโทษครับ ผมไม่สามารถแยกข้อมูลได้ กรุณาระบุให้ชัดเจนกว่านี้ เช่น "ชั้น 1 มีเสา 40x40 สูง 3.5 เมตร 24 ต้น"';

        return {
            message: responseMessage,
            data: Object.keys(data).length > 0 ? data : null,
            insights
        };
    },

    // Add message to UI
    addMessageToUI(role, message) {
        const container = document.getElementById('chat-messages');

        const messageDiv = document.createElement('div');
        messageDiv.className = 'flex items-start gap-2 fade-in';

        if (role === 'user') {
            messageDiv.innerHTML = `
                <div class="user-message ml-auto">
                    ${this.formatMessage(message)}
                </div>
                <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0">
                    <i class="fas fa-user text-sm"></i>
                </div>
            `;
        } else {
            messageDiv.innerHTML = `
                <div class="bg-purple-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0">
                    <i class="fas fa-robot text-sm"></i>
                </div>
                <div class="ai-message">
                    ${this.formatMessage(message)}
                </div>
            `;
        }

        container.appendChild(messageDiv);
        container.scrollTop = container.scrollHeight;
    },

    // Format message with line breaks and markdown-like syntax
    formatMessage(message) {
        return message
            .replace(/\n/g, '<br>')
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/`(.*?)`/g, '<code class="bg-gray-100 px-1 rounded">$1</code>');
    },

    // Show typing indicator
    showTyping() {
        const container = document.getElementById('chat-messages');
        const typingDiv = document.createElement('div');
        typingDiv.id = 'typing-indicator';
        typingDiv.className = 'flex items-start gap-2';
        typingDiv.innerHTML = `
            <div class="bg-purple-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0">
                <i class="fas fa-robot text-sm"></i>
            </div>
            <div class="bg-white p-3 rounded-lg shadow-sm">
                <div class="flex gap-1">
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0s"></div>
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.4s"></div>
                </div>
            </div>
        `;
        container.appendChild(typingDiv);
        container.scrollTop = container.scrollHeight;
    },

    // Hide typing indicator
    hideTyping() {
        const typing = document.getElementById('typing-indicator');
        if (typing) typing.remove();
    }
};

// Public function to send message
async function sendMessage() {
    const input = document.getElementById('chat-input');
    const message = input.value.trim();

    if (!message) return;

    // Get current form data as context
    const context = getCurrentFormData();

    // Send to AI
    await AIService.sendMessage(message, context);

    // Clear input
    input.value = '';
}

// Helper to send to AI (can be called from file-parser.js)
async function sendToAI(message, context = {}) {
    return await AIService.sendMessage(message, context);
}

// Get current form data
function getCurrentFormData() {
    return {
        projectName: document.getElementById('project-name')?.value || '',
        floorLevel: document.getElementById('floor-level')?.value || '',
        columnWidth: document.getElementById('column-width')?.value || '',
        columnLength: document.getElementById('column-length')?.value || '',
        columnHeight: document.getElementById('column-height')?.value || '',
        columnCount: document.getElementById('column-count')?.value || '',
        beamWidth: document.getElementById('beam-width')?.value || '',
        beamHeight: document.getElementById('beam-height')?.value || '',
        beamLength: document.getElementById('beam-length')?.value || '',
        slabArea: document.getElementById('slab-area')?.value || '',
        slabThickness: document.getElementById('slab-thickness')?.value || '',
        concreteFc: document.getElementById('concrete-fc')?.value || '',
        reuseRate: document.getElementById('reuse-rate')?.value || '',
        supportSets: document.getElementById('support-sets')?.value || ''
    };
}
