# Notes for developes and contributors

## Mental classification of functions per functionality
(must clarify these notes)
To expand upon:
allocate - deallocate
reserve - unreserve
function getters
get... -> get field
new... -> construct something new
prioritize -> return a vector of indices
choose -> return a specific (scalar) index
comp -> compilation


## How to read variables
transmission -> trans\
module -> mdl\
mode -> mode\
index -> idx\
uuid -> id\
ibn framework -> ibnf\

## Create a new availability-aware IP-Optical Algorithm
Look at `src/IBNLayer/ibn_bestempiricalavailabilitymatch.jl` where the algorithm `BestEmpiricalAvailabilityCompilation` is defined.
More specifically, assume your new algorithm is a struct `MyNewAlgorithm`.
We suggest you make it a subtype of `<: IntentCompilationAlgorithmWithMemory` and contain the following fields in your struct:
```julia
    "How many k paths to check"
    candidatepathsnum::Int
    """
    How many m paths to consider for joint protection.
    It investigates all possible pair of the first m paths
    """
    pathsforprotectionnum::Int
    "cached information"
    cachedresults::CachedResults
    "The algorithm memory that is updated"
    basicalgmem::BasicAlgorithmMemory
```

1. Define a `const IBNFrameworkMNA = IBNFramework{A,B,C,D,MyNewAlgorithm} where {A,B,C,D}` to use it later

2. Define 3 cosntructors
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

3. Define a `compileintent!` for your new type `@recvtime function compileintent!(ibnf::IBNFrameworkMNA, idagnode::IntentDAGNode{<:ConnectivityIntent}; verbose::Bool = false)`
Inside your function you can use [`MINDFul.intradomaincompilationtemplate`](@ref) and [`MINDFul.compileintenttemplate!](@ref) for easier development.
Read the docs of the two functions for a better understanding. Now that's all.
For multi-domain availability research the most important configurations you might want to add are `prioritizepaths` from `intradomaincompilationtemplate` and `prioritizesplitbordernodes` from `compileintenttemplate!`.
The first one determines the internal domain paths and the second the split border nodes between the domains.

## Further APIs

## Testing

Usefull testing functions are in the `TestModule` weak dependency.
To access them you first need to load `Test` and `JET` and then use `Base.get_extention`.
```julia
# get the test module from MINDFul
import Test, JET
TestModule = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TM)
```
Now, with dot notation (`TestModule.`) you can access all the following functions. 

### Testing API

```@autodocs
Modules = [Base.get_extension(MINDFul, :TestModule)]
```
