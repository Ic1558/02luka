#!/usr/bin/env python3
"""
Test Runner for Governance v5 Test Suites (Unittest-based)

Runs all v5 test suites using Python's unittest framework.
Generates quality gate report and auto-redesigns if score < 90.
"""

import sys
import unittest
import json
from pathlib import Path
from datetime import datetime
from io import StringIO

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

QUALITY_GATE = 90

# Test modules to import
TEST_MODULES = [
    ("v5_router", "tests.v5_router.test_router_lanes"),
    ("v5_router", "tests.v5_router.test_router_mission_scope"),
    ("v5_sandbox", "tests.v5_sandbox.test_paths"),
    ("v5_sandbox", "tests.v5_sandbox.test_content"),
    ("v5_sandbox", "tests.v5_sandbox.test_sip_cli"),
    ("v5_sip", "tests.v5_sip.test_single_file_sip"),
    ("v5_clc", "tests.v5_clc.test_wo_validation"),
    ("v5_clc", "tests.v5_clc.test_exec_strict"),
    ("v5_wo_processor", "tests.v5_wo_processor.test_lane_routing"),
    ("v5_wo_processor", "tests.v5_wo_processor.test_local_exec"),
    ("v5_wo_processor", "tests.v5_wo_processor.test_clc_wo_schema"),
    ("v5_health", "tests.v5_health.test_health_json"),
    ("v5_health", "tests.v5_health.test_health_thresholds"),
]

SUITE_WEIGHTS = {
    "v5_router": 20,
    "v5_sandbox": 20,
    "v5_sip": 15,
    "v5_clc": 15,
    "v5_wo_processor": 20,
    "v5_health": 10,
}


def run_test_module(module_path):
    """Run a test module and return results."""
    try:
        # Import module
        module = __import__(module_path, fromlist=[""])
        
        # Discover tests
        loader = unittest.TestLoader()
        suite = loader.loadTestsFromModule(module)
        
        # Run tests
        stream = StringIO()
        runner = unittest.TextTestRunner(stream=stream, verbosity=0)
        result = runner.run(suite)
        
        output = stream.getvalue()
        
        # Calculate score
        total = result.testsRun
        if total == 0:
            score = 0
        else:
            # Count xfail as passed
            xfail_count = len([t for t in suite._tests if hasattr(t, '_testMethodName') and 'xfail' in t._testMethodName.lower()])
            passed = total - len(result.failures) - len(result.errors) + xfail_count
            score = (passed / total * 100) if total > 0 else 0
        
        return {
            "status": "PASSED" if len(result.failures) == 0 and len(result.errors) == 0 else "FAILED",
            "passed": total - len(result.failures) - len(result.errors),
            "failed": len(result.failures),
            "errors": len(result.errors),
            "skipped": len(result.skipped),
            "total": total,
            "score": round(score, 2),
            "output": output[:500]
        }
    except ImportError as e:
        return {
            "status": "SKIPPED",
            "reason": f"Import error: {e}",
            "score": 0
        }
    except Exception as e:
        return {
            "status": "ERROR",
            "reason": str(e),
            "score": 0
        }


def run_all_tests():
    """Run all test modules and aggregate results."""
    suite_results = {}
    
    for suite_name, module_path in TEST_MODULES:
        if suite_name not in suite_results:
            suite_results[suite_name] = {
                "modules": [],
                "total_passed": 0,
                "total_failed": 0,
                "total_errors": 0,
                "total_skipped": 0,
                "total_tests": 0
            }
        
        print(f"  Running {module_path}...", end=" ")
        result = run_test_module(module_path)
        suite_results[suite_name]["modules"].append({
            "module": module_path,
            **result
        })
        
        suite_results[suite_name]["total_passed"] += result.get("passed", 0)
        suite_results[suite_name]["total_failed"] += result.get("failed", 0)
        suite_results[suite_name]["total_errors"] += result.get("errors", 0)
        suite_results[suite_name]["total_skipped"] += result.get("skipped", 0)
        suite_results[suite_name]["total_tests"] += result.get("total", 0)
        
        status_icon = "✅" if result.get("status") == "PASSED" else "❌" if result.get("status") == "FAILED" else "⏭️"
        print(f"{status_icon} {result.get('status', 'UNKNOWN')} ({result.get('score', 0):.1f}%)")
    
    # Calculate suite scores
    for suite_name in suite_results:
        suite = suite_results[suite_name]
        total = suite["total_tests"]
        if total == 0:
            suite["score"] = 0
        else:
            passed = suite["total_passed"]
            suite["score"] = round((passed / total * 100) if total > 0 else 0, 2)
    
    return suite_results


