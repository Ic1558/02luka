# Setting Up Local AI (Ollama) for ProBuild

ProBuild includes built-in AI capabilities powered by local LLMs (Large Language Models) via Ollama. This keeps your data private and works completely offline.

## Quick Start

### 1. Install Ollama

**macOS:**
```bash
brew install ollama
```

**Linux:**
```bash
curl -fsSL https://ollama.com/install.sh -o /tmp/ollama_install.sh
sh /tmp/ollama_install.sh  # Inspect the script before executing; no piping allowed
```

**Windows:**
Download from https://ollama.com/download/windows

### 2. Start Ollama Service

```bash
ollama serve
```

This starts the Ollama API server on `http://localhost:11434`

### 3. Download a Model

**Recommended for architecture work:**
```bash
# Llama 3.2 (3B parameters - fast, good for chat)
ollama pull llama3.2

# Llama 3.1 (8B parameters - slower but more capable)
ollama pull llama3.1:8b

# Mistral (7B parameters - excellent for technical tasks)
ollama pull mistral
```

### 4. Test the Integration

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Test a completion
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [{"role": "user", "content": "Hello!"}],
  "stream": false
}'
```

### 5. Configure ProBuild API

Update your `.env` file:
```env
OLLAMA_ENDPOINT=http://localhost:11434
OLLAMA_MODEL=llama3.2
```

### 6. Start ProBuild

```bash
# Start backend
cd api
npm run dev

# Start frontend (in another terminal)
cd webapp
npm run dev
```

## AI Features in ProBuild

### 1. **AI Assistant Chat**
- Click the floating AI button (bottom-right)
- Ask questions about your projects
- Get architecture and construction advice
- Context-aware responses based on current page

### 2. **Context Analysis**
- Open any Design Context
- Click "Analyze" in the AI Site Analysis card
- Get automated insights about:
  - Site opportunities
  - Potential constraints
  - Design recommendations
  - Regulatory compliance
  - Sustainability suggestions

### 3. **Smart Task Processing** (Background)
- Zoning document extraction
- Material recommendations
- Cost estimations
- Sketch analysis
- Report generation

## Available AI Capabilities

| Feature | Description | Model Recommended |
|---------|-------------|-------------------|
| **Context Analysis** | Analyzes site conditions, zoning, and constraints | llama3.1:8b |
| **Material Recommendations** | Suggests materials based on project requirements | mistral |
| **Cost Estimation** | Estimates project costs | llama3.1:8b |
| **Document Parsing** | Extracts data from PDFs and documents | llama3.2 |
| **Chat Assistant** | General Q&A about projects | llama3.2 |
| **Report Generation** | Creates formatted reports | mistral |

## Performance Tuning

### For Faster Responses:
```env
OLLAMA_MODEL=llama3.2  # Smaller, faster model
```

### For Better Quality:
```env
OLLAMA_MODEL=llama3.1:8b  # Larger, more capable model
```

### Adjust Temperature (Creativity):
```javascript
// In api/routes/ai.js
temperature: 0.7  // Default (balanced)
temperature: 0.3  // More focused, factual
temperature: 1.0  // More creative
```

## Troubleshooting

### AI Assistant Shows "Offline"

1. **Check if Ollama is running:**
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. **Restart Ollama:**
   ```bash
   pkill ollama
   ollama serve
   ```

3. **Check the model is installed:**
   ```bash
   ollama list
   ```

### Slow Responses

1. **Use a smaller model:**
   ```bash
   ollama pull llama3.2  # 3B params - faster
   ```

2. **Check system resources:**
   - Minimum 8GB RAM recommended
   - 16GB+ for larger models

3. **Limit concurrent requests:**
   - AI tasks are queued automatically
   - Only one task processes at a time

### Model Not Found

```bash
# List installed models
ollama list

# Pull the default model
ollama pull llama3.2
```

## Alternative: Use OpenAI Instead

If you prefer cloud AI instead of local:

1. **Get an OpenAI API key:** https://platform.openai.com/api-keys

2. **Update `.env`:**
   ```env
   OPENAI_API_KEY=sk-...your-key-here...
   ```

3. **Modify `api/routes/ai.js`:**
   ```javascript
   // Change agent type to 'openai'
   agent_type: 'openai'
   model_name: 'gpt-4o-mini'  // or 'gpt-4'
   ```

## Model Recommendations by Use Case

### Architecture Firms
- **Primary:** `llama3.1:8b` (best balance)
- **Backup:** `mistral` (technical tasks)

### Interior Design
- **Primary:** `llama3.2` (fast, creative)
- **Backup:** `mistral` (material knowledge)

### Construction Management
- **Primary:** `llama3.1:8b` (calculations, estimates)
- **Backup:** `llama3.2` (quick queries)

### Small/Personal Projects
- **Primary:** `llama3.2` (low resource usage)

## Resource Usage

| Model | RAM | Speed | Quality | Best For |
|-------|-----|-------|---------|----------|
| llama3.2 (3B) | 4GB | Fast | Good | Chat, quick analysis |
| llama3.1 (8B) | 8GB | Medium | Better | Technical analysis |
| mistral (7B) | 6GB | Medium | Excellent | Material/cost work |
| llama3.1 (70B) | 40GB+ | Slow | Best | Complex reasoning |

## Privacy & Security

✅ **All AI processing happens locally**
✅ **No data sent to external servers**
✅ **Works completely offline**
✅ **HIPAA/GDPR compliant by default**
✅ **Your project data stays on your machine**

## Updates

Keep Ollama and models up to date:

```bash
# Update Ollama
brew upgrade ollama  # macOS

# Update models
ollama pull llama3.2
ollama pull mistral
```

## Support

- **Ollama Docs:** https://ollama.com/docs
- **Model Library:** https://ollama.com/library
- **ProBuild Issues:** https://github.com/Ic1558/02luka/issues

---

**Pro Tip:** Run Ollama as a background service:

```bash
# macOS/Linux (systemd)
ollama serve &

# Or use launchd (macOS)
# Create ~/Library/LaunchAgents/com.ollama.serve.plist
```

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
