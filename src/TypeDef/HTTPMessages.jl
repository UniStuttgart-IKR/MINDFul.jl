"""
    The HTTP codes and data defined for the different requests.
    All the `const` variables have a `String` value that represents the endpoint of the URL or the data that is passed respectively.
 """
module HTTPMessages

#export IBNAGRAPH, SPECTRUM_AVAILABILITY, COMPILATION_ALGORITHMS

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

const SET_LINKSTATE = "/api/set_linkstate"

const REQ_LINKSTATES = "/api/request_linkstates"

const IDAG = "/api/request_idag"

const REQUEST_HANDLERS = "/api/request_handlers"

const LOGICAL_ORDER = "/api/logical_order"


const INITIATOR_IBNFID = "initiator_ibnfid"

const GLOBAL_EDGE = "global_edge"

const NEWSTATE = "newstate"

const OPERATINGSTATE = "operatingstate"

const IDAGNODEID = "idagnodeid"

const INTERNAL_IDAGNODEID = "internalidagnodeid"

const INTENT = "intent"

const INTENTUUID = "intentuuid"

const COMPILATION_KEY = "compilationalgorithmkey"

const COMPILATION_ARGS = "compilationalgorithmargs"

const ONLY_INSTALLED = "onlyinstalled"

const NOEXTRALLIS = "noextrallis"

const VERBOSE = "verbose"

const LINK_DATETIME = "linkdatetime"

const LINK_STATE = "linkstate"



end
