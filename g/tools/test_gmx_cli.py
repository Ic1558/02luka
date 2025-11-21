# g/tools/test_gmx_cli.py
"""
Unit tests for the GMX Command-Line Interface (gmx_cli.py).

This test suite validates the core functionality of the GMX CLI, including:
- Correctly invoking the Gemini API via GeminiConnector.
- Robustly parsing the direct JSON response from the Gemini API.
- Handling various failure modes (e.g., API errors, invalid JSON, connector unavailable).
- Ensuring the main function correctly orchestrates the full flow from prompt to dispatch.
"""
from __future__ import annotations

import unittest
import json
import sys
from unittest.mock import patch, MagicMock, call
from pathlib import Path

# --- Path Setup for Module Import ---
# Make the 'g' module importable from the test directory
# Mock google-generativeai before importing to avoid dependency issues
import sys
from unittest.mock import MagicMock, patch
import importlib.util

# Create mock module for google.generativeai before any imports
mock_google = MagicMock()
mock_genai = MagicMock()
sys.modules['google'] = mock_google
sys.modules['google.generativeai'] = mock_genai

# Mock importlib.util.find_spec to return a mock spec for google.generativeai
_original_find_spec = importlib.util.find_spec
def _mock_find_spec(name):
    if name == "google.generativeai":
        spec = MagicMock()
        spec.loader = MagicMock()
        return spec
    return _original_find_spec(name)
importlib.util.find_spec = _mock_find_spec

try:
    SCRIPT_DIR = Path(__file__).parent.resolve()
    # Assuming the structure is /g/tools/test_gmx_cli.py, root is 2 levels up
    PROJECT_ROOT = SCRIPT_DIR.parents[1]
    sys.path.insert(0, str(PROJECT_ROOT))
    
    # Patch gemini_connector's genai module before importing
    with patch('g.connectors.gemini_connector.genai', mock_genai):
        with patch('g.connectors.gemini_connector.genai_spec', MagicMock()):
            from g.tools.gmx_cli import run_gmx_mode, main
