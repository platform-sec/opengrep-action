"""Action-boundary tripwire.

For each injection class we run a real `act` job (not --dry-run) against a
workflow that feeds a malicious payload into one input, and assert that act
exits non-zero AND the action's own validator error message appears in the
output. The stderr match is the key signal: it proves the composite step's
validator fired, not that something unrelated (workflow YAML parse, missing
Docker, network failure) happened to make act fail.

Unit-level coverage of the validators themselves lives in tests/unit/.
"""

# SPDX-License-Identifier: MIT

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
DOCKER_IMAGE = "catthehacker/ubuntu:act-22.04"
ACT_TIMEOUT_SECONDS = 180

# name, input field, payload, substring that must appear in act's output
# from action.yml / scripts/validators.sh (see `Error: ...` messages).
CASES = [
    ("path_traversal",    "target",   "../../etc/passwd",   "Path traversal detected"),
    ("command_injection", "include",  "; echo OWNED",       "invalid characters"),
    ("numeric_bounds",    "timeout",  "99999",              "timeout too large"),
    ("enum_bypass",       "severity", "INFO; echo OWNED",   "Invalid severity level"),
    ("control_char",      "target",   "ok\n../etc/passwd",  "Invalid characters in path"),
    ("baseline_commit",   "baseline-commit", "../../etc/passwd", "Path traversal detected"),
]


@pytest.fixture(scope="module")
def act_bin() -> str:
    path = shutil.which("act")
    if not path:
        pytest.skip("act is not installed")
    return path


def _build_workflow(field: str, payload: str) -> str:
    wf = {
        "name": "Boundary",
        "on": ["push"],
        "jobs": {
            "boundary": {
                "runs-on": "ubuntu-latest",
                "steps": [
                    {
                        "id": "scan",
                        "uses": "./",
                        "with": {field: payload},
                    }
                ],
            }
        },
    }
    return yaml.safe_dump(wf, sort_keys=False, allow_unicode=True, width=10_000)


@pytest.mark.parametrize(
    "name,field,payload,expected",
    CASES,
    ids=[c[0] for c in CASES],
)
def test_payload_is_rejected(
    act_bin: str,
    tmp_path: Path,
    name: str,
    field: str,
    payload: str,
    expected: str,
) -> None:
    wf_path = tmp_path / f"{name}.yml"
    wf_path.write_text(_build_workflow(field, payload))

    result = subprocess.run(
        [
            act_bin,
            "-W", str(wf_path),
            "-j", "boundary",
            "-P", f"ubuntu-latest={DOCKER_IMAGE}",
            "--env", "ACT=true",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=ACT_TIMEOUT_SECONDS,
    )

    combined = result.stdout + result.stderr
    tail = combined[-4000:]

    assert result.returncode != 0, (
        f"act succeeded but payload {payload!r} should have been rejected.\n"
        f"--- last output ---\n{tail}"
    )
    assert expected in combined, (
        f"act failed, but not with the expected validator error "
        f"{expected!r}. Something else broke — the tripwire lost its signal.\n"
        f"--- last output ---\n{tail}"
    )
