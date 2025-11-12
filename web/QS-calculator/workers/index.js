// Cloudflare Worker - AI Formwork Calculator Backend
// Handles API requests, AI proxy, and data storage

// Environment variables (set in Cloudflare Dashboard):
// - OPENROUTER_API_KEY
// - KIMI_API_KEY
// - GLM_API_KEY
// - DATABASE_URL (optional - D1 or KV)

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const path = url.pathname;

        // CORS headers
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
        };

        // Handle CORS preflight
        if (request.method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }

        try {
            // Routes
            if (path === '/health') {
                return jsonResponse({ status: 'ok', timestamp: Date.now() }, corsHeaders);
            }

            if (path === '/api/ai/chat' && request.method === 'POST') {
                return await handleAIChat(request, env, corsHeaders);
            }

            if (path === '/api/calculations' && request.method === 'POST') {
                return await handleSaveCalculation(request, env, corsHeaders);
            }

            if (path === '/api/calculations' && request.method === 'GET') {
                return await handleGetCalculations(request, env, corsHeaders);
            }

            // 404 Not Found
            return jsonResponse({ error: 'Not Found' }, corsHeaders, 404);
        } catch (error) {
            console.error('Worker Error:', error);
            return jsonResponse({ error: error.message }, corsHeaders, 500);
        }
    }
};

// Handle AI Chat
async function handleAIChat(request, env, corsHeaders) {
    try {
        const body = await request.json();
        const { message, messages, context, provider = 'openrouter' } = body;

        // Build messages array
        const chatMessages = messages || [
            {
                role: 'system',
                content: buildSystemPrompt(context)
            },
            {
                role: 'user',
                content: message
            }
        ];

        // Call appropriate AI provider
        let response;
        switch (provider) {
            case 'openrouter':
                response = await callOpenRouter(chatMessages, env);
                break;
            case 'kimi':
                response = await callKimi(chatMessages, env);
                break;
            case 'glm':
                response = await callGLM(chatMessages, env);
                break;
            default:
                throw new Error('Unsupported provider: ' + provider);
        }

        return jsonResponse(response, corsHeaders);
    } catch (error) {
        console.error('AI Chat Error:', error);
        return jsonResponse({ error: error.message }, corsHeaders, 500);
    }
}

// Call OpenRouter API
async function callOpenRouter(messages, env) {
    const apiKey = env.OPENROUTER_API_KEY || '';

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`,
            'HTTP-Referer': 'https://www.theedges.work',
            'X-Title': 'PD17 AI Formwork Calculator'
        },
        body: JSON.stringify({
            model: 'deepseek/deepseek-chat', // Free model
            messages,
            temperature: 0.7,
            max_tokens: 1000
        })
    });

    if (!response.ok) {
        const error = await response.text();
        throw new Error(`OpenRouter API Error: ${error}`);
    }

    const data = await response.json();
    const message = data.choices[0].message.content;

    return { message, provider: 'openrouter' };
}

// Call Kimi API
async function callKimi(messages, env) {
    const apiKey = env.KIMI_API_KEY || '';

    const response = await fetch('https://api.moonshot.cn/v1/chat/completions', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
            model: 'moonshot-v1-8k',
            messages,
            temperature: 0.7
        })
    });

    if (!response.ok) {
        const error = await response.text();
        throw new Error(`Kimi API Error: ${error}`);
    }

    const data = await response.json();
    const message = data.choices[0].message.content;

    return { message, provider: 'kimi' };
}

// Call GLM-4 API
async function callGLM(messages, env) {
    const apiKey = env.GLM_API_KEY || '';

    const response = await fetch('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
            model: 'glm-4-flash',
            messages,
            temperature: 0.7
        })
    });

    if (!response.ok) {
        const error = await response.text();
        throw new Error(`GLM API Error: ${error}`);
    }

    const data = await response.json();
    const message = data.choices[0].message.content;

    return { message, provider: 'glm' };
}

// Build system prompt
function buildSystemPrompt(context) {
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
        "columnCount": 24
    },
    "insights": ["ข้อแนะนำ 1", "ข้อแนะนำ 2"]
}`;
}

// Handle Save Calculation
async function handleSaveCalculation(request, env, corsHeaders) {
    try {
        const data = await request.json();

        // Save to Cloudflare KV (if available)
        if (env.CALCULATIONS_KV) {
            const key = `calc_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
            await env.CALCULATIONS_KV.put(key, JSON.stringify(data), {
                metadata: {
                    projectName: data.projectName,
                    timestamp: new Date().toISOString()
                }
            });

            return jsonResponse({ success: true, id: key }, corsHeaders);
        }

        // Or save to D1 (SQLite) if configured
        if (env.DB) {
            const stmt = env.DB.prepare(
                'INSERT INTO calculations (data, project_name, created_at) VALUES (?, ?, ?)'
            );
            await stmt.bind(JSON.stringify(data), data.projectName, new Date().toISOString()).run();

            return jsonResponse({ success: true }, corsHeaders);
        }

        // No storage configured
        return jsonResponse({ success: false, message: 'No storage configured' }, corsHeaders);
    } catch (error) {
        console.error('Save Error:', error);
        return jsonResponse({ error: error.message }, corsHeaders, 500);
    }
}

// Handle Get Calculations
async function handleGetCalculations(request, env, corsHeaders) {
    try {
        const url = new URL(request.url);
        const limit = parseInt(url.searchParams.get('limit') || '10');

        const calculations = [];

        // Get from KV
        if (env.CALCULATIONS_KV) {
            const list = await env.CALCULATIONS_KV.list({ limit });

            for (const key of list.keys) {
                const value = await env.CALCULATIONS_KV.get(key.name);
                if (value) {
                    calculations.push({
                        id: key.name,
                        ...JSON.parse(value),
                        metadata: key.metadata
                    });
                }
            }
        }

        // Or get from D1
        if (env.DB) {
            const { results } = await env.DB.prepare(
                'SELECT * FROM calculations ORDER BY created_at DESC LIMIT ?'
            ).bind(limit).all();

            calculations.push(...results.map(row => ({
                id: row.id,
                ...JSON.parse(row.data),
                created_at: row.created_at
            })));
        }

        return jsonResponse({ calculations }, corsHeaders);
    } catch (error) {
        console.error('Get Error:', error);
        return jsonResponse({ error: error.message }, corsHeaders, 500);
    }
}

// JSON Response helper
function jsonResponse(data, headers = {}, status = 200) {
    return new Response(JSON.stringify(data), {
        status,
        headers: {
            'Content-Type': 'application/json',
            ...headers
        }
    });
}
