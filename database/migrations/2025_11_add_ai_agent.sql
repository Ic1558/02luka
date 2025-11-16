-- Phase 22.2: Local AI Agent System
-- Adds intelligent task processing, analysis, and assistance

-- AI Agents Configuration
CREATE TABLE IF NOT EXISTS ai_agents (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    agent_type VARCHAR(100) NOT NULL CHECK (agent_type IN ('local_llm', 'openai', 'anthropic', 'custom')),

    -- Connection details
    endpoint_url TEXT,
    api_key TEXT,
    model_name VARCHAR(255),

    -- Capabilities
    capabilities TEXT[], -- ['context_analysis', 'material_recommendation', 'cost_estimation', 'code_generation']

    -- Configuration
    config JSONB DEFAULT '{}',
    max_tokens INTEGER DEFAULT 2000,
    temperature DECIMAL(3, 2) DEFAULT 0.7,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_online BOOLEAN DEFAULT FALSE,
    last_health_check TIMESTAMP,

    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Tasks Queue
CREATE TABLE IF NOT EXISTS ai_tasks (
    id SERIAL PRIMARY KEY,
    agent_id INTEGER REFERENCES ai_agents(id),

    -- Task details
    task_type VARCHAR(100) NOT NULL CHECK (task_type IN (
        'context_analysis',
        'zoning_extraction',
        'material_recommendation',
        'cost_estimation',
        'sketch_analysis',
        'document_parsing',
        'report_generation',
        'chat_completion',
        'code_generation'
    )),

    -- Related entities
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    context_id INTEGER REFERENCES contexts(id) ON DELETE CASCADE,
    sketch_id INTEGER REFERENCES sketches(id) ON DELETE CASCADE,

    -- Task payload
    prompt TEXT NOT NULL,
    input_data JSONB,
    instructions TEXT,

    -- Execution
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    priority INTEGER DEFAULT 5, -- 1-10, higher = more urgent

    -- Results
    result TEXT,
    result_data JSONB,
    error_message TEXT,

    -- Timing
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    processing_time_ms INTEGER,

    -- Request tracking
    requested_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Conversations (Chat history)
CREATE TABLE IF NOT EXISTS ai_conversations (
    id SERIAL PRIMARY KEY,
    agent_id INTEGER REFERENCES ai_agents(id),
    user_id INTEGER REFERENCES users(id),

    -- Conversation metadata
    title VARCHAR(255),
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    context_id INTEGER REFERENCES contexts(id) ON DELETE CASCADE,

    -- Configuration
    system_prompt TEXT,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Messages
CREATE TABLE IF NOT EXISTS ai_messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER REFERENCES ai_conversations(id) ON DELETE CASCADE,

    -- Message details
    role VARCHAR(50) NOT NULL CHECK (role IN ('system', 'user', 'assistant', 'function')),
    content TEXT NOT NULL,

    -- Function calling
    function_name VARCHAR(255),
    function_arguments JSONB,
    function_result JSONB,

    -- Metadata
    tokens_used INTEGER,
    model_used VARCHAR(255),
    processing_time_ms INTEGER,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Generated Insights
CREATE TABLE IF NOT EXISTS ai_insights (
    id SERIAL PRIMARY KEY,

    -- Related entity
    entity_type VARCHAR(50) NOT NULL CHECK (entity_type IN ('context', 'project', 'sketch', 'task')),
    entity_id INTEGER NOT NULL,

    -- Insight details
    insight_type VARCHAR(100) NOT NULL CHECK (insight_type IN (
        'site_analysis',
        'regulatory_compliance',
        'material_suggestion',
        'cost_optimization',
        'design_recommendation',
        'risk_assessment',
        'sustainability_score'
    )),

    title VARCHAR(255) NOT NULL,
    description TEXT,
    confidence_score DECIMAL(3, 2), -- 0.00 to 1.00

    -- Data
    data JSONB,

    -- Source
    agent_id INTEGER REFERENCES ai_agents(id),
    task_id INTEGER REFERENCES ai_tasks(id),

    -- Status
    is_relevant BOOLEAN DEFAULT TRUE,
    user_feedback VARCHAR(50) CHECK (user_feedback IN ('helpful', 'not_helpful', 'incorrect')),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Training Data (User feedback for fine-tuning)
CREATE TABLE IF NOT EXISTS ai_training_data (
    id SERIAL PRIMARY KEY,

    -- Input/Output pair
    input_prompt TEXT NOT NULL,
    expected_output TEXT NOT NULL,
    actual_output TEXT,

    -- Context
    task_type VARCHAR(100),
    entity_type VARCHAR(50),
    entity_id INTEGER,

    -- Quality
    quality_score INTEGER CHECK (quality_score BETWEEN 1 AND 5),
    is_approved BOOLEAN DEFAULT FALSE,

    -- Metadata
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_tasks_status ON ai_tasks(status);
CREATE INDEX IF NOT EXISTS idx_ai_tasks_agent ON ai_tasks(agent_id);
CREATE INDEX IF NOT EXISTS idx_ai_tasks_type ON ai_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_ai_tasks_priority ON ai_tasks(priority DESC);
CREATE INDEX IF NOT EXISTS idx_ai_tasks_project ON ai_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_project ON ai_conversations(project_id);
CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation ON ai_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_entity ON ai_insights(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_type ON ai_insights(insight_type);

-- Default local AI agent (Ollama)
INSERT INTO ai_agents (name, agent_type, endpoint_url, model_name, capabilities, is_active, config)
VALUES (
    'Ollama Local LLM',
    'local_llm',
    'http://localhost:11434',
    'llama3.2',
    ARRAY['context_analysis', 'material_recommendation', 'chat_completion', 'document_parsing'],
    TRUE,
    '{"stream": false, "temperature": 0.7, "top_p": 0.9}'::jsonb
) ON CONFLICT DO NOTHING;

-- Comments
COMMENT ON TABLE ai_agents IS 'Configuration for AI agents (local LLM, OpenAI, etc.)';
COMMENT ON TABLE ai_tasks IS 'Queue of AI tasks to be processed asynchronously';
COMMENT ON TABLE ai_conversations IS 'Chat conversations between users and AI assistants';
COMMENT ON TABLE ai_messages IS 'Individual messages in AI conversations';
COMMENT ON TABLE ai_insights IS 'AI-generated insights and recommendations';
COMMENT ON TABLE ai_training_data IS 'Training data collected from user interactions for model improvement';
