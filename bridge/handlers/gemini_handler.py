#!/usr/bin/env python3
"""
Gemini Task Handler
Phase 1 - Foundation Setup

Purpose: Process work orders from bridge/inbox/GEMINI/, execute via Gemini API
Protocol: v3.2 compliant
Created: 2025-11-18
"""

import os
import sys
import yaml
import json
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

# Add parent directories to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "g" / "connectors"))

from gemini_connector import GeminiConnector, run_gemini_task

logger = logging.getLogger(__name__)


def handle(task: Dict[str, Any]) -> Dict[str, Any]:
    """
    Normalize incoming Gemini tasks and call gemini_connector.
    """
    task_type = task.get("task_type", "code_transform")
    payload = {
        "files": task.get("files", []),
        "instructions": task.get("instructions", ""),
        "context": task.get("context", {}),
    }

    result = run_gemini_task(task_type, payload)

    return {
        "ok": bool(result.get("ok")),
        "task_type": task_type,
        "result": result,
        # TODO: Phase 3 WO routing will integrate inbox/outbox bridging here.
    }


class GeminiHandler:
    """
    Handles work orders for Gemini agent.

    Process:
    1. Monitor /bridge/inbox/GEMINI/ for work orders
    2. Load context via memory loader
    3. Execute task via Gemini API
    4. Write result to /bridge/outbox/GEMINI/
    """

    def __init__(self, base_dir: Optional[Path] = None):
        """
        Initialize handler.

        Args:
            base_dir: Base directory (defaults to $HOME/02luka)
        """
        self.base_dir = base_dir or Path.home() / "02luka"
        self.inbox = self.base_dir / "bridge" / "inbox" / "GEMINI"
        self.outbox = self.base_dir / "bridge" / "outbox" / "GEMINI"

        # Create directories
        self.inbox.mkdir(parents=True, exist_ok=True)
        self.outbox.mkdir(parents=True, exist_ok=True)

        # Initialize connector
        self.connector = GeminiConnector()

        logger.info(f"Gemini handler initialized")
        logger.info(f"  Inbox: {self.inbox}")
        logger.info(f"  Outbox: {self.outbox}")

    def process_work_order(self, wo_path: Path) -> bool:
        """
        Process a single work order.

        Args:
            wo_path: Path to work order YAML file

        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info(f"Processing work order: {wo_path.name}")

            # Load work order
            with open(wo_path, 'r') as f:
                wo = yaml.safe_load(f)

            wo_id = wo.get('wo_id', wo_path.stem)
            task_type = wo.get('task_type', 'unknown')

            logger.info(f"  WO ID: {wo_id}")
            logger.info(f"  Task type: {task_type}")

            # Check if connector is available
            if not self.connector.is_available():
                logger.error("Gemini connector not available")
                self._write_error_result(wo_id, "Gemini API not configured")
                return False

            # Build prompt based on task type
            prompt = self._build_prompt(wo)

            if not prompt:
                logger.error(f"Could not build prompt for task type: {task_type}")
                self._write_error_result(wo_id, f"Unsupported task type: {task_type}")
                return False

            # Execute via Gemini API
            logger.info(f"  Executing via Gemini API...")
            result = self.connector.generate_text(
                prompt=prompt,
                temperature=wo.get('temperature', 0.7),
                max_output_tokens=wo.get('max_output_tokens', 2048)
            )

            if not result:
                logger.error("Gemini API call failed")
                self._write_error_result(wo_id, "Gemini API call failed")
                return False

            # Write result
            self._write_success_result(wo_id, wo, result)

            logger.info(f"  ✅ Work order completed ({result['usage']['total_tokens']} tokens)")
            return True

        except Exception as e:
            logger.error(f"Error processing work order: {e}")
            self._write_error_result(wo.get('wo_id', wo_path.stem), str(e))
            return False

    def _build_prompt(self, wo: Dict[str, Any]) -> Optional[str]:
        """
        Build prompt from work order.

        Args:
            wo: Work order dict

        Returns:
            Prompt string or None if cannot build
        """
        task_type = wo.get('task_type')
        input_data = wo.get('input', {})

        if task_type == 'bulk_test_generation':
            return self._build_test_generation_prompt(input_data)
        elif task_type == 'multi_file_analysis':
            return self._build_analysis_prompt(input_data)
        elif task_type == 'script_generation':
            return self._build_script_generation_prompt(input_data)
        elif task_type == 'doc_generation':
            return self._build_doc_generation_prompt(input_data)
        else:
            # Generic prompt
            return input_data.get('prompt', None)

    def _build_test_generation_prompt(self, input_data: Dict[str, Any]) -> str:
        """Build prompt for test generation task."""
        target_files = input_data.get('target_files', [])
        framework = input_data.get('test_framework', 'jest')
        coverage = input_data.get('coverage_target', 80)

        prompt = f"""You are a test generation specialist. Generate comprehensive test suite.

