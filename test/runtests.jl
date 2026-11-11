# The test prelude: the TestModule extension of MINDFul provides the testing utilities, the test networks and the MINDFul names
using Test, TestSetExtensions, JET, MINDFul, Graphs, UUIDs, Unitful, UnitfulData, Dates, MbedTLS
const TM = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TM)
using .TM

# Arguments: `--nojet` skips the JET checks, `--nosercache` calculates the cached paths anew
# The calculated paths of the test networks are cached (git-ignored) and reused by all tests and runs
TM.setcachedresults!(joinpath(@__DIR__, "cache", "cachedresults.bin"); reuse = !("--nosercache" in ARGS))

include("testsuite/utils.jl")
include("testsuite/physicaltest.jl")
include("testsuite/conformance.jl")
include("testsuite/opticalconstraintssingledomain.jl")
include("testsuite/failingintime.jl")
include("testsuite/grooming.jl")
include("testsuite/groomingonfail.jl")
include("testsuite/permissions.jl")
include("testsuite/rsaauthentication.jl")

include("testsuite/pingintent.jl")

include("testsuite/installingstate.jl")
include("testsuite/increasingtimestamps.jl")

include("testsuite/singledomainavailabilityprotection.jl")
# include("testsuite/singledomainavailabilityprotection_grooming.jl")

include("testsuite/logintraintertest.jl")

# TODO make better
include("testsuite/updowntimes.jl")
include("testsuite/updowntimes_interdomain.jl")
include("testsuite/simulatedtime.jl")
include("testsuite/consecutive_link_failure.jl")
include("testsuite/groomed_install_on_failure.jl")
include("testsuite/failed_crossdomain_compile.jl")
include("testsuite/splitavailability.jl")

include("testsuite/singledomainavailabilityprotection_grooming_split.jl")
# include("testsuite/multidomainavailabilityprotection_grooming.jl")


nothing
