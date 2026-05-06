# Security tests

**Unit-level validator coverage lives in [tests/unit/](../unit/).** Those
bats tests source [scripts/validators.sh](../../scripts/validators.sh)
directly and cover the combinatorial input space in ~2 seconds.

This directory is the **integration tripwire**: a small set of real `act`
runs that prove the validators are actually wired into the composite
action. The tripwire catches regressions that unit tests cannot see — most
importantly, a new input added to [action.yml](../../action.yml) without a
`validate_*` call, or a validator accidentally bypassed by a refactor.

## Contents

- [`test_action_boundary.py`](test_action_boundary.py) — one parametrised
  pytest per injection class. Each case runs a real `act` job against a
  workflow carrying a malicious payload, asserts the run fails, and
  asserts the action's own error message appears in `act`'s output. The
  stderr match is load-bearing: it proves the validator fired, not that
  something else broke.
- [`conftest.py`](conftest.py), [`pytest.ini`](pytest.ini) — pytest glue.
- [`requirements.txt`](requirements.txt) — `pytest` and `PyYAML`.

## Running

```bash
just test-security     # runs the 5 cases via pytest (~75s)
```

The recipe creates `tests/security/.venv/` on first use. `act` and Docker
must be available; tests `pytest.skip` otherwise.

## Adding a case

Append a tuple to the `CASES` list in `test_action_boundary.py`. Keep the
set small — the point of this layer is cost-bounded coverage of the
action boundary, not exhaustive fuzzing. Combinatorial expansion belongs
in [tests/unit/](../unit/).
