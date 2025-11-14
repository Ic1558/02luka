# Architecture Overview

## System Components

### 1. CLS (Command Learning System)
**Purpose**: Capture and analyze terminal commands for workflow optimization

**Components**:
- `~/.zshrc.d/02luka-cls-hooks.zsh` - Shell integration hooks
- `tools/cls_learn.zsh` - Command capture
- `tools/cls_detect_patterns.zsh` - Pattern analysis
- `memory/cls/learning_db.jsonl` - Command database

**Flow**:
```
Terminal → hooks → cls_learn → learning_db.jsonl → pattern detection
```

### 2. GitHub Actions Workflows

**Workflows**:
- `ci.yml` - Continuous integration testing
- `daily-proof.yml` - Daily validation (uses artifact@v4)
- `docs-publish.yml` - Documentation deployment
- `pages.yml` - GitHub Pages deployment

**Artifact Storage**: All using `actions/upload-artifact@v4`

### 3. Documentation Publisher

**Purpose**: Auto-publish documentation to GitHub Pages

**Components**:
- `run/publish_docs.cjs` - Doc generator
- `dist/docs/` - Generated output
- GitHub Pages deployment

### 4. Ops Monitoring

**Components**:
- `g/reports/` - Operational reports
- `g/metrics/` - Performance metrics
- `g/telemetry/` - System telemetry

## Data Flow

```
User Commands → CLS → Learning DB
                 ↓
            Pattern Detection
                 ↓
          Ops Reports → GitHub Actions → Deployment
```

## Integration Points

- **Git**: Version control and CI/CD trigger
- **GitHub Actions**: Automated testing and deployment
- **GitHub Pages**: Documentation hosting
- **Shell (zsh)**: Command capture integration
