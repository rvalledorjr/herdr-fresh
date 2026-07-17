# herdr-fresh — Production Readiness Plan (agent handoff)

> **Purpose.** This is an execution plan for AI agents (and humans) to take herdr-fresh from a
> Linux-verified preview (v0.1.1) to a production release (v1.0.0). It is written for **handoff**:
> each task below is self-contained — an agent can pick up any *ready* task without prior context
> from this conversation. Read the "How to use this document" section first, then jump to a task.

---

## How to use this document (read first)

**You are an agent picking up a task.** Do this:

1. **Read the repo's design-of-record before touching anything:**
   [`PLAN.md`](../../PLAN.md) (architecture, the 3 load-bearing gotchas, milestone history) and
   [`AGENTS.md`](../../AGENTS.md) (conventions). Do not re-derive decisions justified there.
2. **Pick a task** whose `Status` is `READY` and whose `Depends on` tasks are all `DONE`.
3. **Obey the guardrails** in the "Non-negotiable constraints" section below. They are the reason
   this project stays small; violating them fails review regardless of correctness.
4. **Satisfy the task's `Acceptance criteria` literally** and run its `Verification` commands.
5. **Update this file** when done: set the task `Status: DONE`, add a one-line result note, and
   check the box in the tracker table. Keep `PLAN.md`'s milestone notes and `docs/` in sync in the
   *same* change (an AGENTS.md convention).

**The 3 load-bearing facts** (from PLAN.md §3.3 — every script depends on these; do not "fix" them):
1. `fresh --cmd daemon new <name>` fails without a TTY (`os error 6`). Daemons are only created by
   `fresh -a <name>` running as the `[[panes]]` command, which herdr gives a real PTY. Never
   pre-create a daemon from a headless action script.
2. `fresh --cmd daemon open-file` requires the target daemon to already exist. "Open file at line"
   must ensure the pane is open first.
3. herdr resolves a `[[panes]]` entry's *relative* command against `plugin pane open`'s `--cwd`,
   **not** the plugin root. Passing the target repo cwd caused the silent exit-127 flash-and-close
   fixed in v0.1.1. Launchers must **omit `--cwd`**; `run-fresh-daemon.sh`'s own `cd` moves Fresh
   into the target dir.

## Non-negotiable constraints (guardrails — from PLAN.md §2.2)

- **No editor code.** Anything editor-shaped goes upstream to Fresh, never implemented here.
- **No fork/patch of Fresh.** Integrate only via its documented CLI/daemon surface.
- **No bundled Fresh binary.** Install locates/installs it at build time.
- **No bespoke TUI/rendering.** Fresh is the UI.
- **Config trust model:** `config.toml` is read only from `$HERDR_PLUGIN_CONFIG_DIR` (or the
  XDG/HOME fallback) — **never** from a repo's cwd. Do not add a cwd-relative config path.
- **Every `.sh` launcher has a behavior-equivalent `.ps1`**, or the gap is noted in
  `docs/windows.md`. Action ids are unique across platforms (`-windows` suffix for Windows).
- **Docs stay in sync with code** in the same change.

## Environment / how to verify

- **No live-herdr requirement for most tasks.** Tasks are designed to be testable with mock
  `herdr`/`fresh` shims (see task M8.2). Tasks needing real binaries are flagged
  `Needs: live herdr+fresh` and may be handed to a human/CI instead.
- Current tooling on dev host: `jq`, `python3` present; `shellcheck` **not** installed locally
  (CI runs it). Verified stack: herdr 0.7.0, fresh 0.4.1.
- Repo root is the git root. Scripts live in `scripts/`, docs in `docs/`, CI in
  `.github/workflows/ci.yml`.

---

## Progress tracker

