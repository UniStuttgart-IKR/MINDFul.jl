"""
    The HTTP codes and data defined for the different requests.
    All the `const` variables have a `String` value that represents the endpoint of the URL or the data that is passed respectively.
 """
module HTTPMessages

#export IBNAGRAPH, SPECTRUM_AVAILABILITY, COMPILATION_ALGORITHMS

const URI_IBNAGRAPH = "/api/ibnattributegraph"

const URI_SPECTRUMAVAILABILITY = "/api/spectrum_availability"

const URI_COMPILATIONALGORITHMS = "/api/compilation_algorithms"

const URI_COMPILEINTENT = "/api/compile_intent"

const URI_CURRENTLINKSTATE = "/api/current_linkstate"

const URI_DELEGATEINTENT = "/api/delegate_intent"

const URI_REMOTEINTENTSTATEUPDATE = "/api/remoteintent_stateupdate"

const URI_ISSATISFIED = "/api/requestissatisfied"

const URI_INSTALLINTENT = "/api/install_intent"

const URI_UNINSTALLINTENT = "/api/uninstall_intent"

const URI_UNCOMPILEINTENT = "/api/uncompile_intent"

const URI_SETLINKSTATE = "/api/set_linkstate"

const URI_REQLINKSTATES = "/api/request_linkstates"

const URI_REQUESTIDAG = "/api/request_idag"

const URI_REQUESTHANDLERS = "/api/request_handlers"

const URI_LOGICALORDER = "/api/logical_order"

const URI_LIGHTPATHS = "/api/lightpaths"

const URI_INTENTGLOBALPATH = "/api/intentglobalpath"

const URI_ELECTRICALPRESENCE = "/api/electricalpresence"


const KEY_INITIATORIBNFID = "initiator_ibnfid"

const KEY_GLOBALEDGE = "global_edge"

const KEY_NEWSTATE = "newstate"

const KEY_OPERATINGSTATE = "operatingstate"

const KEY_IDAGNODEID = "idagnodeid"

const KEY_INTERNALIDAGNODEID = "internalidagnodeid"

const KEY_INTENT = "intent"

const KEY_INTENTUUID = "intentuuid"

const KEY_COMPILATIONKEY = "compilationalgorithmkey"

const KEY_COMPILATIONARGS = "compilationalgorithmargs"

const KEY_ONLYINSTALLED = "onlyinstalled"

const KEY_NOEXTRALLIS = "noextrallis"

const KEY_VERBOSE = "verbose"

const KEY_LINKDATETIME = "linkdatetime"

const KEY_LINKSTATE = "linkstate"



end
