# 02luka System Map (auto)

## Roots & Roles
- g/: infra tools, validators, helpers
- run/: runtime artifacts, status, reports
- boss/: your workspace (inbox/sent/deliverables/dropbox)
- f/ai_context/: resolver mapping & context data
- Forbidden for AI writes: a/, c/, o/, s/ (human-only)

## Tree (depth 2)
    .
    ├── .codex
    │   ├── CONTEXT_SEED.md
    │   ├── GUARDRAILS.md
    │   ├── PATH_KEYS.md
    │   ├── PREPROMPT.md
    │   ├── TASK_RECIPES.md
    │   ├── codex.env.yml
    │   └── preflight.sh
    ├── .devcontainer
    │   └── devcontainer.json
    ├── .env.example
    ├── .github
    │   ├── PULL_REQUEST_TEMPLATE.md
    │   └── workflows
    ├── .gitignore
    ├── .nojekyll
    ├── 404.html
    ├── CODEx_INSTRUCTIONS.md
    ├── DEPLOY.md
    ├── README.md
    ├── auto_tunnel.zsh
    ├── boss
    │   ├── deliverables
    │   ├── dropbox
    │   ├── inbox
    │   └── sent
    ├── boss-api
    │   ├── .env.sample
    │   └── server.js
    ├── boss-ui
    │   └── index.html
    ├── cleanup_home_backups.sh
    ├── contracts
    │   ├── chat.request.example.json
    │   ├── chat.response.example.json
    │   └── mcp-tools.schema.json
    ├── docs
    │   └── architecture.md
    ├── expose_gateways.sh
    ├── f
    │   ├── ai_context
    │   └── bridge
    ├── g
    │   ├── reports
    │   └── tools
    ├── index.html
    ├── index_backup.html
    ├── index_optimized.html
    ├── luka_working.html
    ├── output
    │   └── reports
    ├── run
    │   ├── auto_context
    │   ├── change_units
    │   ├── system_status.v2.json
    │   └── tickets
    ├── run_local.sh
    ├── setup
    │   └── post_setup.sh
    ├── tunnel
    └── verify_system.sh
    
    27 directories, 35 files

## Known Services
- boss-api:     boss-api/.env.sample:2:PORT=4000
    boss-api/server.js:7:PORT = Number(process.env.PORT || 4000

## Data Flow
dropbox → (router) → inbox/sent (query/answer) → deliverables