| Task | Title | Tier | Status | Depends on |
|---|---|---|---|---|
| M8.1 | Test harness + CI job scaffolding | 1 | READY | — |
| M8.2 | Mock `herdr`/`fresh` shims | 1 | READY | M8.1 |
| M8.3 | bats unit tests for `common.sh` | 1 | BLOCKED | M8.2 |
| M8.4 | bats launcher/behavioral tests | 1 | BLOCKED | M8.2 |
| M8.5 | Pester tests for `.ps1` launchers | 1 | BLOCKED | M8.2 |
| M9.1 | `notify()` error-surfacing helper | 1 | READY | — |
| M9.2 | Guard every silent failure path | 1 | BLOCKED | M9.1 |
| M9.3 | Bounded/observable daemon-wait | 2 | BLOCKED | M9.1 |
| M9.4 | Validate `open-file` target arg | 2 | READY | — |
| M9.5 | `HERDR_FRESH_DEBUG` verbose logging | 4 | BLOCKED | M9.1 |
| M10.1 | Platform support matrix in README | 1 | READY | — |
| M10.2 | macOS verification pass | 1 | READY | Needs: macOS host |
| M10.3 | Windows verification or "experimental" label | 1 | READY | Needs: Windows host |
| M10.4 | Dependency auto-install + guidance (jq/python3) | 1 | READY | — |
| M11.1 | Robust daemon detection (drop `grep -qx`) | 2 | READY | — |
| M11.2 | Runtime version/capability detection | 2 | READY | — |
| M11.3 | Concurrency lock on pane-open | 2 | BLOCKED | M9.1 |
| M11.4 | Unified single-source config parser | 3 | READY | — |
| M12.1 | CHANGELOG.md (backfilled) | 3 | DONE | — |
| M12.2 | Release workflow + version↔tag gate | 3 | READY | M12.1 |
| M12.3 | Strengthen CI (shfmt, pins, win runner, md-links) | 3 | READY | M8.1 |
| M12.4 | Standalone `herdr-fresh open` helper | 3 | READY | M9.4 |
| M12.5 | Troubleshooting + compatibility docs | 4 | READY | — |
| M12.6 | Uninstall/daemon-cleanup path | 4 | READY | — |
| M12.7 | File post-v1 backlog as GitHub issues | 4 | READY | — |

**Legend:** `READY` = startable now · `BLOCKED` = waiting on a dependency · `DONE` = merged +
verified. `Needs:` flags a task requiring resources the default agent may lack (hand to human/CI).

---

# Tier 1 — Blockers (must ship before calling it production-ready)

## M8 — Safety net (behavioral tests without live herdr)

### Task M8.1 — Test harness + CI job scaffolding
- **Status:** READY · **Depends on:** — · **Tier:** 1
- **Why:** Today "verification" is `bash -n` + shellcheck (syntax only). No behavioral tests, so
  refactors are unsafe and regressions like the v0.1.1 `--cwd` bug only surface by hand.
- **Files:** `test/` (new), `.github/workflows/ci.yml`, `docs/` (contributor note), `AGENTS.md`.
- **Do:**
  1. Add [bats-core](https://github.com/bats-core/bats-core) as the bash test runner (vendored as
     a git submodule under `test/bats/` or installed in CI via apt/npm — pick one and document it).
  2. Create `test/helpers.bash` with common setup (temp dirs, `PATH` shimming hook for M8.2).
  3. Add a `bats` CI job to `ci.yml` (Ubuntu) that runs `test/*.bats`. Make it a required check.
  4. Update `AGENTS.md`'s "Verifying changes locally" section to mention `bats test/`.
- **Acceptance criteria:** `bats test/` runs green locally and in CI (even with just a trivial
  smoke test initially); CI job is present and required.
- **Verification:** `bats test/` exits 0; CI workflow YAML parses (`python3 -c "import yaml,sys;
  yaml.safe_load(open('.github/workflows/ci.yml'))"` — note: needs pyyaml, else eyeball).
- **Handoff note:** Prefer the submodule approach for bats to avoid a network dependency in CI;
  if using apt, pin the version.

### Task M8.2 — Mock `herdr`/`fresh` shims
- **Status:** READY · **Depends on:** M8.1 · **Tier:** 1
- **Why:** Launchers shell out to `herdr` and `fresh`. To test behavior without live binaries we
  need fakes on `PATH` that record the args they were called with and emit canned JSON.
- **Files:** `test/mocks/herdr`, `test/mocks/fresh` (new, executable), `test/helpers.bash`.
- **Do:**
  1. Write shim scripts that append their argv to `$MOCK_CALL_LOG` and print canned responses
     driven by env vars (e.g. `MOCK_PANE_LIST_JSON`, `MOCK_DAEMON_LIST`).
  2. Add a helper that prepends `test/mocks` to `PATH` and sets `HERDR_BIN_PATH` to the mock.
  3. Provide fixtures: a `pane list` JSON with/without a matching `label`, a `daemon list` sample.
