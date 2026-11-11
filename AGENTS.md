# AGENTS.md

Context for AI agents working on MINDFul.jl: a Julia framework for intent-driven multi-domain IP-optical network coordination, used for simulations.
Details are in `.agents/skills/*/SKILL.md` (plain Markdown, readable by any agent; `.claude/skills/` only links to them):
`mindful-environments` (environments, running tests, simulated time) and `solving-issues-with-worktree` (how issues are fixed).

## Layout
- `src/`: the package. `src/IBNLayer/` holds intents, the intent DAG, compilation (`compilationtemplate.jl`) and the algorithm interface (`policiesinterfaces.jl`, `Policies/` with `KShorestPathFirstFitCompilation`, `BestEmpiricalAvailabilityCompilation`, `BestAverageEmpiricalAvailabilityCompilation`). `src/PhyLayer/` and `src/SDNLayer/` hold the physical resources and their reservations.
- `ext/TestModule.jl` + `ext/TestModule/`: the test extension (helpers, test networks, test suites). It loads when `Test` and `JET` are loaded.
- `test/`: `runtests.jl` and `testsuite/*.jl`. The test networks are TOML files in `test/data/`.
- `docs/`: Documenter site; `docs/src/dev.md` describes the algorithm interface and testing.

## Environments and running
- The root `Project.toml` is the package; `test/Project.toml` is a separate test environment that uses the local package. Run everything from the repo root with `--project=test`.
- `julia` may be missing from PATH in an agent's (non-interactive) shell: juliaup adds it only in interactive shell startup files. Call the juliaup binary directly, e.g. `~/.juliaup/bin/julia`.
- Full suite (about 3-5 minutes): `julia --project=test test/runtests.jl`. Arguments: `--nojet` skips the JET checks; `--nosercache` recalculates the cached paths.
- The calculated candidate paths of the test networks are cached in the git-ignored `test/cache/cachedresults.bin` (`TM.setcachedresults!`); the cache key includes the network file content.
- A script or REPL session needs the test prelude of `test/runtests.jl` before including a `testsuite/*.jl` file:
  ```julia
  using Test, TestSetExtensions, JET, MINDFul, Graphs, UUIDs, Unitful, UnitfulData, Dates, MbedTLS
  const TM = Base.get_extension(MINDFul, :TestModule)
  using .TM
  ```
- Scratch scripts and logs don't belong in the repo (`test/tmp/` is an old, unused scratch folder).

## Testing conventions
- **Core tests for compilation algorithms:** `TM.testsuitecompilationalgorithm(alg)` (`ext/TestModule/conformance.jl`) checks behaviour every algorithm must have (lifecycle in one and in several domains, 100 random intents, clean failed compilations). External packages with their own algorithm run it in their tests; MINDFul runs it for its own algorithms and an example external one (`test/testsuite/conformance.jl`). Tests of KSP's specific choices (exact paths, slots, grooming) stay in the other test files.
- **Simulated time:** always pass `offsettime = nowtime` and continue with the returned time (`rc, nowtime = f(...; offsettime = nowtime)`); never reuse an `offsettime`. Going back in time throws `MINDF.SimulatedTimeError`.
- Keep new tests minimal: prefer a few `@test`s in an existing file over a new file; the suite is already large.

## Writing a compilation algorithm
- Copy the pattern of `src/IBNLayer/Policies/ibn_kspffcompilation.jl`:
  - a struct with `candidatepathsnum`, `cachedresults` and `basicalgmem`;
  - the constructors `(ibnag, k)`, `(k; nodenum)` and `(alg, cachedresults)`; the test networks use the last one per domain;
  - `compileintent!` built on `compileintenttemplate!` / `intradomaincompilationtemplate` with your policy functions.
- Define `compileintent!` with `MINDF.@recvtime` and pass `MINDF.@passtime` to nested calls. The macro expansion calls `now()` unqualified, so import `Dates: now` in your module.
- Check it with `TM.testsuitecompilationalgorithm(MyAlg(10; nodenum = 1))`.

