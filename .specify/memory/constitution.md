<!--
SYNC IMPACT REPORT
==================
Version change: (unversioned template) → 1.0.0
Modified principles: N/A — initial ratification, all sections new
Added sections: Core Principles (I–V), Technology Constraints, Development Workflow, Governance
Removed sections: N/A
Templates reviewed:
  ✅ .specify/templates/plan-template.md — Constitution Check gate reads dynamically from this file; no hardcoded names to update
  ✅ .specify/templates/spec-template.md — No constitution references; no changes required
  ✅ .specify/templates/tasks-template.md — No constitution references; no changes required
  ✅ .specify/templates/agent-file-template.md — No constitution references; no changes required
Deferred TODOs: none
-->

# Fahrplan Constitution

## Core Principles

### I. Thin Executable, Rich Library

The `Fahrplan` binary MUST remain a thin dispatcher — it reads the `mode` environment variable
and delegates immediately to a handler in `FahrplanLib`. All logic MUST live in `FahrplanLib`
so it can be tested independently of Alfred's runtime environment.

**Rationale**: Alfred invokes the binary as a black box; keeping the library separate allows
unit and integration tests to exercise every code path without requiring Alfred to be running.

### II. Alfred JSON Protocol

All output MUST be written to stdout as valid Alfred Script Filter JSON, produced through the
`Workflow` and `Item` types in `Alfred.swift`. No direct `print` of raw strings as final
output is permitted. Diagnostic output MUST go to stderr via `log()` / `debug()`.

**Rationale**: Alfred's UI is driven entirely by the JSON it receives; any malformed or
unexpected stdout will silently break the workflow for the end user.

### III. Mode-Based Dispatch Is the Public Contract

The `mode` environment variable is the sole interface between Alfred and the binary. Adding a
new user-facing feature MUST be modelled as a new mode (or an extension of an existing one)
and documented in the dispatch table in `CLAUDE.md`. No feature MUST rely on undocumented
side-effects of another mode's execution.

**Rationale**: Alfred wires modes to UI actions in `info.plist`; an undocumented dependency
between modes cannot be expressed in the Alfred editor and will produce hard-to-debug failures.

### IV. Alfred Directories for All Persistent State

Runtime state MUST be stored exclusively in `$alfred_workflow_data` (favourites, home station)
and `$alfred_workflow_cache` (trip results for pagination). No other filesystem paths, no
`UserDefaults`, no embedded databases.

**Rationale**: Alfred manages the lifecycle of these directories (backup, migration, uninstall).
Writing outside them produces orphaned files and breaks clean reinstalls.

### V. Simplicity — No Speculative Abstraction

New code MUST solve the problem at hand. Helpers, protocols, or abstractions MUST NOT be
introduced for hypothetical future reuse. Three similar lines of code are preferable to a
premature helper. Dependencies MUST be added only when the standard library cannot do the job.

**Rationale**: This is a single-user productivity tool with one maintainer. Complexity that
exists only to satisfy a design pattern adds maintenance burden with no user benefit.

## Technology Constraints

- **Language / toolchain**: Swift 6.0+; minimum deployment target macOS 14.
- **Package manager**: Swift Package Manager only — no CocoaPods, no Carthage.
- **Testing framework**: `swift-testing` (not XCTest). Unit tests go in `FahrplanTests.swift`;
  network-dependent tests go in `APIIntegrationTests.swift`.
- **Build artefact**: `.build/release/Fahrplan` — this path is referenced by `info.plist` and
  MUST NOT change without a matching plist update.
- **No new runtime dependencies** unless Principle V is explicitly waived with justification.

## Development Workflow

- Run `swift test` before committing; integration tests require network access.
- `make build` produces the release binary; `make clean` removes all build artefacts.
- To run a single test suite: `swift test --filter <SuiteName>`.
- The Alfred plist auto-builds the binary on first run; local dev MUST also test via
  `make build` to catch release-mode compilation issues.

## Governance

This constitution supersedes all other development practices for this repository. Any amendment
MUST update this file, increment `CONSTITUTION_VERSION` following semantic versioning
(MAJOR: principle removal/redefinition; MINOR: new principle or section; PATCH: clarification),
and update `LAST_AMENDED_DATE`. All feature plans MUST include a Constitution Check gate that
verifies the proposed design against all five Core Principles before implementation begins.

**Version**: 1.0.0 | **Ratified**: 2026-03-26 | **Last Amended**: 2026-03-26