- **Acceptance criteria:** A test can invoke a launcher, then assert on `$MOCK_CALL_LOG` contents
  (exact flags passed to `herdr`/`fresh`).
- **Verification:** A throwaway test asserting `open-fresh.sh` produced a `plugin pane open` line
  in the log passes.

### Task M8.3 — bats unit tests for `common.sh`
- **Status:** BLOCKED (M8.2) · **Tier:** 1
- **Why:** `common.sh` holds all the pure logic (naming, resolution, config). Unit-testable
  without any herdr/fresh.
- **Files:** `test/common.bats`.
- **Do:** Cover, at minimum:
  - `daemon_name` for `per-workspace` (uses workspace id) and `per-repo` (hashes cwd), plus custom
    `daemon_name_prefix`.
  - `resolve_workspace_id` / `resolve_focused_pane_id` / `resolve_tab_id` / `resolve_cwd`:
    context-JSON path wins; falls back correctly when the env var is empty.
  - `config_get` fallbacks: missing key → default; malformed config → default; **non-absolute
    config path → `{}` (untrusted-cwd guard)**; missing `python3` → defaults.
  - `fresh_bin` / `fresh_args` defaults and overrides.
- **Acceptance criteria:** Each helper has ≥1 happy-path and ≥1 fallback test; the untrusted-cwd
  guard is explicitly asserted.
- **Verification:** `bats test/common.bats` green.

### Task M8.4 — bats launcher/behavioral tests
- **Status:** BLOCKED (M8.2) · **Tier:** 1
- **Why:** Guards the integration behavior and the specific v0.1.1 regression.
- **Files:** `test/open-fresh.bats`, `test/open-fresh-tab.bats`, `test/open-file-in-fresh.bats`.
- **Do:** Assert (using mocks):
  - **Regression guard:** `open-fresh.sh` calls `plugin pane open` **without** `--cwd` and **with**
    `--target-pane <focused>` and `--placement split --direction right`.
  - **Idempotent focus:** with a `pane list` fixture containing a matching `label`, `open-fresh.sh`
    does **not** call `plugin pane open` again and instead zooms the existing pane.
  - `open-fresh-tab.sh`: opens with `--placement tab --workspace <id>`; focuses existing tab when
    the label already exists.
  - `open-file-in-fresh.sh`: when daemon absent → calls `open-fresh.sh` then
    `daemon open-file <daemon> <target>`; rejects empty arg with usage error/exit 1.
- **Acceptance criteria:** All four behaviors asserted; the no-`--cwd` regression test present.
- **Verification:** `bats test/*.bats` green.

### Task M8.5 — Pester tests for `.ps1` launchers
- **Status:** BLOCKED (M8.2) · **Tier:** 1
- **Why:** Windows launchers have zero behavioral coverage. Mirror the bats coverage.
- **Files:** `test/*.Tests.ps1`, `.github/workflows/ci.yml` (Pester job — ideally `windows-latest`).
- **Do:** Port M8.3/M8.4 assertions using Pester + PowerShell command mocks (`Mock` on the herdr/
  fresh invocations). Add a CI job.
- **Acceptance criteria:** Pester suite runs in CI; covers daemon-name resolution, the no-`--cwd`
  regression, and idempotent focus.
- **Verification:** `Invoke-Pester test/` green in CI.
- **Handoff note:** Runs best on a real `windows-latest` runner; pwsh-on-Linux is acceptable for
  logic tests but won't catch Windows-specific path issues.

## M9 — No silent failures

### Task M9.1 — `notify()` error-surfacing helper
- **Status:** READY · **Depends on:** — · **Tier:** 1
- **Why:** THE top production liability. Everything uses `|| true` / `2>/dev/null`, so failures are
  invisible (split flashes and closes). Users get no signal and no diagnostic.
- **Files:** `scripts/common.sh`, `scripts/common.ps1`, `docs/troubleshooting.md` (new, stub ok).
- **Do:**
  1. Add `notify <level> <message>` to both commons. Preference order for the channel:
     (a) a herdr notification CLI if one exists (probe `herdr --help`/`herdr notify`);
     (b) append to `${HERDR_PLUGIN_STATE_DIR:-$config_dir}/herdr-fresh.log` with a timestamp;
     (c) echo to stderr. Always do (b)+(c); add (a) if available.
  2. Establish a state-dir resolver mirroring `_config_dir`'s trust rules (never cwd).
