# Developer Guide

Welcome to the MINDFul.jl developer documentation. This section covers common conventions, how to extend MINDFul.jl algorithms, and how to run tests.

## Variable Naming Conventions

To keep the codebase consistent and readable, MINDFul.jl uses the following abbreviations for common variables:

| Abbreviation | Meaning |
| :--- | :--- |
| `trans` | transmission |
| `mdl` | module |
| `mode` | mode |
| `idx` | index |
| `id` | uuid |
| `ibnf` | IBN framework |

## Creating a new Availability-Aware IP-Optical Algorithm

MINDFul.jl is designed to be easily extensible. You can define your own intent compilation algorithms. As an example, look at `src/IBNLayer/ibn_bestempiricalavailabilitymatch.jl` where the algorithm `BestEmpiricalAvailabilityCompilation` is defined.

To create a new algorithm `MyNewAlgorithm`, we recommend making it a subtype of `<: IntentCompilationAlgorithmWithMemory` and including the following fields:

```julia
struct MyNewAlgorithm <: IntentCompilationAlgorithmWithMemory
    "How many k paths to check"
    candidatepathsnum::Int
    "How many m paths to consider for joint protection."
    pathsforprotectionnum::Int
    "Cached information"
    cachedresults::CachedResults
    "The algorithm memory that is updated"
    basicalgmem::BasicAlgorithmMemory
end
```

### 1. Define an IBNFramework alias

Define a constant for your new framework configuration:
```julia
const IBNFrameworkMNA = IBNFramework{A,B,C,D,MyNewAlgorithm} where {A,B,C,D}
```

### 2. Define Constructors

Provide convenient constructors to initialize your algorithm's memory and cache:

```julia
function MyNewAlgorithm(ibnag::IBNAttributeGraph, candidatepathsnum::Int, pathforprotectionnum::Int)
    cachedresults = CachedResults(ibnag, candidatepathsnum)
    return MyNewAlgorithm(candidatepathsnum, pathforprotectionnum, cachedresults, BasicAlgorithmMemory())
end

function MyNewAlgorithm(candidatepathnum::Int, pathsforprotectionnum::Int; nodenum)
    return MyNewAlgorithm(candidatepathnum, pathsforprotectionnum, CachedResults(nodenum), BasicAlgorithmMemory())
end

function MyNewAlgorithm(mna::MyNewAlgorithm, cachedresults::CachedResults)
    return MyNewAlgorithm(mna.candidatepathsnum, mna.pathsforprotectionnum, cachedresults, BasicAlgorithmMemory())
end
```

### 3. Define the Compilation Function

Define the `compileintent!` function for your new algorithm type. You can use the provided templates `intradomaincompilationtemplate` and `compileintenttemplate!` to jumpstart your development.

```julia
@recvtime function compileintent!(ibnf::IBNFrameworkMNA, idagnode::IntentDAGNode{<:ConnectivityIntent}; verbose::Bool = false)
    # Your compilation logic here using intradomaincompilationtemplate and compileintenttemplate!
end
```

For multi-domain availability research, the most important configurations to hook into are:
- `prioritizepaths` (from `intradomaincompilationtemplate`): Determines the internal domain paths.
- `prioritizesplitbordernodes` (from `compileintenttemplate!`): Determines the split border nodes between domains.

## Event-Based Simulations and Visualizations

MINDFul.jl provides a hackable interface designed to conduct event-based simulations under diverse scenarios. You can interact with the API to change intent states and monitor network resources over time. 

Additionally, the companion package `MINDFulMakie.jl` can be used to visualize your simulations, draw intent DAGs, or render a compiled connectivity intent across the network topology.

### Simulated time

Every time-aware function (marked with `@recvtime`) takes the keyword `offsettime`: the simulated time at which the call starts.
Inside the call, simulated time advances with the real elapsed time (`offsettime + (now() - entrytime)`, see `@logtime`), and nested calls receive it through `@passtime`.
Without `offsettime` the real clock (`now()`) is used.

User-facing functions return a `ReturnCodeTime` (`addintent!` returns a `ReturnUUIDTime`) whose `datetime` is the simulated time at which the call finished.
**Simulated time must only move forward**: pass the returned time (or a later one) as the `offsettime` of the next call, advance it explicitly to let time pass, and never reuse an `offsettime`.

