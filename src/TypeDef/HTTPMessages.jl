"""
    The HTTP codes and data defined for the different requests.
    All the `const` variables have a `String` value that represents the endpoint of the URL or the data that is passed respectively.
    With full permission, the domains can access all the functions of the remote IBN framework.
    With limited permission, the domains can only access the defined limited set of functions.
 """
module HTTPMessages

const URI_IBNAGRAPH = "/api/ibnattributegraph"

const URI_SPECTRUMAVAILABILITY = "/api/spectrumavailability"

const URI_COMPILATIONALGORITHMS = "/api/compilationalgorithms"

const URI_COMPILEINTENT = "/api/compileintent"

const URI_CURRENTLINKSTATE = "/api/currentlinkstate"

const URI_DELEGATEINTENT = "/api/delegateintent"

const URI_REMOTEINTENTSTATEUPDATE = "/api/remoteintentstateupdate"

const URI_ISSATISFIED = "/api/requestissatisfied"

const URI_INSTALLINTENT = "/api/installintent"

const URI_UNINSTALLINTENT = "/api/uninstallintent"

const URI_UNCOMPILEINTENT = "/api/uncompileintent"

const URI_SETLINKSTATE = "/api/setlinkstate"

const URI_REQUESTLINKSTATES = "/api/requestlinkstates"

const URI_REQUESTIDAG = "/api/requestidag"

const URI_REQUESTHANDLERS = "/api/requesthandlers"

const URI_LOGICALORDER = "/api/logicalorder"

const URI_LIGHTPATHS = "/api/lightpaths"

const URI_INTENTGLOBALPATH = "/api/intentglobalpath"

const URI_ELECTRICALPRESENCE = "/api/electricalpresence"

const URI_HANDSHAKE = "/api/handshake"

const URI_DIFFIEHELLMAN = "/api/diffiehellman"

const URI_RSAAUTHENTICATION = "/api/rsaauthentication"


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

const KEY_IBNFID = "ibnfid"

const KEY_VALUE = "value"

const KEY_BASEURL = "baseurl"

const KEY_LOCALNODE = "localnode"

const KEY_OFFSETTIME = "offsettime"

const KEY_NOTHING = "nothing"

const KEY_SRC = "src"

const KEY_DST = "dst"

const KEY_RATE = "rate"

const KEY_CONSTRAINTS = "constraints"

const KEY_TYPE = "type"

const KEY_GNI = "globalnode_input"

const KEY_SSR = "spectrumslotsrange"

const KEY_OPTICALREACH = "opticalreach"

const KEY_TMC = "transmissionmodulecompat"

const KEY_SSN = "spectrumslotsneeded"

const KEY_NAME = "name"

const KEY_NODE = "node"

const KEY_INPUT = "input"

const KEY_ADDDROPPORT = "adddropport"

const KEY_OUTPUT = "output"

const KEY_SLOTSTART = "slotstart"

const KEY_SLOTEND = "slotend"

const KEY_POOLINDEX = "poolindex"

const KEY_MODESINDEX = "modesindex"

const KEY_PORT = "port"

const KEY_HOST = "Host"

const KEY_OPTICALINITIATECONSTRAINT = "OpticalInitiateConstraint"

const KEY_OPTICALTERMINATECONSTRAINT = "OpticalTerminateConstraint"

const KEY_ADBYPASSSPECTRUM = "OXCAddDropBypassSpectrumLLI"

const KEY_TRANSMISSIONMODULE = "TransmissionModuleLLI"

const KEY_ROUTERPORT = "RouterPortLLI"

const KEY_TOKEN = "token"

const KEY_AVAILABLEFUNCTIONS = "availablefunctions"

const KEY_PERMISSION = "permission"

const KEY_GENTOKEN = "gentoken"

const KEY_RECVTOKEN = "recvtoken"

const KEY_PUBLICNUMBER = "publicnumber"

const KEY_DHSECRET = "dhsecret"

const KEY_RSASECRET = "rsasecret"

const KEY_RSAKEY = "rsakey"

const KEY_FULLPERMISSION = "full"

const KEY_LIMITEDPERMISSION = "limited"

const KEY_TYPEOFPUBLICKEY = "PUBLIC KEY"

const KEY_TYPEOFPRIVATEKEY = "PRIVATE KEY"

const LIST_ALLFUNCTIONS = [
    URI_IBNAGRAPH,
    URI_SPECTRUMAVAILABILITY,
    URI_COMPILATIONALGORITHMS,
    URI_COMPILEINTENT,
    URI_CURRENTLINKSTATE,
    URI_DELEGATEINTENT,
    URI_REMOTEINTENTSTATEUPDATE,
    URI_ISSATISFIED,
    URI_INSTALLINTENT,
    URI_UNINSTALLINTENT,
    URI_UNCOMPILEINTENT,
    URI_SETLINKSTATE,
    URI_REQUESTLINKSTATES,
    URI_REQUESTIDAG,
    URI_REQUESTHANDLERS,
    URI_LOGICALORDER,
    URI_LIGHTPATHS,
    URI_INTENTGLOBALPATH,
    URI_ELECTRICALPRESENCE
]


const LIST_LIMITEDFUNCTIONS = [
    URI_IBNAGRAPH,
    URI_SPECTRUMAVAILABILITY,
    URI_COMPILATIONALGORITHMS,
    URI_CURRENTLINKSTATE,
    URI_REMOTEINTENTSTATEUPDATE,
    URI_ISSATISFIED,
    URI_SETLINKSTATE,
    URI_REQUESTLINKSTATES,
    URI_REQUESTIDAG,
    URI_REQUESTHANDLERS,
    URI_LOGICALORDER,
    URI_LIGHTPATHS,
    URI_INTENTGLOBALPATH,
    URI_ELECTRICALPRESENCE
]

end