- **Acceptance criteria:** `notify error "x"` writes a timestamped line to the log file and stderr;
  never reads/writes under the repo cwd.
- **Verification:** bats test (after M8.2) asserting the log line; manual `HERDR_PLUGIN_STATE_DIR=
  /tmp/s notify error hi` shows the line.
- **Handoff note:** Confirm whether herdr 0.7.0 exposes a notification/report CLI before wiring
  (a); if unknown, ship (b)+(c) and leave a TODO with the exact command to probe.

### Task M9.2 — Guard every silent failure path
- **Status:** BLOCKED (M9.1) · **Tier:** 1
- **Why:** Turn each opaque failure into a specific, actionable message.
- **Files:** all `scripts/*.sh` and `scripts/*.ps1`.
- **Do:**
  - Runtime `command -v "$(fresh_bin)"` guard in each action script → `notify` "Fresh not
    installed — see getfresh.dev / re-run herdr plugin install" and exit non-zero.
  - Check `plugin pane open` exit status; on non-zero, `notify` the failure instead of `exec`-and-
    forget where feasible.
  - In `run-fresh-daemon.sh`, if the final `exec fresh …` can't start, `notify` and hold the pane
    (e.g. `read -r -t 10` or print then sleep) so the error is legible, not a flash-and-close.
  - Replace bare `|| true` on user-visible operations with `|| notify …`.
- **Acceptance criteria:** Missing-Fresh, failed-pane-open, and failed-daemon-start each produce a
  distinct message; no user-visible operation fails completely silently.
- **Verification:** bats tests (M8.4) with mocks returning non-zero assert a `notify`/log line.

### Task M9.3 — Bounded, observable daemon-registration wait
- **Status:** BLOCKED (M9.1) · **Tier:** 2
- **Why:** `open-file-in-fresh.sh` polls `seq 1 50; sleep 0.2` (silent 10s), then calls
  `daemon open-file` even on timeout — a silent no-op if the daemon never came up.
- **Files:** `scripts/open-file-in-fresh.sh`, `.ps1` counterpart, `config.example.toml`,
  `docs/configuration.md`.
- **Do:** Make timeout/interval config-driven (`open_file_timeout_ms`, default 10000). On timeout,
  `notify` a specific message and exit non-zero **before** attempting `open-file`. Re-check the
  daemon exists after the loop and branch on it.
- **Acceptance criteria:** Timeout emits a clear message and does not call `open-file`; timeout is
  configurable and documented.
- **Verification:** bats test with a mock `fresh` whose `daemon list` never lists the daemon →
  asserts the timeout notification and no `open-file` call.

### Task M9.4 — Validate the `open-file` target argument
- **Status:** READY · **Depends on:** — · **Tier:** 2
- **Why:** `$1` (`path:line:col`) is forwarded raw. It's a programmatic entry point for other
  agents/plugins; a sanity check + documented trust boundary is warranted.
- **Files:** `scripts/open-file-in-fresh.sh`, `.ps1`, `SECURITY.md`.
- **Do:** Validate the arg matches `path[:line[:col]]` (line/col numeric); reject empty/malformed
  with the existing usage error (extend it). Add a SECURITY.md note: this action forwards a
  caller-supplied path into Fresh; caller owns the path, Fresh Workspace Trust governs execution.
- **Acceptance criteria:** Empty and clearly-malformed inputs exit non-zero with a usage message;
  valid `README.md:5:3` passes through unchanged.
- **Verification:** bats cases for empty, `foo:bar` (non-numeric line), and `README.md:5:3`.

### Task M9.5 — `HERDR_FRESH_DEBUG` verbose logging
- **Status:** BLOCKED (M9.1) · **Tier:** 4
- **Why:** Diagnosing "nothing happened" currently requires editing scripts to remove
  `2>/dev/null`.
- **Files:** `scripts/common.sh`, `scripts/common.ps1`, `docs/troubleshooting.md`.
- **Do:** When `HERDR_FRESH_DEBUG=1`, route the suppressed stderr and key decision points to the
  state-dir log (or stderr). Document it.
- **Acceptance criteria:** With the flag set, a run logs the resolved daemon name, pane ids, and
  each herdr/fresh call; without it, behavior is unchanged.
- **Verification:** bats test toggling the env var asserts extra log lines appear/disappear.

## M10 — Platform truth & dependencies