def calculate_weighted_score(suite_results):
    """Calculate weighted score."""
    total_weight = sum(SUITE_WEIGHTS.values())
    weighted_sum = 0
    
    for suite_name, weight in SUITE_WEIGHTS.items():
        suite = suite_results.get(suite_name, {})
        score = suite.get("score", 0)
        weighted_sum += score * weight
    
    return round(weighted_sum / total_weight, 2) if total_weight > 0 else 0


def generate_report(suite_results, weighted_score):
    """Generate quality gate report."""
    report = {
        "timestamp": datetime.now().isoformat(),
        "quality_gate": QUALITY_GATE,
        "weighted_score": weighted_score,
        "gate_passed": weighted_score >= QUALITY_GATE,
        "suites": suite_results,
        "summary": {
            "total_passed": sum(s.get("total_passed", 0) for s in suite_results.values()),
            "total_failed": sum(s.get("total_failed", 0) for s in suite_results.values()),
            "total_errors": sum(s.get("total_errors", 0) for s in suite_results.values()),
            "total_skipped": sum(s.get("total_skipped", 0) for s in suite_results.values()),
            "total_tests": sum(s.get("total_tests", 0) for s in suite_results.values()),
        }
    }
    
    return report


def main():
    """Main test runner."""
    print("🧪 Running Governance v5 Test Suites (Unittest)...")
    print("=" * 60)
    
    suite_results = {}
    
    for suite_name in SUITE_WEIGHTS.keys():
        print(f"\n▶ Suite: {suite_name}")
        # Run modules for this suite
        modules_for_suite = [m for s, m in TEST_MODULES if s == suite_name]
        if not modules_for_suite:
            suite_results[suite_name] = {"score": 0, "status": "SKIPPED", "reason": "No test modules"}
            continue
        
        # Aggregate results for suite
        suite_data = {
            "modules": [],
            "total_passed": 0,
            "total_failed": 0,
            "total_errors": 0,
            "total_skipped": 0,
            "total_tests": 0
        }
        
        for module_path in modules_for_suite:
            result = run_test_module(module_path)
            suite_data["modules"].append({"module": module_path, **result})
            suite_data["total_passed"] += result.get("passed", 0)
            suite_data["total_failed"] += result.get("failed", 0)
            suite_data["total_errors"] += result.get("errors", 0)
            suite_data["total_skipped"] += result.get("skipped", 0)
            suite_data["total_tests"] += result.get("total", 0)
        
        total = suite_data["total_tests"]
        suite_data["score"] = round((suite_data["total_passed"] / total * 100) if total > 0 else 0, 2)
        suite_data["status"] = "PASSED" if suite_data["total_failed"] == 0 and suite_data["total_errors"] == 0 else "FAILED"
        
        suite_results[suite_name] = suite_data
        
        status_icon = "✅" if suite_data["status"] == "PASSED" else "❌"
        print(f"  {status_icon} {suite_data['status']} - Score: {suite_data['score']:.2f}%")
        print(f"    Tests: {suite_data['total_passed']}/{suite_data['total_tests']} passed")
    
    weighted_score = calculate_weighted_score(suite_results)
    
    print("\n" + "=" * 60)
    print(f"📊 Weighted Score: {weighted_score:.2f}%")
    print(f"🎯 Quality Gate: {QUALITY_GATE}%")
    print(f"   {'✅ PASSED' if weighted_score >= QUALITY_GATE else '❌ FAILED'}")
    print("=" * 60)
    
    # Generate report
    report = generate_report(suite_results, weighted_score)
    
    # Save report
    report_file = project_root / "g" / "reports" / "feature-dev" / "governance_v5_unified_law" / "251209_block6_tests_RESULTS.json"
    report_file.parent.mkdir(parents=True, exist_ok=True)
    report_file.write_text(json.dumps(report, indent=2))
    
    print(f"\n📄 Report saved: {report_file}")
    
    # Auto-redesign trigger
    if weighted_score < QUALITY_GATE:
        print(f"\n⚠️  Quality gate failed ({weighted_score:.2f}% < {QUALITY_GATE}%)")
        print("   Auto-redesign triggered (max 3 retries)")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

