---
name: mindful-environments
description: How MINDFul.jl's Julia environments are laid out — the root Project.toml is the MINDFul package itself, while test/Project.toml is a separate test-only environment that pulls in the package via `dev ..` (a `[sources]` path entry). Use this skill whenever working in the MINDFul.jl repo and you need to add, remove or move a dependency, run or set up the tests, decide which Project.toml to edit, activate an environment, debug "package not found" / "cannot load" errors, touch the TestModule extension in ext/, or reason about CI, docs/ or test/LiveTest environments — even if the user doesn't mention "environments" explicitly.
---

# MINDFul.jl environment layout

MINDFul.jl keeps the package and its test tooling in **separate Julia environments**. Getting this wrong is the most common source of confusing errors (a dependency added to the wrong file, tests loading a registry copy of MINDFul instead of the local source, etc.), so check which environment you are in before changing anything.

## The environments

| Path | Role | Activate with |
|---|---|---|
| `Project.toml` (root) | **The package.** Name, UUID, version, runtime `[deps]`, `[compat]`, `[weakdeps]`, `[extensions]`. This is what users get when they install MINDFul. | `julia --project=.` |
| `test/Project.toml` | **Test-only environment.** Test frameworks, debugging tools (JET, Cthulhu, Revise, TestSetExtensions) and every package the test files `using` directly. Used by CI. | `julia --project=test` |
| `docs/Project.toml` | Documenter build environment. | `julia --project=docs` |
| `test/LiveTest/Project.toml` | Local, interactive experimentation/visualization (GLMakie, profilers). Depends on a sibling checkout `../../../MINDFulMakie.jl`, so it is **not** reproducible on a fresh clone and not used by CI. Leave it alone unless the user asks. | `julia --project=test/LiveTest` |

## How the test environment links to the package

`test/Project.toml` lists `MINDFul` in `[deps]` and pins where it comes from:

```toml
[sources]
MINDFul = {path = ".."}
```

This is exactly what running `pkg> dev ..` from inside the `test` environment records (Julia ≥ 1.11 writes the `[sources]` entry). The consequence: `using MINDFul` in the test environment always loads the **live source in `src/`**, not a registered release. `docs/` uses the same mechanism (`path = ".."`) and `test/LiveTest` uses `path = "../.."`.

`Manifest.toml` is gitignored everywhere, so the `[sources]` entry is the only thing that makes the link survive a fresh clone. Don't remove it, and don't run `pkg> add MINDFul` in the test environment — that would replace the local path with the registry version and tests would silently run against old code. If the link is ever lost, restore it with:

```bash
julia --project=test -e 'using Pkg; Pkg.develop(path=".")'
```

(run from the repo root; the path is relative to the current directory, and Pkg stores it relative to the environment, i.e. `..`).

## Where does a dependency go?

- **Used by code in `src/`** → root `Project.toml`: add to `[deps]` *and* give it a `[compat]` bound (the package is registered, so every dep needs compat). From the root: `julia --project=. -e 'using Pkg; Pkg.add("Foo")'`, then add the compat entry.
- **Only used by tests** → `test/Project.toml` only: `julia --project=test -e 'using Pkg; Pkg.add("Foo")'`. Never put test-only tools in the root `[deps]`; that forces them on every user of the package.
- **Used by both `src/` and directly by test files** → both. Julia only lets you `using Foo` for packages that are *direct* deps of the active environment, so even though MINDFul already depends on e.g. `Graphs`, `test/runtests.jl` can only `using Graphs` because `Graphs` is also listed in `test/Project.toml`. If a test file gains a new `using`/`import`, the package must be added to the test environment.
- **Used by the `TestModule` extension** (`ext/TestModule.jl`) → see below.

After editing the root `Project.toml`, the test environment picks the change up on its next resolve: `julia --project=test -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'`.

## The TestModule extension

Shared test helpers (`testcompilation`, `testinstallation`, `nothingisallocated`, …), the test-network loaders (`loadmultidomaintestibnfs`, …, reading the TOML networks in `test/data`) and the path cache (`setcachedresults!`) live in a package extension, not in `test/`:

- Root `Project.toml` declares `JET`, `Test`, `Random` as `[weakdeps]` and `TestModule = ["JET", "Test", "Random"]` under `[extensions]`.
- The extension code is `ext/TestModule.jl` (+ `ext/TestModule/`).
- Because the test environment has JET, Test and Random installed and loads them, Julia activates the extension automatically. `test/runtests.jl` fetches it with `const TM = Base.get_extension(MINDFul, :TestModule)`, asserts it is not `nothing`, and does `using .TM`: the extension exports the helpers, loaders, suites and the MINDFul names the tests use (the "test prelude").

If `TM` is `nothing`, one of the trigger packages isn't loaded/installed in the active environment — you're probably not running under `--project=test`. If the extension needs a new package that isn't already a MINDFul dep, add it to the root `[weakdeps]` (with `[compat]`), add it to the `TestModule` trigger list, and add it to `test/Project.toml` so it gets loaded.

The root `[extras]` / `[targets] test = ["Test"]` section is a leftover of the older test-dependency mechanism; when `test/Project.toml` exists, Pkg uses that instead. Don't add test deps to `[extras]`.