### Task M10.1 — Platform support matrix in README
- **Status:** READY · **Depends on:** — · **Tier:** 1
- **Why:** README says "cross-platform" but only Linux is real-herdr verified; the ambiguity is a
  credibility/support risk.
- **Files:** `README.md`.
- **Do:** Add a table: OS (Linux/macOS/Windows) × capability (install, split, tab, open-at-line,
  editor-integration) with cells marked **verified / lint-only / unsupported**. Reflect *current*
  reality (Linux verified; Windows lint-only; macOS pending until M10.2).
- **Acceptance criteria:** Matrix present, accurate, and linked from the status blurb.
- **Verification:** Manual read; no claim of "verified" for an unverified cell.

### Task M10.2 — macOS verification pass
- **Status:** READY · **Needs: macOS host** · **Tier:** 1
- **Why:** PLAN lists macOS as first-class but it's not independently verified; BSD userland
  differs (grep/sed/sleep/cksum).
- **Files:** `PLAN.md` (milestone note), `README.md` (matrix), possibly `scripts/*.sh` fixes.
- **Do:** On macOS, run the M1–M3 flow via `herdr plugin link`; confirm `grep -qx`, fractional
  `sleep 0.2`, `cksum`, `seq` behave. Fix any BSD incompatibilities. Record results.
- **Acceptance criteria:** Split/tab/open-at-line work on macOS or gaps are documented + fixed;
  matrix updated to "verified".
- **Verification:** Manual real-herdr pass; `bats` still green.
- **Handoff note:** If no macOS host, hand to a maintainer; CI `macos-latest` can cover install
  smoke + `bash -n` but not a real herdr link.

### Task M10.3 — Windows: verify or label "experimental"
- **Status:** READY · **Needs: Windows host** · **Tier:** 1
- **Why:** Windows launchers are lint-only; status is ambiguous.
- **Files:** `README.md`, `docs/windows.md`, GitHub issue.
- **Do:** Either (a) real `herdr plugin link` pass on Windows → promote to "supported" in the
  matrix, or (b) label Windows **experimental** in README (not just windows.md) and open a
  tracking issue listing the untested paths.
- **Acceptance criteria:** No ambiguous status remains; README matrix + windows.md agree.
- **Verification:** Manual.

### Task M10.4 — Dependency auto-install + per-OS guidance (jq/python3)
- **Status:** READY · **Depends on:** — · **Tier:** 1
- **Why:** `install.sh` only *checks* for `jq` and fails; no install, no per-OS guidance. `python3`
  needed for config. A user without jq gets a dead-end build failure.
- **Files:** `scripts/install.sh`, `scripts/install.ps1`, `docs/install.md`.
- **Do:** Attempt to install `jq` via the platform package manager (apt/dnf/brew; winget/choco on
  Windows) with a clear fallback message and per-OS manual instructions in docs. **Also evaluate
  reducing the dependency surface** (see M11.4 — moving config queries into python removes jq from
  the config path; assess whether herdr JSON parsing can drop jq too). At minimum, emit the
  OS-appropriate install command on failure instead of a generic error.
- **Acceptance criteria:** Missing `jq` triggers an install attempt + actionable guidance; docs
  list the manual command per OS.
- **Verification:** CI install-smoke still passes; manual run on a jq-less container shows the
  guidance path.

---

# Tier 2 — Reliability & correctness hardening

### Task M11.1 — Robust daemon detection (drop `grep -qx "  $daemon"`)
- **Status:** READY · **Depends on:** — · **Tier:** 2
- **Why:** `open-file-in-fresh.sh` detects a daemon via a hard-coded two-space-prefixed exact
  match on `fresh --cmd daemon list` output. Any formatting change silently breaks detection.
- **Files:** `scripts/open-file-in-fresh.sh`, `scripts/common.sh` (add a helper), `.ps1`.
- **Do:** Prefer a structured/robust check: try `fresh --cmd daemon info <name>` exit code as an
  existence test, or `daemon list --json` if available. If only text exists, match on word
  boundary, not leading whitespace. Add a `daemon_exists <name>` helper in common.
- **Acceptance criteria:** Detection works across several plausible list formats; no hard-coded
  whitespace prefix.
- **Verification:** bats test feeding 3+ `daemon list` format variants to a mock `fresh`.
- **Handoff note:** Probe real `fresh 0.4.1` for whether `daemon info` / `--json` exist before
  committing to one; document the chosen mechanism.

