#!/usr/bin/env python3
"""
WO Processor v5 — Lane-Based Work Order Routing

This module implements lane-based routing for Work Orders:
- STRICT lane → CLC Executor v5
- FAST/WARN lane → Local execution (agents + SandboxGuard)
- BLOCKED lane → Reject

Integrates with:
- Router v5 (lane resolution)
- SandboxGuard v5 (pre-write checks)
- CLC Executor v5 (STRICT lane execution)

Author: 02luka System
Status: Implementation (Phase 3.3)
"""

import os
import json
import yaml
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from datetime import datetime
from enum import Enum

# Import Router v5, SandboxGuard v5, CLC Executor v5
try:
    from bridge.core.router_v5 import route, RoutingDecision
    from bridge.core.sandbox_guard_v5 import check_write_allowed, SandboxCheckResult
    from agents.clc.executor_v5 import read_work_order, WorkOrder
except ImportError:
    # Fallback for standalone testing
    def route(trigger, actor, path, op="write", context=None):
        return type('obj', (object,), {
            'zone': 'OPEN',
            'lane': 'FAST',
            'primary_writer': actor,
            'auto_approve_allowed': False
        })()
    
    def check_write_allowed(path, actor, operation="write", content=None, context=None):
        return type('obj', (object,), {
            'allowed': True,
            'zone': 'OPEN',
            'warnings': []
        })()


# ============================================================================
# TYPE DEFINITIONS
# ============================================================================

class ProcessingStatus(Enum):
    """WO processing status."""
    PENDING = "PENDING"
    ROUTING = "ROUTING"
    EXECUTING = "EXECUTING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    REJECTED = "REJECTED"


@dataclass
class OperationRouting:
    """Routing decision for a single operation."""
    operation: Dict[str, Any]
    routing_decision: Any  # RoutingDecision from Router v5
    lane: str
    destination: str  # "CLC" | "LOCAL" | "REJECTED"
    reason: str


@dataclass
class ProcessingResult:
    """Result of WO processing."""
    wo_id: str
    status: ProcessingStatus
    strict_operations: List[Dict]  # Operations sent to CLC
    local_operations: List[Dict]  # Operations executed locally
    rejected_operations: List[Dict]  # Operations rejected
    clc_wo_path: Optional[str] = None  # Path to WO created for CLC
    local_execution_result: Optional[Dict] = None
    errors: List[str] = None
    warnings: List[str] = None
    
    def __post_init__(self):
        if self.errors is None:
            self.errors = []
        if self.warnings is None:
            self.warnings = []


# ============================================================================
# WO READER
# ============================================================================

def read_wo_from_main(wo_path: str) -> Dict[str, Any]:
    """
    Read WO from bridge/inbox/main/.
    
    Args:
        wo_path: Path to WO file
    
    Returns:
        WO dictionary
    """
    path = Path(wo_path)
    
    if not path.exists():
        raise FileNotFoundError(f"Work Order not found: {wo_path}")
    
    with open(path, 'r', encoding='utf-8') as f:
        if path.suffix in ['.yaml', '.yml']:
            return yaml.safe_load(f)
        else:
            return json.load(f)


# ============================================================================
# LANE-BASED ROUTER
# ============================================================================

def route_operations_by_lane(
    wo: Dict[str, Any],
    operations: List[Dict[str, Any]]
) -> Tuple[List[OperationRouting], List[str]]:
    """
    Route operations by lane using Router v5.
    
    Args:
        wo: Work Order dictionary
        operations: List of operations to route
    
    Returns:
        (list of OperationRouting, list of errors)
    """
    routings = []
    errors = []
    
    # Support both top-level and origin.trigger/actor (for compatibility)
    trigger = wo.get('trigger') or wo.get('origin', {}).get('trigger', 'background')
    actor = wo.get('actor') or wo.get('origin', {}).get('actor', 'CLC')
    wo_id = wo.get('wo_id', 'unknown')
    
    for op in operations:
        path = op.get('path', '')
        operation = op.get('operation', 'write')
        
        if not path:
            errors.append(f"Operation missing path: {op}")
            continue
        
        # Call Router v5
        try:
            routing_decision = route(
                trigger=trigger,
                actor=actor,
                path=path,
                op=operation,
                context={'wo_id': wo_id}
            )
        except Exception as e:
            errors.append(f"Router v5 error for {path}: {e}")
            continue
        
        # Determine destination based on lane
        lane = routing_decision.lane
        destination = None
        reason = ""
        
        if lane == "STRICT":
            destination = "CLC"
            reason = f"STRICT lane: Background/LOCKED zone operation"
        elif lane == "FAST":
            destination = "LOCAL"
            reason = f"FAST lane: OPEN zone, CLI world"
        elif lane == "WARN":
            if routing_decision.auto_approve_allowed:
                destination = "LOCAL"
                reason = f"WARN lane: CLS auto-approve allowed (Mission Scope + safety conditions)"
            else:
                # WARN without auto-approve → STRICT
                destination = "CLC"
                reason = f"WARN lane: No auto-approve, routing to CLC"
        elif lane == "BLOCKED":
            destination = "REJECTED"
            reason = f"BLOCKED lane: DANGER zone operation"
        else:
            errors.append(f"Unknown lane: {lane} for {path}")
            continue
        
        routings.append(OperationRouting(
            operation=op,
            routing_decision=routing_decision,
            lane=lane,
            destination=destination,
            reason=reason
        ))
    
    return (routings, errors)