except (ImportError, IndexError) as e:
    print(f"FATAL: Could not set up test path. Ensure tests are run from 'g/tools/'. Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)


# --- Mock Data ---

# This is the raw JSON string the language model is expected to output.
GMX_PLAN_AS_STRING = json.dumps({
    "gmx_plan": {"intent": "refactor", "description": "Planned successfully."},
    "task_spec": {"intent": "refactor", "target_files": ["agents/liam/liam.py"]}
})

# This simulates the direct API response from GeminiConnector.generate_text()
# (no CLI wrapper - direct JSON string in response["text"])
MOCK_GEMINI_CONNECTOR_SUCCESS = {
    "text": GMX_PLAN_AS_STRING,  # Direct JSON string from API
    "model": "gemini-1.5-pro-latest",
    "usage": {
        "prompt_tokens": 100,
        "completion_tokens": 50,
        "total_tokens": 150
    }
}

# This is the final, parsed Python dictionary we expect `run_gmx_mode` to return.
EXPECTED_GMX_PLAN_RESULT = json.loads(GMX_PLAN_AS_STRING)


class TestGMXCLI(unittest.TestCase):
    """Test cases for the GMX CLI wrapper."""

    @patch('g.tools.gmx_cli.load_gmx_system_prompt', return_value="# GMX Mode")
    @patch('g.tools.gmx_cli.GeminiConnector')
    def test_run_gmx_mode_success_with_correct_parsing(self, mock_connector_class, mock_load_prompt):
        """
        Given a valid response from GeminiConnector,
        When run_gmx_mode is called,
        Then it should parse the JSON and return the GMX plan.
        """
        # Mock connector instance
        mock_connector = MagicMock()
        mock_connector.is_available.return_value = True
        mock_connector.generate_text.return_value = MOCK_GEMINI_CONNECTOR_SUCCESS
        mock_connector_class.return_value = mock_connector
        
        result = run_gmx_mode("Please refactor the dispatch module.")
        
        with self.subTest("Should return the correctly parsed JSON"):
            self.assertEqual(result, EXPECTED_GMX_PLAN_RESULT)
        
        with self.subTest("Should call connector.generate_text with correct parameters"):
            mock_connector.generate_text.assert_called_once()
            call_args = mock_connector.generate_text.call_args
            # Check that prompt contains system prompt and user input
            self.assertIn("GMX Mode", call_args[0][0])
            self.assertIn("Please refactor", call_args[0][0])
            # Check temperature is set for structured output
            self.assertEqual(call_args[1]["temperature"], 0.3)

    @patch('g.tools.gmx_cli.load_gmx_system_prompt', return_value="# GMX Mode")
    @patch('g.tools.gmx_cli.GeminiConnector')
    def test_gemini_connector_unavailable(self, mock_connector_class, mock_load_prompt):
        """
        Given the GeminiConnector is not available (no API key),
        When run_gmx_mode is called,
        Then it should return a structured error message.
        """
        # Mock connector instance that's not available
        mock_connector = MagicMock()
        mock_connector.is_available.return_value = False
        mock_connector_class.return_value = mock_connector
        
        result = run_gmx_mode("Test failure.")
        self.assertEqual(result.get('status'), 'ERROR')
        self.assertIn("not available", result.get('reason', ''))
        self.assertIn("GEMINI_API_KEY", result.get('reason', ''))

    @patch('g.tools.gmx_cli.load_gmx_system_prompt', return_value="# GMX Mode")
    @patch('g.tools.gmx_cli.GeminiConnector')
    def test_invalid_json_output(self, mock_connector_class, mock_load_prompt):
        """
        Given the Gemini API returns a non-JSON string,
        When run_gmx_mode is called,
        Then it should return a structured error about invalid JSON.
        """
        # Mock connector that returns invalid JSON
        mock_connector = MagicMock()
        mock_connector.is_available.return_value = True
        mock_connector.generate_text.return_value = {
            "text": "This is NOT JSON {",
            "model": "gemini-1.5-pro-latest",
            "usage": {"total_tokens": 10}
        }
        mock_connector_class.return_value = mock_connector
        
        result = run_gmx_mode("Test bad output.")
        self.assertEqual(result.get('status'), 'ERROR')
        self.assertIn("Invalid JSON from Gemini API", result.get('reason', ''))

    @patch('g.tools.gmx_cli.dispatch_work_order', return_value=Path('/tmp/test_wo.yaml'))
    @patch('g.tools.gmx_cli.run_gmx_mode', return_value=EXPECTED_GMX_PLAN_RESULT)
    @patch('argparse.ArgumentParser.parse_args', return_value=MagicMock(prompt="Test full run."))
    @patch('builtins.print')
    def test_main_dispatch_success(self, mock_print, mock_parse_args, mock_run_gmx, mock_dispatch):
        """
        Given a successful run of the GMX planner,
        When the main() function is called,
        Then it should call the dispatcher with the correct task_spec.
        """
        
        main()
        
        # Verify the dispatcher was called with the extracted task_spec
        mock_dispatch.assert_called_once_with(
            EXPECTED_GMX_PLAN_RESULT['task_spec'],
            source='gmx_cli'
        )
        
        # Verify specific success messages were printed in the correct order
        expected_prints_sequence = [
            call('\n✅ SUCCESS: Work Order Dispatched.'),
            call('   File: test_wo.yaml'),
            call('   Inbox: tmp') # Assuming Path('/tmp/test_wo.yaml') results in parent 'tmp'
        ]
        
        # Check if the sequence of expected calls is present in the actual calls in order
        # We need to find the starting point of our expected sequence in the full call_args_list
        call_list = mock_print.call_args_list
        
        # Find the index where our expected sequence starts
        start_index = -1
        for i in range(len(call_list) - len(expected_prints_sequence) + 1):
            if call_list[i] == expected_prints_sequence[0]:
                if call_list[i : i + len(expected_prints_sequence)] == expected_prints_sequence:
                    start_index = i
                    break
        
        self.assertNotEqual(start_index, -1, "Expected print sequence not found in mock_print calls.")


if __name__ == '__main__':
    unittest.main()
