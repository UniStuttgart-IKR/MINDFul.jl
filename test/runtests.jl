include("initialize.jl")
include("testsuite/utils.jl")
include("testsuite/physicaltest.jl")
include("testsuite/basicintenttest.jl")
include("testsuite/opticalconstraintssingledomain.jl")
include("testsuite/multidomain.jl")
include("testsuite/multidomain_bestempiricalavailability.jl")
include("testsuite/failingintime.jl")
include("testsuite/grooming.jl")
include("testsuite/groomingonfail.jl")
include("testsuite/interface.jl")
include("testsuite/permissions.jl")
include("testsuite/rsaauthentication.jl")

include("testsuite/singledomainavailabilityprotection.jl")
include("testsuite/singledomainavailabilityprotection_grooming.jl")

include("testsuite/logintraintertest.jl")

include("testsuite/multidomainavailabilityprotection_grooming.jl")

nothing