# ============================================================================
# CLC ROUTING (STRICT LANE)
# ============================================================================

def create_clc_wo(
    wo: Dict[str, Any],
    strict_operations: List[Dict[str, Any]]
) -> str:
    """
    Create WO for CLC and send to bridge/inbox/clc/.
    
    Args:
        wo: Original WO
        strict_operations: Operations for STRICT lane
    
    Returns:
        Path to created WO file
    """
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    clc_inbox = luka_root / "bridge" / "inbox" / "CLC"
    clc_inbox.mkdir(parents=True, exist_ok=True)
    
    # Create CLC WO
    clc_wo = {
        "wo_id": wo.get("wo_id", f"CLC-{datetime.now().strftime('%Y%m%d-%H%M%S')}"),
        "created_at": datetime.now().isoformat(),
        "origin": {
            "world": "BACKGROUND",
            "actor": "CLC",
            "source_wo": wo.get("wo_id"),
            "routed_from": "WO_PROCESSOR_V5"
        },
        "target_paths": [op.get("path") for op in strict_operations],
        "zone_summary": {},  # Will be resolved by CLC
        "risk_level": wo.get("risk_level", "MEDIUM"),
        "desired_state": wo.get("desired_state", "Execute STRICT lane operations"),
        "change_type": wo.get("change_type", "MIXED"),
        "rollback_strategy": wo.get("rollback_strategy"),
        "approver": wo.get("approver"),
        "constraints": wo.get("constraints", []),
        "operations": strict_operations,
        "status": "PENDING"
    }
    
    # Write WO file
    wo_file = clc_inbox / f"{clc_wo['wo_id']}.yaml"
    with open(wo_file, 'w', encoding='utf-8') as f:
        yaml.dump(clc_wo, f, default_flow_style=False)
    
    return str(wo_file)


# ============================================================================
# LOCAL EXECUTION ENGINE
# ============================================================================

