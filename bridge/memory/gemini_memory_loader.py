#!/usr/bin/env python3
"""
Gemini Memory Loader
Phase 1 - Foundation Setup

Purpose: Load relevant context for Gemini tasks (protocols, recent work, file context)
Protocol: v3.2 compliant
Created: 2025-11-18
"""

import os
import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)


class GeminiMemoryLoader:
    """
    Loads context/memory for Gemini tasks.

    Provides:
    - Protocol references
    - Recent MLS lessons
    - File content (when needed for analysis)
    - System conventions
    """

    def __init__(self, base_dir: Optional[Path] = None):
        """
        Initialize memory loader.

        Args:
            base_dir: Base directory (defaults to $HOME/02luka)
        """
        self.base_dir = base_dir or Path.home() / "02luka"
        self.protocols_dir = self.base_dir / "g" / "docs"
        self.mls_file = self.base_dir / "g" / "knowledge" / "mls_lessons.jsonl"

        logger.info(f"Gemini memory loader initialized")

    def load_protocols(self) -> Dict[str, str]:
        """
        Load key protocol documents.

        Returns:
            dict mapping protocol name to content
        """
        protocols = {}

        protocol_files = [
            "CONTEXT_ENGINEERING_PROTOCOL_v3.md",
            "PATH_AND_TOOL_PROTOCOL.md"
        ]

        for protocol_name in protocol_files:
            protocol_path = self.protocols_dir / protocol_name

            if protocol_path.exists():
                try:
                    with open(protocol_path, 'r') as f:
                        protocols[protocol_name] = f.read()
                    logger.debug(f"Loaded protocol: {protocol_name}")
                except Exception as e:
                    logger.warning(f"Could not load protocol {protocol_name}: {e}")
            else:
                logger.warning(f"Protocol not found: {protocol_path}")

        return protocols

    def load_recent_mls(self, limit: int = 10, type_filter: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Load recent MLS lessons.

        Args:
            limit: Max number of lessons to load
            type_filter: Filter by type (solution, improvement, pattern, etc.)

        Returns:
            list of MLS lesson dicts
        """
        if not self.mls_file.exists():
            logger.warning(f"MLS file not found: {self.mls_file}")
            return []

        lessons = []

        try:
            with open(self.mls_file, 'r') as f:
                for line in f:
                    try:
                        lesson = json.loads(line.strip())
                        if type_filter and lesson.get('type') != type_filter:
                            continue
                        lessons.append(lesson)
                    except json.JSONDecodeError:
                        continue

            # Return most recent N lessons
            return lessons[-limit:]

        except Exception as e:
            logger.error(f"Error loading MLS lessons: {e}")
            return []

    def load_file_content(self, file_paths: List[str]) -> Dict[str, str]:
        """
        Load content from specified files.

        Args:
            file_paths: List of file paths (relative to base_dir or absolute)

        Returns:
            dict mapping file_path to content
        """
        contents = {}

        for file_path in file_paths:
            # Resolve path
            if file_path.startswith('$SOT/'):
                path = self.base_dir / file_path.replace('$SOT/', '')
            elif file_path.startswith('/'):
                path = Path(file_path)
            else:
                path = self.base_dir / file_path

            if path.exists() and path.is_file():
                try:
                    with open(path, 'r') as f:
                        contents[file_path] = f.read()
                    logger.debug(f"Loaded file: {file_path}")
                except Exception as e:
                    logger.warning(f"Could not load file {file_path}: {e}")
                    contents[file_path] = f"[Error loading file: {e}]"
            else:
                logger.warning(f"File not found: {path}")
                contents[file_path] = "[File not found]"

        return contents

    def get_system_conventions(self) -> Dict[str, Any]:
        """
        Get system conventions and standards.

        Returns:
            dict with conventions
        """
        return {
            "path_variable": "$SOT",
            "base_dir": str(self.base_dir),
            "forbidden_zones": [
                "/CLC/**",
                "/CLS/**",
                "$SOT/bridge/**",
                "$SOT/memory/**",
                "~/Library/LaunchAgents/*.plist"
            ],
            "coding_standards": {
                "python": {
                    "style": "PEP 8",
                    "docstrings": "Google style",
                    "type_hints": "encouraged"
                },
                "javascript": {
                    "style": "Standard JS",
                    "testing": "jest"
                },
                "shell": {
                    "interpreter": "zsh",
                    "error_handling": "set -euo pipefail"
                }
            }
        }

    def build_context(self, task_type: str, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Build complete context for a task.

        Args:
            task_type: Type of task (bulk_test_generation, etc.)
            input_data: Input parameters from work order

        Returns:
            dict with all relevant context
        """
        context = {
            "task_type": task_type,
            "system_conventions": self.get_system_conventions()
        }

        # Load protocols (always useful)
        if input_data.get('load_protocols', True):
            context["protocols"] = self.load_protocols()

        # Load recent MLS (for pattern reference)
        if input_data.get('load_mls', False):
            context["recent_lessons"] = self.load_recent_mls(
                limit=input_data.get('mls_limit', 10),
                type_filter=input_data.get('mls_type_filter')
            )

        # Load specific files (for analysis tasks)
        if 'target_files' in input_data:
            context["file_contents"] = self.load_file_content(input_data['target_files'])

        # Load additional context files
        if 'context_files' in input_data:
            context["context_files"] = self.load_file_content(input_data['context_files'])

        return context

    def summarize_context(self, context: Dict[str, Any]) -> str:
        """
        Create text summary of context for inclusion in prompt.

        Args:
            context: Context dict from build_context()

        Returns:
            Formatted string for prompt inclusion
        """
        parts = []

        # System conventions
        if 'system_conventions' in context:
            parts.append("## System Conventions")
            conv = context['system_conventions']
            parts.append(f"- Base directory: {conv['base_dir']}")
            parts.append(f"- Path variable: {conv['path_variable']}")
            parts.append(f"- Forbidden zones: {', '.join(conv['forbidden_zones'][:3])}...")

        # Protocols
        if 'protocols' in context:
            parts.append("\n## Available Protocols")
            for name in context['protocols'].keys():
                parts.append(f"- {name} (loaded)")

        # Recent lessons
        if 'recent_lessons' in context:
            parts.append(f"\n## Recent MLS Lessons ({len(context['recent_lessons'])})")
            for lesson in context['recent_lessons'][:3]:
                parts.append(f"- [{lesson.get('type')}] {lesson.get('title')}")

        # Files
        if 'file_contents' in context:
            parts.append(f"\n## Files Loaded ({len(context['file_contents'])})")
            for path in list(context['file_contents'].keys())[:3]:
                parts.append(f"- {path}")

        return "\n".join(parts)


def main():
    """Test memory loader."""
    logging.basicConfig(level=logging.INFO)

    loader = GeminiMemoryLoader()

    print("=== Testing Gemini Memory Loader ===\n")

    # Test protocol loading
    print("Loading protocols...")
    protocols = loader.load_protocols()
    print(f"✅ Loaded {len(protocols)} protocols")

    # Test MLS loading
    print("\nLoading recent MLS lessons...")
    lessons = loader.load_recent_mls(limit=5)
    print(f"✅ Loaded {len(lessons)} lessons")

    # Test system conventions
    print("\nLoading system conventions...")
    conventions = loader.get_system_conventions()
    print(f"✅ Loaded conventions (base: {conventions['base_dir']})")

    # Test context building
    print("\nBuilding test context...")
    context = loader.build_context(
        task_type="test",
        input_data={"load_protocols": True, "load_mls": True}
    )
    print(f"✅ Context built with {len(context)} components")

    # Test summary
    print("\nContext summary:")
    print(loader.summarize_context(context))

    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
