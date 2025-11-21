import unittest
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from g.core.impact_assessment_v35 import (
    assess_deploy_impact,
    impact_report_to_apio_payload,
    ChangeSummary,
    ImpactReport
)


class TestImpactAssessmentV35(unittest.TestCase):
    """Unit tests for Impact Assessment Module V3.5"""

    def test_minimal_deploy_single_file(self):
        """Test minimal deploy with single file change"""
        summary: ChangeSummary = {
            "feature_name": "fix_typo",
            "description": "Fix typo in README",
            "files_touched": ["README.md"],
            "components_affected": ["docs"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["deploy_type"], "minimal")
        self.assertEqual(report["risk"], "low")
        self.assertFalse(report["requires_rollback"])
        self.assertFalse(report["update_sot"])
        self.assertFalse(report["update_ai_context"])
        self.assertFalse(report["notify_workers"])

    def test_minimal_deploy_two_files(self):
        """Test minimal deploy with two files"""
        summary: ChangeSummary = {
            "feature_name": "update_docs",
            "description": "Update documentation",
            "files_touched": ["README.md", "CHANGELOG.md"],
            "components_affected": ["docs"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["deploy_type"], "minimal")
        self.assertEqual(report["risk"], "low")

    def test_full_deploy_three_files(self):
        """Test full deploy with three files"""
        summary: ChangeSummary = {
            "feature_name": "refactor_tools",
            "description": "Refactor tools",
            "files_touched": ["tool1.py", "tool2.py", "tool3.py"],
            "components_affected": ["tools"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["deploy_type"], "full")
        self.assertTrue(report["requires_rollback"])

    def test_full_deploy_protocol_change(self):
        """Test full deploy with protocol change"""
        summary: ChangeSummary = {
            "feature_name": "update_apio",
            "description": "Update AP/IO protocol",
            "files_touched": ["ap_io_v31.py"],
            "components_affected": ["protocol"],
            "touches_governance": False,
            "changes_protocol": True,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["deploy_type"], "full")
        self.assertEqual(report["risk"], "high")
        self.assertTrue(report["requires_rollback"])
        self.assertTrue(report["update_sot"])
        self.assertTrue(report["update_ai_context"])
        self.assertTrue(report["notify_workers"])

    def test_full_deploy_executor_change(self):
        """Test full deploy with executor change"""
        summary: ChangeSummary = {
            "feature_name": "update_executor",
            "description": "Update executor logic",
            "files_touched": ["executor.py"],
            "components_affected": ["executor"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": True,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["deploy_type"], "full")
        self.assertEqual(report["risk"], "high")
        self.assertTrue(report["update_sot"])

    def test_full_deploy_new_subsystem(self):
        """Test full deploy with new subsystem"""
        summary: ChangeSummary = {
            "feature_name": "add_memory_hub",
            "description": "Add memory hub subsystem",
            "files_touched": ["memory_hub.py", "memory_config.yaml"],
            "components_affected": ["memory"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": True,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["deploy_type"], "full")
        self.assertEqual(report["risk"], "medium")
        self.assertTrue(report["update_sot"])
        self.assertTrue(report["update_ai_context"])
        self.assertTrue(report["notify_workers"])

    def test_risk_level_high(self):
        """Test high risk level detection"""
        summary: ChangeSummary = {
            "feature_name": "update_governance",
            "description": "Update governance",
            "files_touched": ["02luka.md"],
            "components_affected": ["governance"],
            "touches_governance": True,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["risk"], "high")
        self.assertEqual(report["deploy_type"], "full")

    def test_risk_level_medium(self):
        """Test medium risk level detection"""
        summary: ChangeSummary = {
            "feature_name": "update_schema",
            "description": "Update schema",
            "files_touched": ["schema.json"],
            "components_affected": ["schema"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": True,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)

        self.assertEqual(report["risk"], "medium")

    def test_apio_payload_generation(self):
        """Test AP/IO payload generation"""
        summary: ChangeSummary = {
            "feature_name": "test_feature",
            "description": "Test description",
            "files_touched": ["file1.py"],
            "components_affected": ["component1"],
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }

        report = assess_deploy_impact(summary)
        payload = impact_report_to_apio_payload(summary, report)

        self.assertEqual(payload["feature_name"], "test_feature")
        self.assertEqual(payload["description"], "Test description")
        self.assertEqual(payload["deploy_type"], "minimal")
        self.assertEqual(payload["risk"], "low")
        self.assertIn("files_changed", payload)
        self.assertIn("components_affected", payload)


if __name__ == '__main__':
    unittest.main()