## Running the tests

Always run from the repo root with the test environment active — this matches CI (`.github/workflows/test.yaml`):

```bash
julia --project=test -e 'using Pkg; Pkg.instantiate()'   # first time / after dep changes
julia --project=test test/runtests.jl                    # full suite
julia --project=test test/runtests.jl --nojet            # skip JET checks (faster)
julia --project=test test/runtests.jl --nosercache       # recompute cached path results
```

`test/runtests.jl` starts with the test prelude (the `using`s, `const TM = …; using .TM`, and `TM.setcachedresults!` with the git-ignored `test/cache/cachedresults.bin`), then includes each `testsuite/*.jl` file.

### Running a single testsuite file

**The test prelude must run once in the Julia session before any `testsuite/*.jl` file.** The testsuite files are not self-contained: they use the names the prelude brings in (`MINDF`, the MINDFul names, `runjet()`, `TESTDATADIR`, loaders like `loadmultidomaintestibnfs`, helpers like `nothingisallocated`, `ExtendedTestSet`, `Edge`, `DateTime`, `u"..."`). Without it, a testsuite file fails with `UndefVarError`s that look like bugs but aren't. In a REPL you only need the prelude once; afterwards you can re-`include` testsuite files repeatedly.

Put throwaway runner/debug scripts in the session scratchpad (not in the repo). A script starts with the prelude lines of `test/runtests.jl`:

```julia
using Test, TestSetExtensions, JET, MINDFul, Graphs, UUIDs, Unitful, UnitfulData, Dates, MbedTLS
const TM = Base.get_extension(MINDFul, :TestModule)
using .TM
TM.setcachedresults!(joinpath(pkgdir(MINDFul), "test", "cache", "cachedresults.bin"))   # reuse the cached paths
include(joinpath(pkgdir(MINDFul), "test", "testsuite", "grooming.jl"))
```

```bash
julia --project=test /path/to/script.jl           # flags like --nojet work here too
```

For an interactive session, `Revise` is in the test environment: `julia --project=test`, then `using Revise` before the prelude, so edits in `src/` are picked up without restarting.

### Simulated time in tests

MINDFul functions take an `offsettime` keyword (added by the `@recvtime` macro) and the simulated clock is `offsettime + (real time spent in the call)`. Simulated time must only move forward. Rules when writing or debugging tests:

- **Always pass `offsettime = nowtime`.** Omitting it defaults to `now()`, the *real* wall clock. Tests use fixed simulated dates (e.g. `DateTime("2026-01-01")`), so a call that silently uses `now()` works until the real date overtakes the simulated one and then fails — a date bomb.
- **Always take the returned time and feed it to the next call.** Every state-changing call returns a `ReturnCodeTime` (`addintent!` a `ReturnUUIDTime`) with the simulated time it finished at: `rc, nowtime = installintent!(...; offsettime = nowtime)`, `uuid, nowtime = addintent!(...)`, `_, nowtime = MINDF.updatelogintentcomp!(...)`, `_, nowtime = setlinkstate!(...)`. Let time pass only explicitly (`nowtime += Dates.Month(3)`) after that.
- **Never reuse an `offsettime`.** Two calls with the same `offsettime` can register their events out of order by a millisecond. The package checks every registered event (intent states, link states, accounted up/down times) and throws `MINDF.SimulatedTimeError` when time would go backwards — if you see one, a call got a stale `offsettime`. (Before this check existed, the symptom was a rare `AssertionError: dt >= zero(dt)` in `src/IBNLayer/availabilityfuncs.jl`.)
- **"Was this logged during the call?" checks:** `t0 = nowtime; rc, nowtime = f(...; offsettime = t0); @test t0 <= logtime <= nowtime`. Don't compare a log time against the *returned* time with `logtime - nowtime >= 0` — the returned time is the end of the call, so it is always ≥ the log time.
- The one deliberate exception is back-dating link events to fabricate link history while no intent uses the link (`test/testsuite/singledomainavailabilityprotection.jl`); each edge's own log must still be in order.
- **Don't assert exact zero/equal durations.** Real compute time leaks into the simulated clock (JIT compilation can add tens of ms on a cold run), so compare durations with a tolerance (the suite uses ±`Dates.Second(5)`). A test that passes in the full suite but fails when run alone is often this: in the full suite the code is already compiled, so the leak is ~0 ms.

## Julia version note

`[sources]` is honored from Julia 1.11 on, while the root `[compat]` says `julia = "1.8"`. Older Julia versions ignore `[sources]`, so the test environment would not find the local MINDFul. Use a recent Julia (the README advises following the latest release; docs CI pins 1.12.x).

JET is tightly coupled to the Julia minor version (e.g. Julia 1.13 only accepts JET 0.12.x). Because JET is a `[weakdeps]` of the package *with a `[compat]` bound in the root Project.toml*, that bound also constrains the test environment. If `Pkg.instantiate()`/`resolve()` in `test/` fails with "Unsatisfiable requirements detected for package JET … no versions left", the fix is the JET entry in the root `[compat]`, not anything in `test/Project.toml`.
