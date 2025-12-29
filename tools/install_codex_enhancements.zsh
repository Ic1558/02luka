#!/usr/bin/env zsh
# ======================================================================
# Codex Enhancement Stack Installer
# Purpose: Install all 4 enhancement repos to make Codex CLI competitive with CLC
# Usage: zsh ~/02luka/tools/install_codex_enhancements.zsh [phase]
#        zsh ~/02luka/tools/install_codex_enhancements.zsh all       # Install all phases
#        zsh ~/02luka/tools/install_codex_enhancements.zsh 1         # Install Phase 1 only
#        zsh ~/02luka/tools/install_codex_enhancements.zsh 1,2       # Install Phases 1+2
# ======================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directories
CODEX_BASE="${HOME}/02luka/tools/codex"
SKILLS_DIR="${HOME}/.codex/skills"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

# Logging
log_info() {
    echo "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Codex CLI installed
    if ! command -v codex &> /dev/null; then
        log_error "Codex CLI not found. Install first:"
        log_error "  brew install openai/tap/codex"
        log_error "  or: npm i -g @openai/codex"
        exit 1
    fi

    local codex_version=$(codex --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    log_success "Codex CLI $codex_version installed"

    # Check git
    if ! command -v git &> /dev/null; then
        log_error "Git not found. Install git first."
        exit 1
    fi

    # Create base directories
    mkdir -p "$CODEX_BASE"
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$CLAUDE_SKILLS_DIR"

    log_success "Prerequisites OK"
}

# Phase 1: Install official OpenAI skills
install_phase1() {
    log_info "=== Phase 1: Installing Official OpenAI Skills ==="

    local repo_url="https://github.com/openai/skills.git"
    local target_dir="$CODEX_BASE/skills"

    if [[ -d "$target_dir" ]]; then
        log_warning "openai/skills already exists at $target_dir"
        read "yn?Overwrite? (y/n): "
        if [[ "$yn" != "y" ]]; then
            log_info "Skipping Phase 1"
            return 0
        fi
        rm -rf "$target_dir"
    fi

    log_info "Cloning openai/skills..."
    git clone --depth 1 "$repo_url" "$target_dir"

    # Check for skill-installer
    if [[ -f "$target_dir/skill-installer" ]]; then
        chmod +x "$target_dir/skill-installer"
        log_success "skill-installer ready"

        # Install core skills
        log_info "Installing core skills..."
        cd "$target_dir"

        local core_skills=("code-review" "refactor" "test-generation" "debug-assistant")
        for skill in "${core_skills[@]}"; do
            if ./skill-installer "$skill" 2>&1 | grep -q "installed\|already exists"; then
                log_success "Installed skill: $skill"
            else
                log_warning "Skill $skill may not be available or already installed"
            fi
        done
    else
        log_warning "skill-installer not found. Manual skill installation may be required."
        log_info "Check $target_dir for available skills."
    fi

    log_success "Phase 1 complete: Official OpenAI skills installed"
}

# Phase 2: Install Claude Code -> Codex bridge
install_phase2() {
    log_info "=== Phase 2: Installing Claude Code <-> Codex Bridge ==="

    local repo_url="https://github.com/skills-directory/skill-codex.git"
    local target_dir="$CLAUDE_SKILLS_DIR/codex"

    if [[ -d "$target_dir" ]]; then
        log_warning "skill-codex already exists at $target_dir"
        read "yn?Overwrite? (y/n): "
        if [[ "$yn" != "y" ]]; then
            log_info "Skipping Phase 2"
            return 0
        fi
        rm -rf "$target_dir"
    fi

    log_info "Cloning skills-directory/skill-codex..."
    git clone --depth 1 "$repo_url" "$target_dir"

    # Check for SKILL.md
    if [[ -f "$target_dir/SKILL.md" ]]; then
        log_success "skill-codex installed at $target_dir"
        log_info "To use from Claude Code:"
        log_info "  /skills codex \"your task here\""
    else
        log_error "SKILL.md not found in $target_dir"
        return 1
    fi

    log_success "Phase 2 complete: Claude Code <-> Codex bridge installed"
}

# Phase 3: Install workflow automation (claude-codex-settings)
install_phase3() {
    log_info "=== Phase 3: Installing Workflow Automation ==="

    local repo_url="https://github.com/fcakyon/claude-codex-settings.git"
    local target_dir="$CODEX_BASE/claude-codex-settings"

    if [[ -d "$target_dir" ]]; then
        log_warning "claude-codex-settings already exists at $target_dir"
        read "yn?Overwrite? (y/n): "
        if [[ "$yn" != "y" ]]; then
            log_info "Skipping Phase 3"
            return 0
        fi
        rm -rf "$target_dir"
    fi

    log_info "Cloning fcakyon/claude-codex-settings..."
    git clone --depth 1 "$repo_url" "$target_dir"

    log_success "claude-codex-settings cloned to $target_dir"
    log_info ""
    log_info "To complete Phase 3 setup:"
    log_info "  1. In Claude Code CLI, run:"
    log_info "     /plugin marketplace add https://github.com/fcakyon/claude-codex-settings"
    log_info "     /plugin install claude-codex-settings"
    log_info ""
    log_info "  2. Or manually copy configs:"
    log_info "     cp $target_dir/.claude/settings.json ~/.claude/"
    log_info "     cp $target_dir/.codex/config.toml ~/.codex/"

    log_success "Phase 3 complete: Workflow automation files ready"
}

# Phase 4: Install research/reasoning skills
install_phase4() {
    log_info "=== Phase 4: Installing Research/Reasoning Skills ==="

    local repo_url="https://github.com/zechenzhangAGI/AI-research-SKILLs.git"
    local target_dir="$CODEX_BASE/ai-research-skills"

    if [[ -d "$target_dir" ]]; then
        log_warning "AI-research-SKILLs already exists at $target_dir"
        read "yn?Overwrite? (y/n): "
        if [[ "$yn" != "y" ]]; then
            log_info "Skipping Phase 4"
            return 0
        fi
        rm -rf "$target_dir"
    fi

    log_info "Cloning zechenzhangAGI/AI-research-SKILLs..."
    git clone --depth 1 "$repo_url" "$target_dir"

    log_success "AI-research-SKILLs cloned to $target_dir"
    log_info ""
    log_info "Available skill categories:"
    log_info "  - 01-model-architecture"
    log_info "  - 03-fine-tuning"
    log_info "  - 11-evaluation"
    log_info "  - 15-rag"
    log_info "  - 16-prompt-engineering"
    log_info ""
    log_info "To install specific skills:"
    log_info "  cd $target_dir"
    log_info "  ./skill-installer 15-rag  # Example: install RAG skills"

    log_success "Phase 4 complete: Research skills ready for selective installation"
}

# Install complementary tools
install_complementary() {
    log_info "=== Installing Complementary Tools ==="

    # Check and install aider
    if command -v aider &> /dev/null; then
        log_success "aider already installed ($(aider --version 2>&1 | head -1))"
    else
        log_info "Installing aider via pipx..."
        if command -v pipx &> /dev/null; then
            pipx install aider-chat
            log_success "aider installed"
        else
            log_warning "pipx not found. Install aider manually:"
            log_warning "  pipx install aider-chat"
        fi
    fi

    # Check and install ast-grep
    if command -v ast-grep &> /dev/null; then
        log_success "ast-grep already installed ($(ast-grep --version 2>&1 | head -1))"
    else
        log_info "Installing ast-grep via brew..."
        if command -v brew &> /dev/null; then
            brew install ast-grep
            log_success "ast-grep installed"
        else
            log_warning "brew not found. Install ast-grep manually:"
            log_warning "  brew install ast-grep"
        fi
    fi

    # Check and install pre-commit
    if command -v pre-commit &> /dev/null; then
        log_success "pre-commit already installed ($(pre-commit --version 2>&1))"
    else
        log_info "Installing pre-commit via brew..."
        if command -v brew &> /dev/null; then
            brew install pre-commit
            log_success "pre-commit installed"
        else
            log_warning "brew not found. Install pre-commit manually:"
            log_warning "  brew install pre-commit"
        fi
    fi

    # Check and install reviewdog
    if command -v reviewdog &> /dev/null; then
        log_success "reviewdog already installed ($(reviewdog --version 2>&1 | head -1))"
    else
        log_info "Installing reviewdog via brew..."
        if command -v brew &> /dev/null; then
            brew install reviewdog
            log_success "reviewdog installed"
        else
            log_warning "brew not found. Install reviewdog manually:"
            log_warning "  brew install reviewdog"
        fi
    fi

    log_success "Complementary tools check complete"
}

# Main installation flow
main() {
    local phases="${1:-all}"

    echo ""
    log_info "Codex Enhancement Stack Installer"
    log_info "=================================="
    echo ""

    check_prerequisites
    echo ""

    # Parse phases to install
    if [[ "$phases" == "all" ]]; then
        install_phase1
        echo ""
        install_phase2
        echo ""
        install_phase3
        echo ""
        install_phase4
        echo ""
        install_complementary
    else
        IFS=',' read -A phase_array <<< "$phases"
        for phase in "${phase_array[@]}"; do
            case "$phase" in
                1) install_phase1 ;;
                2) install_phase2 ;;
                3) install_phase3 ;;
                4) install_phase4 ;;
                comp|complementary) install_complementary ;;
                *)
                    log_error "Unknown phase: $phase"
                    log_info "Valid phases: 1, 2, 3, 4, comp, all"
                    exit 1
                    ;;
            esac
            echo ""
        done
    fi

    # Final summary
    echo ""
    log_success "======================================"
    log_success "Codex Enhancement Installation Complete"
    log_success "======================================"
    echo ""
    log_info "Installed components:"
    [[ "$phases" == "all" || "$phases" =~ "1" ]] && log_info "  ✓ Phase 1: Official OpenAI skills"
    [[ "$phases" == "all" || "$phases" =~ "2" ]] && log_info "  ✓ Phase 2: Claude Code <-> Codex bridge"
    [[ "$phases" == "all" || "$phases" =~ "3" ]] && log_info "  ✓ Phase 3: Workflow automation"
    [[ "$phases" == "all" || "$phases" =~ "4" ]] && log_info "  ✓ Phase 4: Research/reasoning skills"
    [[ "$phases" == "all" || "$phases" =~ "comp" ]] && log_info "  ✓ Complementary tools"
    echo ""
    log_info "Next steps:"
    log_info "  1. Test Codex with sample task:"
    log_info "     codex --skill code-review \"review ~/02luka/apps/api\""
    log_info ""
    log_info "  2. Update GG Orchestrator to use routing spec:"
    log_info "     See: ~/02luka/g/docs/CODEX_CLC_ROUTING_SPEC.md"
    log_info ""
    log_info "  3. Start routing non-locked tasks to Codex to save CLC quota"
    echo ""
    log_success "Target: 60-80% CLC quota savings"
    echo ""
}

# Run main function
main "$@"