## Pitfalls
- **Availability split:**
  - The two halves of a split `AvailabilityConstraint` must together meet the master compliance target: `ct1 * ct2 >= ct`.
  - After the first half is compiled, the second half is recomputed with `sqrt(ct)` (`calcsecondhalfavailabilityconstraint`, `src/IBNLayer/policiesinterfaces.jl:91`, `src/IBNLayer/compilationtemplate.jl:1386`). So any planner must give the first half at least `sqrt(ct)` (`src/IBNLayer/compilationtemplate.jl:1345`).
  - The second half planned in the `SplitGlobalNode` is never used.
- **Protection pairs:** only intents with an `OpticalTerminateConstraint` need both paths to share the last hop, because the remote domain gets a single `OpticalInitiateConstraint` (`src/IBNLayer/compilationtemplate.jl:1461`). Other protected intents should get disjoint pairs.
- **Dispatch on the estimate type:**
  - `BestAverageEmpiricalAvailabilityCompilation` estimates are plain `Float64` (`mean`), so it runs on the generic methods in `src/IBNLayer/policiesinterfaces.jl`, not on its `DiscreteNonParametric` methods (e.g. `src/IBNLayer/Policies/ibn_bestaverageempiricalavailabilitymatch.jl:154` is never called).
  - A change to an estimator's return type changes which planner runs.
- **Border nodes:**
  - A domain's graph contains the neighbouring domains' border nodes (another `globalnode_ibnfid`).
  - An intent whose destination is a border node is split at that node, so `estimatecrossconnectionavailability` can get a self-edge `GlobalEdge(n, n)`.
- **Staged vs reserved:**
  - Compiling stages resources; installing reserves them.
  - A failed compilation must leave nothing staged in any domain.
  - The tests check this with `nothingisallocated`, `testzerostaged` and `testoxcfiberallocationconsistency`.
- **Return values:**
  - The user-facing calls return a `ReturnCodeTime` (`addintent!` a `ReturnUUIDTime`). Destructure it as `rc, nowtime = f(...)`; it can't be indexed with `[1]`.
  - Return codes are `Symbol`s; test them with `issuccess`.
  - `@returniffalse` (`src/generic/macromagic.jl:8`) returns `ReturnCodes.FAIL`, so it doesn't belong in functions that return a `Bool` or a value.
- **Path cache keys:** `CachedResults` cached by `(ibnfid, k)` alone mix up different graphs with the same domain id (both test networks have a domain 1). The TestModule's key also includes the network file content.
- **`default_IBNAttributeGraph`** (`src/generic/defaults.jl:113`) only accepts an `AG.OAttributeGraph` built with `vertex_type = Dict{Symbol}, edge_type = Dict{Symbol}, graph_type = Dict{Symbol, Any}`; other attribute types give a `MethodError`.
- **TestModule code:** top-level code in an extension runs at precompile time, so read `ARGS` or the environment inside functions (e.g. `runjet()`).
- **JET** versions are tied to the Julia minor version. If `Pkg.resolve` fails on JET in the test environment, the fix is JET's `[compat]` bound in the root `Project.toml`.

## Working agreements with the maintainer
- **Issues are fixed in a git worktree inside the repo**, `.worktrees/<topic>` on branch `fix/<topic>`, with a git-ignored `issuedescription.md` there (problem, location as `path:line`, solution, compatibility, tests). The git-ignored `ISSUES.md` lists the open review items; it and `test/tmp/review/` exist only on the maintainer's machine.
- **Don't commit unless asked.** On "merge": commit on the branch, `git merge --ff-only` into `main`, run the full suite.
- **Compatibility:** other packages (e.g. MINDFulCompanion.jl, the maintainer's dissertation code) implement compilation algorithms on top of MINDFul. Don't change the signatures of the algorithm interface (`policiesinterfaces.jl`, the template hooks in `compilationtemplate.jl`), and keep the existing algorithm logic (loops, fallbacks); list behaviour changes of interface functions.
- Cite code as `path:line` (e.g. `src/IBNLayer/compilationtemplate.jl:1345`), never a bare "line N", also in follow-up sentences.
- The distributed/HTTP code (`server.jl`, `ibn_distributed.jl`, `HTTPMessages.jl`, RemoteHTTPHandler, RSA/TLS) is outside the current review scope; its tests are disabled.
- The `.jld2` network files in `test/data` are kept for `config*.toml`, `src/main.jl` and `test/LiveTest`; the tests use the TOML versions. The networks are produced outside this repo (NetworkProduction).
