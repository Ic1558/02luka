import json
import subprocess
import sys
import tempfile
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _write_allowlist(path: Path) -> None:
    repo_root = _repo_root()
    content = (
        "version: \"v0.1\"\n"
        f"project_roots:\n  - {repo_root}\n"
        "output_roots:\n  - /tmp/openwork_runs\n"
    )
    path.write_text(content, encoding="utf-8")


def _run_cli(args):
    return subprocess.run(args, capture_output=True, text=True)


def test_plan_deterministic_hash(tmp_path):
    allowlist = tmp_path / "allowlist.yaml"
    _write_allowlist(allowlist)

    Path("/tmp/openwork_runs").mkdir(parents=True, exist_ok=True)
    run_dir1 = Path(tempfile.mkdtemp(prefix="pa_plan_", dir="/tmp/openwork_runs"))
    run_dir2 = Path(tempfile.mkdtemp(prefix="pa_plan_", dir="/tmp/openwork_runs"))

    sample_input = _repo_root() / "examples" / "sample_project.json"
    cli = _repo_root() / "g" / "tools" / "pa_intake.py"

    result1 = _run_cli(
        [
            sys.executable,
            str(cli),
            "--mode",
            "plan",
            "--input-file",
            str(sample_input),
            "--output-dir",
            str(run_dir1),
            "--allowlist",
            str(allowlist),
        ]
    )
    assert result1.returncode == 0

    result2 = _run_cli(
        [
            sys.executable,
            str(cli),
            "--mode",
            "plan",
            "--input-file",
            str(sample_input),
            "--output-dir",
            str(run_dir2),
            "--allowlist",
            str(allowlist),
        ]
    )
    assert result2.returncode == 0

    plan1 = json.loads((run_dir1 / "plan.json").read_text(encoding="utf-8"))
    plan2 = json.loads((run_dir2 / "plan.json").read_text(encoding="utf-8"))

    assert plan1["plan_hash"] == plan2["plan_hash"]


def test_dry_run_writes_only_under_output_dir(tmp_path):
    allowlist = tmp_path / "allowlist.yaml"
    _write_allowlist(allowlist)

    Path("/tmp/openwork_runs").mkdir(parents=True, exist_ok=True)
    run_dir = Path(tempfile.mkdtemp(prefix="pa_dry_", dir="/tmp/openwork_runs"))

    sample_input = _repo_root() / "examples" / "sample_project.json"
    cli = _repo_root() / "g" / "tools" / "pa_intake.py"

    result = _run_cli(
        [
            sys.executable,
            str(cli),
            "--mode",
            "dry_run",
            "--input-file",
            str(sample_input),
            "--output-dir",
            str(run_dir),
            "--allowlist",
            str(allowlist),
        ]
    )
    assert result.returncode == 0

    expected_files = [
        run_dir / "plan.json",
        run_dir / "approve_token.txt",
        run_dir / "dry_run" / "doc_spec.json",
        run_dir / "dry_run" / "validation.json",
        run_dir / "dry_run" / "manifest.json",
    ]
    for path in expected_files:
        assert path.exists(), f"Missing {path}"
        resolved = path.resolve()
        try:
            resolved.relative_to(run_dir.resolve())
        except ValueError as exc:
            raise AssertionError(f"Path escapes output_dir: {resolved}") from exc

    invalid_dir = tmp_path / "not_allowed"
    invalid_result = _run_cli(
        [
            sys.executable,
            str(cli),
            "--mode",
            "dry_run",
            "--input-file",
            str(sample_input),
            "--output-dir",
            str(invalid_dir),
            "--allowlist",
            str(allowlist),
        ]
    )
    assert invalid_result.returncode != 0
    payload = json.loads(invalid_result.stdout or "{}")
    assert payload.get("status") == "error"
