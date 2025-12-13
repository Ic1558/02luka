#!/usr/bin/env zsh
# Git Safety Aliases - Source this in .zshrc
# Add to .zshrc: source ~/02luka/.git_aliases.zsh

# Override 'git clean' with warning
function git() {
  if [[ "$1" == "clean" && "$PWD" =~ "02luka" ]]; then
    # Detected git clean in 02luka repo
    shift  # Remove 'clean' from args
    zsh ~/02luka/tools/git_clean_warning.zsh "$@"
  else
    # Normal git command
    command git "$@"
  fi
}

# Safe git clean aliases
alias git-safe-clean='zsh ~/02luka/tools/safe_git_clean.zsh -n'
alias git-safe-clean-force='zsh ~/02luka/tools/safe_git_clean.zsh -f'
