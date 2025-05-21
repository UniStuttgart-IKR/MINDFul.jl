"""
    The HTTP codes defined for the different requests.
    All the `const` variables have a `String` value that represents the endpoint of the URL.
 """
module HTTPCodes

export IBNAGRAPH, SPECTRUM_AVAILABILITY, COMPILATION_ALGORITHMS


const IBNAGRAPH = "/api/ibnattributegraph"


const SPECTRUM_AVAILABILITY = "/api/spectrum_availability"


const COMPILATION_ALGORITHMS = "/api/compilation_algorithms"

const COMPILE_INTENT = "/api/compile_intent"

const CURRENT_LINKSTATE = "/api/current_linkstate"

const DELEGATE_INTENT = "/api/delegate_intent"

const REMOTEINTENT_STATEUPDATE = "/api/remoteintent_stateupdate"

const IS_SATISFIED = "/api/requestissatisfied"

const INSTALL_INTENT = "/api/install_intent"

const UNINSTALL_INTENT = "/api/uninstall_intent"

const UNCOMPILE_INTENT = "/api/uncompile_intent"

end
