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

include("testsuite/installingstate.jl")
# include("testsuite/increasingtimestamps.jl")

include("testsuite/singledomainavailabilityprotection.jl")
include("testsuite/singledomainavailabilityprotection_grooming.jl")

include("testsuite/logintraintertest.jl")

# TODO make better
include("testsuite/updowntimes.jl")
include("testsuite/updowntimes_interdomain.jl")

include("testsuite/singledomainavailabilityprotection_grooming_split.jl")
include("testsuite/multidomainavailabilityprotection_grooming.jl")


nothing
