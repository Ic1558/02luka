# Block 4: Multi-File SIP Transaction Engine — Implementation Specification

**Date:** 2025-12-10  
**Feature Slug:** `block4_multifile_sip`  
**Status:** 📋 SPEC  
**Priority:** P1 (Critical for Governance v5 Integration)  
**Owner:** GG (System Orchestrator)

---

## 🎯 Objective

Implement Multi-File SIP Transaction Engine that:
1. **Atomic Transactions:** All files commit or none (all-or-nothing)
2. **Pre-Validation:** Entire transaction validated before any commit
3. **Automatic Rollback:** Rollback all changes on any failure
4. **Full Audit Trail:** Before/after checksums, transaction log
5. **Integration:** Works with CLC Executor v5 and WO Processor v5

---

## 📐 Architecture

### Core Components

```
Multi-File SIP Transaction Engine
├── TransactionContext (context manager)
│   ├── prepare_files()      # Prepare all files in temp
│   ├── validate()            # Validate entire transaction
│   ├── commit()              # Atomic commit (all-or-nothing)
│   └── rollback()            # Rollback all changes
├── ValidationEngine
│   ├── validate_syntax()     # JSON/YAML/Python syntax
│   ├── validate_dependencies() # File dependencies
│   └── validate_constraints() # Business constraints
└── RollbackEngine
    ├── store_state()         # Store original checksums
    └── restore_state()      # Restore original files
```

---

## 🔧 Implementation Details

### Component 1: Transaction Context Manager

**File:** `bridge/core/sip_engine_v5.py`

**Class:** `TransactionContext`

**Functions:**
```python
class TransactionContext:
    """
    Context manager for multi-file SIP transactions.
    
    Usage:
        with TransactionContext(operations) as tx:
            tx.prepare_files()
            if tx.validate():
                tx.commit()
            else:
                tx.rollback()
    """
    
    def __init__(self, operations: List[Dict[str, Any]], base_path: str = None):
        """
        Initialize transaction context.
        
        Args:
            operations: List of file operations
            base_path: Base path for relative paths (default: 02luka root)
        """
        
    def __enter__(self) -> 'TransactionContext':
        """Enter context manager."""
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Exit context manager (auto-rollback on exception)."""
        
    def prepare_files(self) -> Dict[str, str]:
        """
        Prepare all files in temp (no target files modified yet).
        
        Returns:
            Dict mapping target_path -> temp_file_path
        """
        
    def validate(self) -> Tuple[bool, List[str]]:
        """
        Validate entire transaction.
        
        Returns:
            (is_valid, list_of_errors)
        """
        
    def commit(self) -> Tuple[bool, Dict[str, str], List[str]]:
        """
        Atomic commit (all files or none).
        
        Returns:
            (success, checksums_before_after, errors)
        """
        
    def rollback(self) -> Tuple[bool, List[str]]:
        """
        Rollback all changes to original state.
        
        Returns:
            (success, errors)
        """
```

---

### Component 2: Validation Engine

**Class:** `ValidationEngine`

**Functions:**
```python
class ValidationEngine:
    """Validates multi-file transactions."""
    
    def validate_syntax(
        self,
        file_path: str,
        content: str
    ) -> Tuple[bool, Optional[str]]:
        """
        Validate file syntax (JSON/YAML/Python/etc.).
        
        Returns:
            (is_valid, error_message)
        """
        
    def validate_dependencies(
        self,
        operations: List[Dict[str, Any]]
    ) -> Tuple[bool, List[str]]:
        """
        Validate file dependencies (file A depends on file B).
        
        Returns:
            (is_valid, list_of_errors)
        """
        
    def validate_constraints(
        self,
        operations: List[Dict[str, Any]]
    ) -> Tuple[bool, List[str]]:
        """
        Validate business constraints (e.g., schema compatibility).
        
        Returns:
            (is_valid, list_of_errors)
        """
        
    def validate_transaction(
        self,
        operations: List[Dict[str, Any]],
        temp_files: Dict[str, str]
    ) -> Tuple[bool, List[str]]:
        """
        Validate entire transaction (syntax + dependencies + constraints).
        
        Returns:
            (is_valid, list_of_errors)
        """
```

---

### Component 3: Rollback Engine

**Class:** `RollbackEngine`

**Functions:**
```python
class RollbackEngine:
    """Handles rollback for multi-file transactions."""
    
    def store_state(
        self,
        file_paths: List[str]
    ) -> Dict[str, Dict[str, Any]]:
        """
        Store original state (checksums, content) before transaction.
        
        Returns:
            Dict mapping file_path -> {checksum, content, exists}
        """
        
    def restore_state(
        self,
        state: Dict[str, Dict[str, Any]]
    ) -> Tuple[bool, List[str]]:
        """
        Restore files to original state.
        
        Returns:
            (success, errors)
        """
        
    def handle_partial_rollback(
        self,
        committed_files: List[str],
        state: Dict[str, Dict[str, Any]]
    ) -> Tuple[bool, List[str]]:
        """
        Handle rollback when some files already committed.
        
        Returns:
            (success, errors)
        """
```

---

### Component 4: Main Transaction Function

**Function:**
```python
def apply_multifile_sip_transaction(
    operations: List[Dict[str, Any]],
    base_path: Optional[str] = None,
    validate: bool = True,
    dry_run: bool = False
) -> TransactionResult:
    """
    Apply multi-file SIP transaction.
    
    Args:
        operations: List of file operations
            [
                {
                    "path": "path/to/file1.json",
                    "operation": "modify",  # or "add", "delete"
                    "content": "new content"
                },
                ...
            ]
        base_path: Base path for relative paths
        validate: Whether to validate before commit
        dry_run: If True, prepare and validate but don't commit
    
    Returns:
        TransactionResult(
            success: bool,
            committed_files: List[str],
            checksums_before: Dict[str, str],
            checksums_after: Dict[str, str],
            errors: List[str],
            transaction_id: str
        )
    """
```