**Task:** Generate {framework} tests
**Target files:** {', '.join(target_files)}
**Coverage target:** {coverage}%

**Requirements:**
1. Complete test cases (no TODOs)
2. Cover happy paths and edge cases
3. Include setup/teardown if needed
4. Follow {framework} best practices
5. Add inline comments for complex assertions

**Output format:**
Complete, runnable test file(s) with:
- Describe blocks for each function/component
- It blocks for each test case
- Mock setup if external dependencies
- Clear test descriptions

Generate the complete test suite now:"""

        return prompt

    def _build_analysis_prompt(self, input_data: Dict[str, Any]) -> str:
        """Build prompt for code analysis task."""
        return f"""Analyze the following codebase for patterns and issues:

{json.dumps(input_data, indent=2)}

Provide a structured analysis report with:
1. Summary of findings
2. Pattern categories
3. Recommendations
4. Specific files/locations needing attention
"""

    def _build_script_generation_prompt(self, input_data: Dict[str, Any]) -> str:
        """Build prompt for script generation task."""
        return f"""Generate production-ready scripts based on these specifications:

{json.dumps(input_data, indent=2)}

Requirements:
- Complete error handling
- Usage documentation
- Example invocations
- Proper shebangs and permissions
"""

    def _build_doc_generation_prompt(self, input_data: Dict[str, Any]) -> str:
        """Build prompt for documentation generation."""
        return f"""Generate comprehensive documentation:

{json.dumps(input_data, indent=2)}

Include:
- Overview/purpose
- Usage examples
- API reference (if applicable)
- Configuration options
- Troubleshooting section
"""

    def _write_success_result(self, wo_id: str, wo: Dict[str, Any], result: Dict[str, Any]):
        """Write successful result to outbox."""
        output_file = self.outbox / f"{wo_id}_result.yaml"

        result_data = {
            'wo_id': wo_id,
            'status': 'success',
            'completed_at': datetime.utcnow().isoformat() + 'Z',
            'output': result['text'],
            'tokens_used': result['usage']['total_tokens'],
            'model': result['model'],
            'summary': f"Task completed successfully ({result['usage']['total_tokens']} tokens)",
            'next_steps': wo.get('next_steps', [
                "Review generated output",
                "Test/validate result",
                "Integrate into codebase"
            ])
        }

        with open(output_file, 'w') as f:
            yaml.dump(result_data, f, default_flow_style=False)

        logger.info(f"  Result written: {output_file}")

    def _write_error_result(self, wo_id: str, error: str):
        """Write error result to outbox."""
        output_file = self.outbox / f"{wo_id}_result.yaml"

        result_data = {
            'wo_id': wo_id,
            'status': 'failed',
            'completed_at': datetime.utcnow().isoformat() + 'Z',
            'error': error,
            'summary': f"Task failed: {error}"
        }

        with open(output_file, 'w') as f:
            yaml.dump(result_data, f, default_flow_style=False)

        logger.warning(f"  Error result written: {output_file}")

    def process_inbox(self) -> int:
        """
        Process all work orders in inbox.

        Returns:
            Number of work orders processed
        """
        count = 0
        for wo_file in self.inbox.glob("WO_*.yaml"):
            if self.process_work_order(wo_file):
                # Move to processed
                processed_dir = self.inbox / "processed"
                processed_dir.mkdir(exist_ok=True)
                wo_file.rename(processed_dir / wo_file.name)
                count += 1

        return count


def main():
    """Main entry point for CLI usage."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    handler = GeminiHandler()

    logger.info("Starting Gemini handler...")
    count = handler.process_inbox()
    logger.info(f"Processed {count} work orders")

    return 0 if count >= 0 else 1


if __name__ == "__main__":
    sys.exit(main())