### Task M11.2 — Runtime version/capability detection
- **Status:** READY · **Depends on:** — · **Tier:** 2
- **Why:** Manifest declares `min_herdr_version` and PLAN promises feature-detection, but nothing
  checks at runtime. A changed CLI surface fails opaquely.
- **Files:** `scripts/common.sh`, `scripts/common.ps1`, `README.md` (version range).
- **Do:** Add a cached per-process probe confirming `fresh --cmd daemon` exists; on mismatch,
  `notify` (or stderr) the tested version range. Pin and document tested herdr/fresh ranges.
- **Acceptance criteria:** Absent `--cmd daemon` support produces a clear version-range message;
  README documents the tested range.
- **Verification:** bats test with a mock `fresh` lacking the subcommand asserts the warning.

### Task M11.3 — Concurrency lock on pane-open
- **Status:** BLOCKED (M9.1) · **Tier:** 2
- **Why:** `open-file-in-fresh` auto-opening while `open-fresh` is mid-flight can race two
  `plugin pane open` calls for the same daemon.
- **Files:** `scripts/common.sh` (lock helper), `scripts/open-fresh.sh`,
  `scripts/open-file-in-fresh.sh`, `.ps1` counterparts.
- **Do:** Serialize the ensure-pane-open path with `flock` on
  `$STATE_DIR/<daemon>.lock` (bash) / a named mutex (PowerShell). Best-effort: if `flock` absent,
  proceed (don't hard-fail).
- **Acceptance criteria:** Two concurrent invocations don't open two panes for one daemon.
- **Verification:** bats test launching two invocations in parallel against mocks asserts a single
  `pane open`.

### Task M11.4 — Unified, single-source config parser
- **Status:** READY · **Depends on:** — · **Tier:** 3
- **Why:** Config parsing splits across python3 (TOML→JSON) + jq (query) and diverges between
  `.sh` and `.ps1`. Maintenance drag + drift risk; also blocks dropping jq (M10.4).
- **Files:** `scripts/config.py` (new, single source of truth), `scripts/common.sh`,
  `scripts/common.ps1`, tests, `docs/configuration.md`.
- **Do:** One small python entry point resolves all config values (respecting the trust rules) and
  emits `KEY=VALUE` lines. Both bash and PowerShell consume that identical output — no per-platform
  parsing logic, and the config path no longer needs jq.
- **Acceptance criteria:** bash and PowerShell get identical resolved values from the same parser;
  jq removed from the config path; trust guard preserved.
- **Verification:** bats + Pester assert identical resolved values for the same config fixture,
  including malformed → defaults and non-absolute path → defaults.

---

# Tier 3 — Release engineering & maintainability

### Task M12.1 — CHANGELOG.md (backfilled)
- **Status:** DONE — created `CHANGELOG.md` (Keep a Changelog), backfilled v0.1.0/v0.1.1 from
  PLAN.md M0–M7, with an `Unreleased` section wired into the trunk-based flow. · **Tier:** 3
- **Why:** PLAN §8 promises "CHANGELOG.md from tags" but none exists; v0.1.0/v0.1.1 have no
  user-facing changelog.
- **Files:** `CHANGELOG.md` (new).
- **Do:** Keep a Changelog format; backfill v0.1.0 and v0.1.1 from the M0–M7 history in PLAN.md.
- **Acceptance criteria:** Entries for both released tags + an `Unreleased` section.
- **Verification:** Manual; links resolve.

### Task M12.2 — Release workflow + version↔tag consistency gate
- **Status:** READY · **Depends on:** M12.1 · **Tier:** 3
- **Why:** Version lives in manifest + tag + README by hand; easy to desync.
- **Files:** `.github/workflows/release.yml` (new), `.github/workflows/ci.yml`.
- **Do:** On tag push: re-run full CI, generate release notes from CHANGELOG, create the GitHub
  Release. Add a CI check asserting `herdr-plugin.toml` `version` == pushed tag (minus `v`).
- **Acceptance criteria:** Tagging `vX.Y.Z` with a mismatched manifest version fails CI; a matching
  tag produces a Release.
- **Verification:** Dry-run on a test tag in a branch/fork.

### Task M12.3 — Strengthen CI
- **Status:** READY · **Depends on:** M8.1 · **Tier:** 3
- **Why:** CI gaps: shellcheck `@master` (unpinned) at `warning` only; no `shfmt`; the "windows"
  job runs pwsh on **Linux**, not a real Windows runner; no markdown link check.
- **Files:** `.github/workflows/ci.yml`.
- **Do:** Pin `action-shellcheck` to a release tag; add a `shfmt` formatting gate; add a real
  `windows-latest` job (manifest parse + install smoke, + Pester once M8.5 lands); add a Markdown
  link-check job (docs cross-reference heavily).
- **Acceptance criteria:** All new gates present and green; actions pinned (no `@master`).
- **Verification:** CI passes on a PR; broken markdown link fails the link job.

### Task M12.4 — Standalone `herdr-fresh open <path:line>` helper
- **Status:** READY · **Depends on:** M9.4 · **Tier:** 3
- **Why:** PLAN M3 deferred it, but "push path:line:col from any pane, agent, or script" is a named
  v1 capability. Agents shouldn't need `herdr plugin action invoke`.
- **Files:** `bin/herdr-fresh` (new), `bin/herdr-fresh.ps1`, `docs/usage.md`, README.
- **Do:** Thin dispatcher exposing `open <target>` that reuses `open-file-in-fresh.sh`. Document an
  agent-pushing-a-file example.
- **Acceptance criteria:** `herdr-fresh open README.md:5` routes to the open-file flow; documented.
- **Verification:** bats test asserting the dispatcher calls the underlying script with the arg.

### Task M12.5 — Troubleshooting + compatibility docs
- **Status:** READY · **Depends on:** — · **Tier:** 4
- **Why:** Production users need a failure-mode→fix map and a version-support policy.
- **Files:** `docs/troubleshooting.md`, `README.md` (compat section), link from docs index.
- **Do:** Table the top failure modes (fresh not on PATH, jq missing, daemon didn't register,
  wrong workspace) each with the diagnostic command + fix. Pin tested herdr/fresh versions +
  support policy.
- **Acceptance criteria:** Each Tier-1/2 failure path has a troubleshooting entry; compat section
  present.
- **Verification:** Manual; cross-links resolve.

### Task M12.6 — Uninstall / daemon-cleanup path
- **Status:** READY · **Depends on:** — · **Tier:** 4
- **Why:** Plugin leaves daemons, labels, lock files, logs behind; uninstall behavior undocumented.
- **Files:** `docs/install.md` (uninstall section), optional `scripts/uninstall.sh`/`.ps1`.
- **Do:** Document (and optionally script) daemon cleanup (`fresh --cmd daemon kill`) and list all
  state the plugin creates and where.
- **Acceptance criteria:** Uninstall docs list every state artifact + cleanup command.
- **Verification:** Manual walkthrough.

### Task M12.7 — File post-v1 backlog as GitHub issues
- **Status:** READY · **Depends on:** — · **Tier:** 4
- **Why:** PLAN §6's post-v1 backlog should be public/tracked, with PLAN staying design-of-record.
- **Files:** GitHub issues (no repo files, or a short `docs/roadmap.md` linking them).
- **Do:** Open issues for: SSH remote-edit action, git-review launch action, devcontainer
  awareness, Fresh↔herdr metadata plugin — using the `feature_request` template.
- **Acceptance criteria:** One tracked issue per backlog item.
- **Verification:** Issues exist and link back to PLAN §6.

---

## Milestone rollup & v1.0.0 exit criteria

| Milestone | Tasks | Exit criteria |
|---|---|---|
| **M8 — Safety net** | M8.1–M8.5 | Behavioral tests (bats + Pester) green in CI on every PR |
| **M9 — No silent failures** | M9.1–M9.5 | Every failure path emits a specific user-visible message; regression-tested |
| **M10 — Platform truth** | M10.1–M10.4 | README matrix reflects *verified* reality; deps auto-install or fail with guidance |
| **M11 — Robustness** | M11.1–M11.4 | Daemon detection / version / concurrency / config hardened + tested |
| **M12 — Release discipline** | M12.1–M12.7 | CHANGELOG + release automation + version↔tag gate; standalone `open` helper; troubleshooting docs |

**Tag `v1.0.0`** once: M8–M12 land, **and** both Linux and macOS are verified (M10.2), **and**
Windows status is unambiguous (M10.3 — supported or clearly experimental).

---

*This plan lives at `docs/plans/production-readiness.md`. It is the execution companion to
[`PLAN.md`](../../PLAN.md) (the design-of-record). When a task changes verified behavior, update
both in the same change.*
