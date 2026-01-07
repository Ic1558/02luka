#!/usr/bin/env zsh
# Agent context detection for unified save gateway

detect_agent() {
    # Priority: explicit env -> known markers -> fallback
    if [[ -n "${AGENT_ID:-}" ]]; then
        echo "${AGENT_ID}"
        return
    fi
    if [[ -n "${GG_AGENT_ID:-}" ]]; then
        echo "${GG_AGENT_ID}"
        return
    fi
    if [[ -n "${CODEX_SESSION:-}" ]]; then
        echo "codex"
        return
    fi
    if [[ -n "${GEMINI_CLI:-}" ]]; then
        echo "gmx"
        return
    fi
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
        echo "CLS"
        return
    fi
    echo "unknown"
}

detect_environment() {
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
        echo "cursor"
        return
    fi
    if [[ -n "${SSH_TTY:-}" ]]; then
        echo "ssh"
        return
    fi
    echo "terminal"
}

export AGENT_ID=$(detect_agent)
export AGENT_ENV=$(detect_environment)