def execute_local_operation(
    operation: Dict[str, Any],
    actor: str,
    routing_decision: Any,
    context: Dict[str, Any]
) -> Tuple[bool, Optional[str], List[str]]:
    """
    Execute operation locally (FAST/WARN lane).
    
    Args:
        operation: Operation to execute
        actor: Acting agent
        routing_decision: RoutingDecision from Router v5
        context: Execution context
    
    Returns:
        (success, error_message, warnings)
    """
    warnings = []
    path = operation.get('path', '')
    op_type = operation.get('operation', 'write')
    content = operation.get('content', '')
    
    # Resolve absolute path
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    if not Path(path).is_absolute():
        path = str(luka_root / path)
    
    # SandboxGuard check
    sandbox_context = {
        'world': 'CLI',
        'zone': routing_decision.zone,
        'lane': routing_decision.lane,
        'cls_auto_approve_allowed': routing_decision.auto_approve_allowed
    }
    
    sandbox_result = check_write_allowed(
        path=path,
        actor=actor,
        operation=op_type,
        content=content,
        context=sandbox_context
    )
    
    if not sandbox_result.allowed:
        return (False, f"SandboxGuard blocked: {sandbox_result.reason}", warnings)
    
    warnings.extend(sandbox_result.warnings)
    
    # Execute operation (simple SIP pattern for CLI)
    try:
        if op_type == "write" or op_type == "add" or op_type == "modify":
            # Simple SIP: mktemp → write → mv
            # tempfile and shutil imported at top level
            
            target_path = Path(path)
            target_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Create temp file
            temp_fd, temp_path = tempfile.mkstemp(
                suffix='.tmp',
                prefix=f'.wo_processor_{target_path.name}.',
                dir=str(target_path.parent)
            )
            
            try:
                # Write content to temp
                with os.fdopen(temp_fd, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                # Atomic move
                shutil.move(temp_path, str(target_path))
                
            except Exception as e:
                # Cleanup on failure
                try:
                    os.unlink(temp_path)
                except:
                    pass
                return (False, f"Write failed: {e}", warnings)
        
        elif op_type == "delete":
            if Path(path).exists():
                Path(path).unlink()
            else:
                warnings.append(f"File does not exist for delete: {path}")
        
        elif op_type == "move":
            source = operation.get('source_path', '')
            if not Path(source).is_absolute():
                source = str(luka_root / source)
            if source and Path(source).exists():
                shutil.move(source, path)
            else:
                return (False, f"Source file does not exist: {source}", warnings)
        
        return (True, None, warnings)
    
    except Exception as e:
        return (False, f"Execution failed: {e}", warnings)


def execute_local_operations(
    operations: List[Dict[str, Any]],
    routings: List[OperationRouting],
    actor: str,
    wo_id: str
) -> Dict[str, Any]:
    """
    Execute multiple local operations.
    
    Args:
        operations: Operations to execute
        routings: OperationRouting decisions
        actor: Acting agent
        wo_id: Work Order ID
    
    Returns:
        Execution result dictionary
    """
    results = []
    all_warnings = []
    errors = []
    
    # Create routing map
    # Handle both OperationRouting objects and mock objects
    routing_map = {}
    for routing in routings:
        if hasattr(routing, 'operation'):
            # OperationRouting object
            if isinstance(routing.operation, dict):
                path = routing.operation.get('path')
            else:
                path = getattr(routing.operation, 'path', None)
        else:
            # Mock object or dict - try to get path from routing itself
            if isinstance(routing, dict):
                path = routing.get('path')
            else:
                # For MockRouting objects, we need to match by operation path
                path = None
        
        if path:
            routing_map[path] = routing
    
    for op in operations:
        path = op.get('path', '')
        routing = routing_map.get(path)
        
        if not routing:
            errors.append(f"No routing decision for {path}")
            continue
        
        success, error_msg, warnings = execute_local_operation(
            operation=op,
            actor=actor,
            routing_decision=routing.routing_decision,
            context={'wo_id': wo_id}
        )
        
        results.append({
            'path': path,
            'success': success,
            'error': error_msg,
            'warnings': warnings
        })
        
        all_warnings.extend(warnings)
        if error_msg:
            errors.append(f"{path}: {error_msg}")
    
    return {
        'operations': results,
        'warnings': all_warnings,
        'errors': errors,
        'success_count': sum(1 for r in results if r['success']),
        'failure_count': sum(1 for r in results if not r['success'])
    }


# ============================================================================
# MAIN PROCESSOR
# ============================================================================

def process_wo_with_lane_routing(wo_path: str) -> ProcessingResult:
    """
    Main function: Process WO with lane-based routing.
    
    Flow:
    1. Read WO from bridge/inbox/main/
    2. Route operations by lane (Router v5)
    3. Route STRICT → CLC
    4. Execute FAST/WARN locally
    5. Reject BLOCKED
    
    Args:
        wo_path: Path to WO file
    
    Returns:
        ProcessingResult
    """
    result = ProcessingResult(
        wo_id="",
        status=ProcessingStatus.PENDING,
        strict_operations=[],
        local_operations=[],
        rejected_operations=[],
        clc_wo_path=None
    )
    
    try:
        # Step 1: Read WO
        wo = read_wo_from_main(wo_path)
        result.wo_id = wo.get('wo_id', 'unknown')
        result.status = ProcessingStatus.ROUTING
        
        # Step 2: Get operations
        operations = wo.get('operations', [])
        if not operations:
            # Fallback: Create operations from target_paths
            target_paths = wo.get('target_paths', [])
            operations = [{'path': path, 'operation': 'write'} for path in target_paths]
            result.warnings.append("No operations specified, using target_paths")
        
        # Step 3: Route operations by lane
        routings, routing_errors = route_operations_by_lane(wo, operations)
        result.errors.extend(routing_errors)
        
        # Step 4: Group operations by destination
        for routing in routings:
            if routing.destination == "CLC":
                result.strict_operations.append(routing.operation)
            elif routing.destination == "LOCAL":
                result.local_operations.append(routing.operation)
            elif routing.destination == "REJECTED":
                result.rejected_operations.append(routing.operation)
        
        # Step 5: Route STRICT to CLC
        if result.strict_operations:
            try:
                clc_wo_path = create_clc_wo(wo, result.strict_operations)
                result.clc_wo_path = clc_wo_path
                result.warnings.append(f"STRICT lane operations routed to CLC: {clc_wo_path}")
            except Exception as e:
                result.errors.append(f"Failed to create CLC WO: {e}")
        
        # Step 6: Execute local operations
        if result.local_operations:
            result.status = ProcessingStatus.EXECUTING
            actor = wo.get('origin', {}).get('actor', 'CLS')
            
            local_routings = [r for r in routings if r.destination == "LOCAL"]
            local_result = execute_local_operations(
                operations=result.local_operations,
                routings=local_routings,
                actor=actor,
                wo_id=result.wo_id
            )
            
            result.local_execution_result = local_result
            result.warnings.extend(local_result.get('warnings', []))
            result.errors.extend(local_result.get('errors', []))
        
        # Step 7: Handle rejected operations
        if result.rejected_operations:
            result.errors.append(f"{len(result.rejected_operations)} operations rejected (BLOCKED lane)")
            # Move WO to error inbox
            move_wo_to_error(wo_path, wo, result)
        
        # Step 8: Determine final status
        if result.errors and not result.strict_operations and not result.local_operations:
            result.status = ProcessingStatus.REJECTED
        elif result.errors:
            result.status = ProcessingStatus.FAILED
        else:
            result.status = ProcessingStatus.COMPLETED
        
        # Step 9: Move processed WO
        if result.status != ProcessingStatus.REJECTED:
            move_wo_to_processed(wo_path, wo, result)
        
        return result
    
    except Exception as e:
        result.status = ProcessingStatus.FAILED
        result.errors.append(f"Processing failed: {e}")
        return result


def move_wo_to_processed(wo_path: str, wo: Dict, result: ProcessingResult):
    """Move WO to processed directory."""
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    processed_dir = luka_root / "bridge" / "processed" / "MAIN"
    processed_dir.mkdir(parents=True, exist_ok=True)
    
    wo_file = Path(wo_path)
    processed_file = processed_dir / wo_file.name
    
    # Update WO with processing result
    wo['processing_result'] = {
        'status': result.status.value,
        'strict_count': len(result.strict_operations),
        'local_count': len(result.local_operations),
        'rejected_count': len(result.rejected_operations),
        'clc_wo_path': result.clc_wo_path,
        'errors': result.errors,
        'warnings': result.warnings
    }
    
    with open(processed_file, 'w', encoding='utf-8') as f:
        if wo_file.suffix in ['.yaml', '.yml']:
            yaml.dump(wo, f, default_flow_style=False)
        else:
            json.dump(wo, f, indent=2)
    
    # Remove from inbox
    wo_file.unlink()


def move_wo_to_error(wo_path: str, wo: Dict, result: ProcessingResult):
    """Move WO to error directory."""
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    error_dir = luka_root / "bridge" / "error" / "MAIN"
    error_dir.mkdir(parents=True, exist_ok=True)
    
    wo_file = Path(wo_path)
    error_file = error_dir / wo_file.name
    
    # Update WO with error info
    wo['error'] = {
        'status': result.status.value,
        'errors': result.errors,
        'rejected_operations': result.rejected_operations
    }
    
    with open(error_file, 'w', encoding='utf-8') as f:
        if wo_file.suffix in ['.yaml', '.yml']:
            yaml.dump(wo, f, default_flow_style=False)
        else:
            json.dump(wo, f, indent=2)
    
    # Remove from inbox
    wo_file.unlink()


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """CLI entry point for WO Processor."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="WO Processor v5 — Lane-Based Work Order Routing"
    )
    parser.add_argument("--wo", required=True, help="Path to Work Order file")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    
    args = parser.parse_args()
    
    result = process_wo_with_lane_routing(args.wo)
    
    if args.json:
        output = {
            "wo_id": result.wo_id,
            "status": result.status.value,
            "strict_count": len(result.strict_operations),
            "local_count": len(result.local_operations),
            "rejected_count": len(result.rejected_operations),
            "clc_wo_path": result.clc_wo_path,
            "errors": result.errors,
            "warnings": result.warnings
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"🔧 WO PROCESSOR v5 RESULT:")
        print(f"   WO ID    : {result.wo_id}")
        print(f"   STATUS   : {result.status.value}")
        print(f"   STRICT   : {len(result.strict_operations)} → CLC")
        print(f"   LOCAL    : {len(result.local_operations)} → Executed")
        print(f"   REJECTED : {len(result.rejected_operations)}")
        if result.clc_wo_path:
            print(f"   CLC WO   : {result.clc_wo_path}")
        if result.errors:
            print(f"   ❌ ERRORS: {len(result.errors)}")
            for error in result.errors:
                print(f"      - {error}")


if __name__ == "__main__":
    main()