---

## 🔄 Transaction Flow

### Step-by-Step Algorithm

```
1. Initialize TransactionContext
   ├── Store original state (checksums, content)
   └── Create transaction ID

2. Prepare Files (all in temp)
   ├── For each operation:
   │   ├── Create temp file in same directory
   │   ├── Write new content to temp
   │   └── Store temp_path mapping
   └── No target files modified yet

3. Validate Transaction
   ├── Syntax validation (all files)
   ├── Dependency validation
   ├── Constraint validation
   └── If validation fails → abort (no changes)

4. Commit (if validation passes)
   ├── For each file (in order):
   │   ├── Atomic move: mv temp_path → target_path
   │   ├── Verify checksum after
   │   └── If any fails → rollback all
   └── Log transaction success

5. Rollback (if commit fails)
   ├── Restore all files to original state
   ├── Remove temp files
   └── Log rollback event

6. Post-Commit Verification
   ├── Re-read all committed files
   ├── Verify checksums
   └── Log transaction result
```

---

## 📋 Data Structures

### TransactionResult
```python
@dataclass
class TransactionResult:
    """Result of multi-file SIP transaction."""
    success: bool
    committed_files: List[str]
    checksums_before: Dict[str, str]  # file_path -> checksum
    checksums_after: Dict[str, str]   # file_path -> checksum
    errors: List[str]
    transaction_id: str
    rollback_performed: bool = False
```

### FileOperation
```python
@dataclass
class FileOperation:
    """Single file operation in transaction."""
    path: str
    operation: str  # "add", "modify", "delete"
    content: Optional[str] = None
    temp_path: Optional[str] = None
    checksum_before: Optional[str] = None
    checksum_after: Optional[str] = None
```

---

## 🔗 Integration Points

### Integration 1: CLC Executor v5

**Usage:**
```python
# In agents/clc/executor_v5.py

from bridge.core.sip_engine_v5 import apply_multifile_sip_transaction

# For multi-file WOs:
if len(wo.operations) > 1:
    result = apply_multifile_sip_transaction(
        operations=wo.operations,
        base_path=LUKA_BASE,
        validate=True,
        dry_run=False
    )
    if not result.success:
        # Handle failure (already rolled back)
        log_error(result.errors)
else:
    # Single file: use existing single-file SIP
    apply_sip_single_file(...)
```

### Integration 2: WO Processor v5

**Usage:**
```python
# In bridge/core/wo_processor_v5.py

from bridge.core.sip_engine_v5 import TransactionContext

# For local execution of multi-file operations:
with TransactionContext(operations) as tx:
    tx.prepare_files()
    if tx.validate():
        tx.commit()
    else:
        tx.rollback()
```

---

## 🧪 Validation Rules

### Syntax Validation
- **JSON:** `json.loads()` must succeed
- **YAML:** `yaml.safe_load()` must succeed
- **Python:** `ast.parse()` must succeed (optional, for .py files)
- **Other:** Basic file existence and readability

### Dependency Validation
- **File Ordering:** If file A imports/requires file B, B must be in transaction
- **Path Resolution:** All relative paths must resolve correctly
- **Circular Dependencies:** Detect and reject circular dependencies

### Constraint Validation
- **Schema Compatibility:** If updating schema file, validate dependent files
- **Cross-Zone Rules:** OPEN + LOCKED files in same transaction (warn but allow)
- **Size Limits:** Reject transactions with too many files (>50 files)

---

## 🔒 Safety Guarantees

1. **Atomicity:** All files commit or none (no partial state)
2. **Idempotency:** Safe to re-run (checksums prevent duplicate work)
3. **Rollback:** Automatic rollback on any failure
4. **Audit:** Full transaction log with before/after checksums
5. **Validation:** Entire transaction validated before any commit

---

## 📊 Error Handling

### Error Types
- **ValidationError:** Transaction validation failed (no changes made)
- **CommitError:** Commit failed (rollback performed)
- **RollbackError:** Rollback failed (manual intervention required)
- **StateError:** Original state not found (cannot rollback)

### Error Recovery
- **Validation Failure:** No changes made, return error immediately
- **Commit Failure:** Automatic rollback, return error with rollback status
- **Rollback Failure:** Log critical error, return error with partial state info

---

## 📚 Reference Documents

- `g/docs/AI_OP_001_v5.md` Section 5.2 (Single-File SIP Algorithm)
- `g/docs/AI_OP_001_v5.md` Section 5.3 (Multi-File SIP Requirements)
- `g/reports/feature-dev/governance_v5_unified_law/251209_block3_clc_enforcement_v5_DRYRUN.md` (Single-File SIP Implementation)

---

## ✅ Success Criteria

1. ✅ All files prepared in temp before any commit
2. ✅ Entire transaction validated before applying
3. ✅ Atomic commit (all files or none)
4. ✅ Automatic rollback on any failure
5. ✅ Full audit trail (before/after checksums, transaction log)
6. ✅ Integration with CLC Executor v5 and WO Processor v5
7. ✅ Handles edge cases (empty transaction, single file, large transactions)

---

**Status:** 📋 SPEC Complete — Ready for DRYRUN

**Next:** Create DRYRUN.md with full code implementation

