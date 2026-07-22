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

## Testing

Useful testing functions are located in the `TestModule` weak dependency. To access them, first load `Test` and `JET`, and then use `Base.get_extension`.

```julia
import Test, JET
TestModule = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TestModule)
```

Now, you can access testing utilities with dot notation (`TestModule.`).

### Testing API

```@autodocs
Modules = [Base.get_extension(MINDFul, :TestModule)]
```