```julia
nowtime = DateTime("2026-01-01")
intentuuid, nowtime = addintent!(ibnf, intent, NetworkOperator(); offsettime = nowtime)
returncode, nowtime = compileintent!(ibnf, intentuuid; offsettime = nowtime)
returncode, nowtime = installintent!(ibnf, intentuuid; offsettime = nowtime)
nowtime += Dates.Month(3)  # let time pass
returncode, nowtime = MINDF.setlinkstate!(ibnf, Edge(3, 14), false; offsettime = nowtime)
```

Reusing an `offsettime` makes two calls start at the same simulated time, so the second one can register its events a few milliseconds *before* the events of the first one.
MINDFul.jl checks every registered event (intent states, link states, accounted up/down times) and throws a `SimulatedTimeError` when time would move backwards.

## Testing

Useful testing functions are located in the `TestModule` weak dependency. To access them, first load `Test` and `JET`, and then use `Base.get_extension`.

```julia
import Test, JET
TestModule = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TestModule)
```

Now, you can access testing utilities with dot notation (`TestModule.`).
`using .TestModule` gives the testing utilities, the test networks and the MINDFul names used in the tests without the prefix.
This is how MINDFul's own tests start (`test/runtests.jl`):

```julia
using Test, TestSetExtensions, JET, MINDFul, Graphs, UUIDs, Unitful, UnitfulData, Dates, MbedTLS
const TM = Base.get_extension(MINDFul, :TestModule)
using .TM
TM.setcachedresults!(joinpath(@__DIR__, "cache", "cachedresults.bin"); reuse = !("--nosercache" in ARGS))
```

The test networks are text (TOML) files in `test/data` and are loaded with `loadmultidomaintestibnfs` (3 domains) and `loadsingledomaintestibnf` (1 domain).
Loading a network calculates the candidate paths of every domain, which is slow.
With `setcachedresults!`, they are calculated once and stored in a file that all later loads (also in later sessions) reuse;
the cache is keyed by the content of the network file, so a changed network is calculated anew.
MINDFul's tests keep it in the git-ignored `test/cache`; `--nosercache` calculates it anew, and `--nojet` skips the JET checks:

```
julia --project=test test/runtests.jl --nosercache --nojet
```

### Testing your own compilation algorithm

A compilation algorithm implemented in another package can run MINDFul's **core tests**, without running MINDFul's whole test suite.
The core tests check behaviour that every algorithm must have, independent of its choices (paths, spectrum, ports):
- the intent lifecycle (add, compile, install, uninstall, uncompile, remove) in a single domain and across domains,
- 100 random intents that must compile, install and be satisfied, with consistent resources and logs,
- a failed compilation leaves no trace (intent `Uncompiled`, nothing reserved or staged in any domain), also when retried,
- the state logs are in ascending time (for an `IntentCompilationAlgorithmWithMemory`).

The algorithm is written like [`KShorestPathFirstFitCompilation`](@ref MINDFul.KShorestPathFirstFitCompilation) and needs:
- the constructor `MyAlg(alg::MyAlg, cachedresults::CachedResults)`, which the test networks use to build the algorithm of each domain,
- `getcandidatepathsnum` (e.g. a `candidatepathsnum` field),
- `compileintent!` for `ConnectivityIntent`s. No `AvailabilityConstraint` is used.

In the `test/runtests.jl` of your package:
```julia
using Test, JET, MINDFul, MyAlgorithm
TestModule = Base.get_extension(MINDFul, :TestModule)
TestModule.testsuitecompilationalgorithm(MyAlgorithm.MyAlg(10; nodenum = 1))
```
This takes about one to two minutes, most of it compilation.
With `TestModule.setcachedresults!(file)` before it, the calculated paths are cached in `file` for the next runs.
The test networks shipped with MINDFul can be loaded with `TestModule.loadsingledomaintestibnf` and `TestModule.loadmultidomaintestibnfs` for your own tests.

The other test suites of MINDFul are not part of the core tests: they check MINDFul internals (e.g. the physical layer) or
the specific choices of MINDFul's algorithms (exact paths, spectrum slots or grooming decisions), which another algorithm may legitimately make differently.
MINDFul runs the core tests on its own algorithms and on an example external algorithm (`test/testsuite/conformance.jl`).

### Testing API

```@autodocs
Modules = [Base.get_extension(MINDFul, :TestModule)]
```
