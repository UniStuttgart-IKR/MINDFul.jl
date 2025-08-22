module Server
using Oxygen, HTTP, SwaggerMarkdown, JSON, UUIDs, Dates
using MINDFul
using MINDFul: @recvtime, @passtime
const MINDF = MINDFul
using Serialization


module OxygenInstance
    using Oxygen; @oxidise
end

import .OxygenInstance: @get, @put, @post, @delete, mergeschema, serve, router

export serve

full = OxygenInstance.router("", tags = ["Full-permission required"])
limited = OxygenInstance.router("", tags = ["Limited-permission required"])
api = OxygenInstance.router("", tags = ["API handshake endpoints"])

function getmyibnf(req, context::Dict{Int, <:MINDF.IBNFramework})
    ibnfsdict::Dict{Int, <:MINDF.IBNFramework} = context
    host = Dict(req.headers)[MINDF.HTTPMessages.KEY_HOST]
    uri = HTTP.URI("https://$host")
    port = parse(Int, uri.port)
    ibnf = ibnfsdict[port]
    return ibnf
end

function extractgeneraldata(req, context)
    ibnf = getmyibnf(req, context)
    body = HTTP.payload(req)
    parsedbody = JSON.parse(String(body))
    initiatoribnfid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID])
    remoteibnfhandler = MINDF.getibnfhandler(ibnf, initiatoribnfid)

    if parsedbody[MINDF.HTTPMessages.KEY_OFFSETTIME] == MINDF.HTTPMessages.KEY_NOTHING
        otime = nothing
    else
        otime = DateTime(parsedbody[MINDF.HTTPMessages.KEY_OFFSETTIME])
    end

    hasverbose = haskey(parsedbody, MINDF.HTTPMessages.KEY_VERBOSE)
    if hasverbose
        verbose = parsedbody[MINDF.HTTPMessages.KEY_VERBOSE]
    else
        verbose = false
    end
    return (ibnf, parsedbody, remoteibnfhandler, verbose, otime)
end

function checktoken(ibnf, parsedbody, uri)
    initiatoribnfid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID])
    recvtoken = parsedbody[MINDF.HTTPMessages.KEY_TOKEN]
    handler = MINDF.getibnfhandler(ibnf, initiatoribnfid)

    if recvtoken == MINDF.getibnfhandlergentoken(handler)
        if MINDF.getibnfhandlerperm(handler) == MINDF.HTTPMessages.KEY_FULLPERMISSION
            return true
        elseif MINDF.getibnfhandlerperm(handler) == MINDF.HTTPMessages.KEY_LIMITEDPERMISSION
            if uri in MINDF.HTTPMessages.LIST_LIMITEDFUNCTIONS
                return true
            else
                return false
            end
        else
            return false
        end
    else
        return false
    end
end

@swagger """
/api/tokenhandshake:
  post:
    description: Token exchange with remote IBNF
    requestBody:
      description: The remote IBNF ID, token and available functions
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
              availablefunctions:
                type: array
                items:
                  type: string
    responses:
      "200":
        description: Successfully initiated token handshake.
      "403":
        description: Forbidden. Token not received.
"""
@post api(MINDF.HTTPMessages.URI_TOKENHANDSHAKE) function (req; context)
    ibnf = getmyibnf(req, context)

    parsedbody = JSON.parse(String(HTTP.payload(req)))
    remoteibnfid = parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID]
    remotehandler = MINDF.getibnfhandler(ibnf, UUID(remoteibnfid))
    encryptedsecret = parsedbody[MINDF.HTTPMessages.KEY_RSASECRET]
    decryptedsecret = MINDF.rsaauthentication_term(ibnf, encryptedsecret)
    secret = MINDF.getibnfhandlerrsasecret(remotehandler)
    if decryptedsecret != secret
        return HTTP.Response(403, "RSA authentication failed with: received secret does not match the expected secret")
    end
    MINDF.setibnfhandlerrsasecret!(remotehandler, "")

    token = parsedbody[MINDF.HTTPMessages.KEY_TOKEN]
    availablefunctions = parsedbody[MINDF.HTTPMessages.KEY_AVAILABLEFUNCTIONS]
    #println("\nDomain $myibnfid has access to the following functions in remote domain $remoteibnfid: $availablefunctions \n")
    remotehandler = MINDF.getibnfhandler(ibnf, UUID(remoteibnfid))

    if !isnothing(token)
        MINDF.setibnfhandlerrecvtoken!(remotehandler, token)
        generatedtoken, availablefunctions = MINDF.handshake_term(remotehandler)
        MINDF.setibnfhandlergentoken!(remotehandler, generatedtoken)
        return HTTP.Response(200, JSON.json(Dict(MINDF.HTTPMessages.KEY_TOKEN => generatedtoken, MINDF.HTTPMessages.KEY_AVAILABLEFUNCTIONS => availablefunctions)))
    else
        return HTTP.Response(403, "Token not received")
    end
end


@swagger """
/api/rsaauthentication:
  post:
    description: RSA authentication with remote IBNF
    requestBody:
      description: The remote IBNF ID and encrypted secret
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              rsasecret:
                type: string
    responses:
      "200":
        description: Retrieving RSA concatenated secret encrypted with the initiator's public key.
      "403":
        description: Forbidden. Secret not received.
"""
@post api(MINDF.HTTPMessages.URI_RSAAUTHENTICATION) function (req; context)
    ibnf = getmyibnf(req, context)

    parsedbody = JSON.parse(String(HTTP.payload(req)))
    remoteibnfid = parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID]
    encryptedsecret = parsedbody[MINDF.HTTPMessages.KEY_RSASECRET]

    remotehandler = MINDF.getibnfhandler(ibnf, UUID(remoteibnfid))

    if !isnothing(encryptedsecret)
        decryptedsecret = MINDF.rsaauthentication_term(ibnf, encryptedsecret)
        newsecret = String(rand(UInt8, 32))
        MINDF.setibnfhandlerrsasecret!(remotehandler, newsecret)
        concatenatedsecret = decryptedsecret * "||" * newsecret
        encryptedconcatenatedsecret = MINDF.rsaauthentication_encrypt(remotehandler, concatenatedsecret)
        return HTTP.Response(200, JSON.json(Dict(MINDF.HTTPMessages.KEY_RSASECRET => encryptedconcatenatedsecret)))
    else
        return HTTP.Response(403, "Secret not received")
    end
end


@swagger """
/api/compilationalgorithms: 
  post:
    description: Return the available compilation algorithms
    requestBody:
      description: .
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
    responses:
      "200":
        description: Successfully returned the compilation algorithms.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Compilation algorithms not found.
"""
@post limited(MINDF.HTTPMessages.URI_COMPILATIONALGORITHMS) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_COMPILATIONALGORITHMS) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    compilationalgorithms = MINDF.requestavailablecompilationalgorithms_term!(remoteibnfhandler, ibnf)
    if !isnothing(compilationalgorithms)
        return HTTP.Response(200, JSON.json(compilationalgorithms))
    else
        return HTTP.Response(404, "Compilation algorithms not found")
    end
end


@swagger """
/api/spectrumavailability:
  post:
    description: Return the spectrum availability
    requestBody:
      description: The global edge for which to check spectrum availability
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              src:
                type: object
                properties:
                  ibnfid:
                    type: string
                  localnode:
                    type: integer
              dst:
                type: object
                properties:
                  ibnfid:
                    type: string
                  localnode:
                    type: integer
    responses:
      "200":
        description: Successfully returned the spectrum availability.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Spectrum availability not found.
"""
@post limited(MINDF.HTTPMessages.URI_SPECTRUMAVAILABILITY) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_SPECTRUMAVAILABILITY) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    gedata = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
    receivedge = MINDF.GlobalEdge(
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_LOCALNODE]),
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_LOCALNODE])
    )
    spectrumavailability = MINDF.requestspectrumavailability_term!(remoteibnfhandler, ibnf, receivedge)
    if !isnothing(spectrumavailability)
        return HTTP.Response(200, JSON.json(spectrumavailability))
    else
        return HTTP.Response(404, "Spectrum availability not found")
    end
end

@swagger """
/api/currentlinkstate:
  post:
    description: Return the current link state
    requestBody:
      description: The global edge for which to check the current link state
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              src:
                type: object
                properties:
                  ibnfid:
                    type: string
                  localnode:
                    type: integer
              dst:
                type: object
                properties:
                  ibnfid:
                    type: string
                  localnode:
                    type: integer
    responses:
      "200":
        description: Successfully returned the current link state.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Currently link not available.
"""
@post limited(MINDF.HTTPMessages.URI_CURRENTLINKSTATE) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_CURRENTLINKSTATE) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    gedata = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
    receivedge = MINDF.GlobalEdge(
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_LOCALNODE]),
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_LOCALNODE])
    )
    currentlinkstate = MINDF.requestcurrentlinkstate_term(remoteibnfhandler, ibnf, receivedge)
    if !isnothing(currentlinkstate)
        return HTTP.Response(200, JSON.json(currentlinkstate))
    else
        return HTTP.Response(404, "Currently link not available")
    end
end

@swagger """
/api/compileintent:
  post:
    description: Compile an intent
    requestBody:
      description: The intent to compile
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              idagnodeid:
                type: string
              compilationalgorithmkey:
                type: string
              compilationalgorithmargs:
                type: array
                items:
                  type: object
    responses:
      "200":
        description: Successfully compiled the intent.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to compile the intent.
"""
@post full(MINDF.HTTPMessages.URI_COMPILEINTENT) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_COMPILEINTENT) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
    compilationalgorithmkey = Symbol(parsedbody[MINDF.HTTPMessages.KEY_COMPILATIONKEY])
    compilationalgorithmargs = Tuple(parsedbody[MINDF.HTTPMessages.KEY_COMPILATIONARGS])
    compileintent = MINDF.requestcompileintent_term!(remoteibnfhandler, ibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs; offsettime = otime)
    if !isnothing(compileintent)
        return HTTP.Response(200, JSON.json(string(compileintent)))
    else
        return HTTP.Response(404, "Not possible to compile the intent")
    end

end

@swagger """
/api/delegateintent:
  post:
    description: Delegate an intent to a remote IBNF
    requestBody:
      description: The intent to delegate
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              internalidagnodeid:
                type: string
              intent:
                type: object
                properties:
                  src:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
                  dst:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
                  rate:
                    type: string
                  constraints:
                    type: array
                    items:
                      type: object
    responses:
      "200":
        description: Successfully delegated the intent.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Delegation not worked.
"""
@post full(MINDF.HTTPMessages.URI_DELEGATEINTENT) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_DELEGATEINTENT) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    internalidagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTERNALIDAGNODEID])
    intentdata = parsedbody[MINDF.HTTPMessages.KEY_INTENT]
    rate = MINDF.GBPSf(parse(Float64, replace(intentdata[MINDF.HTTPMessages.KEY_RATE], " Gbps" => "")))
    receivedconstraints = [MINDF.reconvertconstraint(constraint) for constraint in intentdata[MINDF.HTTPMessages.KEY_CONSTRAINTS]]
    receivedintent = MINDF.ConnectivityIntent(
        MINDF.GlobalNode(UUID(intentdata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_IBNFID]), intentdata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_LOCALNODE]),
        MINDF.GlobalNode(UUID(intentdata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_IBNFID]), intentdata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_LOCALNODE]),
        rate,
        receivedconstraints
    )
    delegateintent = MINDF.requestdelegateintent_term!(remoteibnfhandler, ibnf, receivedintent, internalidagnodeid; offsettime = otime)
    if !isnothing(delegateintent)
        return HTTP.Response(200, JSON.json(delegateintent))
    else
        return HTTP.Response(404, "Delegation not worked")
    end
end

@swagger """
/api/remoteintentstateupdate:
  post:
    description: Update the state of a remote intent
    requestBody:
      description: The idganodeid and the new state
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              idagnodeid:
                type: string
              newstate:
                type: string
    responses:
      "200":
        description: Successfully updated the intent state.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to update the intent state.
"""
@post limited(MINDF.HTTPMessages.URI_REMOTEINTENTSTATEUPDATE) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REMOTEINTENTSTATEUPDATE) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
    newstate = Symbol(parsedbody[MINDF.HTTPMessages.KEY_NEWSTATE])
    state = getfield(MINDF.IntentState, newstate)
    updatedstate = MINDF.requestremoteintentstateupdate_term!(remoteibnfhandler, ibnf, idagnodeid, state; offsettime = otime)
    if !isnothing(updatedstate)
        return HTTP.Response(200, JSON.json(updatedstate))
    else
        return HTTP.Response(404, "Not possible to update the intent state")
    end

end

@swagger """
/api/issatisfied:
  post:
    description: Check if an intent is satisfied
    requestBody:
      description: The idagnodeid and flags for checking only installed intents and using all LLIs
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              idagnodeid:
                type: string
              onlyinstalled:
                type: boolean
              noextrallis:
                type: boolean
    responses:
      "200":
        description: Successfully checked if the intent is satisfied.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to check if the intent is satisfied.
"""
@post limited(MINDF.HTTPMessages.URI_ISSATISFIED) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_ISSATISFIED) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
    onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
    noextrallis = parsedbody[MINDF.HTTPMessages.KEY_NOEXTRALLIS]
    issatisfiedresult = MINDF.requestissatisfied_term!(remoteibnfhandler, ibnf, idagnodeid; onlyinstalled, noextrallis)
    if !isnothing(issatisfiedresult)
        return HTTP.Response(200, JSON.json(issatisfiedresult))
    else
        return HTTP.Response(404, "Not possible to check if the intent is satisfied")
    end
end

@swagger """
/api/installintent:
  post:
    description: Install an intent on a remote IBNF
    requestBody:
      description: The idagnodeid of the intent to install
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              idagnodeid:
                type: string
    responses:
      "200":
        description: Successfully installed the intent.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to install the intent.
"""
@post full(MINDF.HTTPMessages.URI_INSTALLINTENT) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_INSTALLINTENT) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
    installintent = MINDF.requestinstallintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose, offsettime = otime)
    if !isnothing(installintent)
        return HTTP.Response(200, JSON.json(installintent))
    else
        return HTTP.Response(404, "Not possible to install the intent")
    end
end

@swagger """
/api/uninstallintent:
  post:
    description: Uninstall an intent from a remote IBNF
    requestBody:
      description: The idagnodeid of the intent to uninstall
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              idagnodeid:
                type: string
    responses:
      "200":
        description: Successfully uninstalled the intent.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to uninstall the intent.
"""
@post full(MINDF.HTTPMessages.URI_UNINSTALLINTENT) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_UNINSTALLINTENT) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
    uninstallintent = MINDF.requestuninstallintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose, offsettime = otime)
    if !isnothing(uninstallintent)
        return HTTP.Response(200, JSON.json(uninstallintent))
    else
        return HTTP.Response(404, "Not possible to install the intent")
    end
end

@swagger """
/api/uncompileintent:
  post:
    description: Uncompile an intent from a remote IBNF
    requestBody:
      description: The idagnodeid of the intent to uncompile
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              idagnodeid:
                type: string
    responses:
      "200":
        description: Successfully uncompiled the intent.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to install the intent.
"""
@post full(MINDF.HTTPMessages.URI_UNCOMPILEINTENT) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_UNCOMPILEINTENT) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
    uncompileintent = MINDF.requestuncompileintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose, offsettime = otime)
    if !isnothing(uncompileintent)
        return HTTP.Response(200, JSON.json(uncompileintent))
    else
        return HTTP.Response(404, "Not possible to install the intent")
    end
end

@swagger """
/api/setlinkstate:
  post:
    description: Set the state of a link
    requestBody:
      description: The global edge and the operating state to set
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              globaledge:
                type: object
                properties:
                  src:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
                  dst:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
              operatingstate:
                type: string
    responses:
      "200":
        description: Successfully set the link state.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Set link state not possible.
"""
@post limited(MINDF.HTTPMessages.URI_SETLINKSTATE) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_SETLINKSTATE) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    gedata = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
    receivedge = MINDF.GlobalEdge(
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_LOCALNODE]),
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_LOCALNODE])
    )
    operatingstate = parsedbody[MINDF.HTTPMessages.KEY_OPERATINGSTATE]
    setlinkstate = MINDF.requestsetlinkstate_term!(remoteibnfhandler, ibnf, receivedge, operatingstate; offsettime = otime)
    if !isnothing(setlinkstate)
        return HTTP.Response(200, JSON.json(setlinkstate))
    else
        return HTTP.Response(404, "Set link state not possible")
    end
end

@swagger """
/api/requestlinkstates:
  post:
    description: Request the link states for a global edge
    requestBody:
      description: The global edge for which to request link states
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              globaledge:
                type: object
                properties:
                  src:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
                  dst:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
    responses:
      "200":
        description: Successfully returned the link states.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Set link state not possible.
"""
@post limited(MINDF.HTTPMessages.URI_REQUESTLINKSTATES) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REQUESTLINKSTATES) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    gedata = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
    receivedge = MINDF.GlobalEdge(
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_LOCALNODE]),
        MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_LOCALNODE])
    )
    requestlinkstates = MINDF.requestlinkstates_term(remoteibnfhandler, ibnf, receivedge)
    if !isnothing(requestlinkstates)
        jsonready = [Dict(MINDF.HTTPMessages.KEY_LINKDATETIME => string(dt), MINDF.HTTPMessages.KEY_LINKSTATE => s) for (dt, s) in requestlinkstates]
        return HTTP.Response(200, JSON.json(jsonready))
    else
        return HTTP.Response(404, "Set link state not possible")
    end
end

@swagger """
/api/requestidag:
  post:
    description: Request the IBNF's Intent Directed Acyclic Graph (IDAG)
    requestBody:
      description: .
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
    responses:
      "200":
        description: Successfully returned the IDAG.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the IDAG.
"""
@post limited(MINDF.HTTPMessages.URI_REQUESTIDAG) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REQUESTIDAG) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    idag = MINDF.requestidag_term(remoteibnfhandler, ibnf)

    io = IOBuffer()
    serialize(io, idag)
    rawbytes = take!(io)

    if !isnothing(idag)
        return HTTP.Response(200, rawbytes)
    else
        return HTTP.Response(404, "Not possible to request the idag")
    end
end

@swagger """
/api/ibnattributegraph:
  post:
    description: Request the IBNF's attribute graph
    requestBody:
      description: .
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
    responses:
      "200":
        description: Successfully returned the IBNF's attribute graph.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the IBNF's attribute graph.
"""
@post limited(MINDF.HTTPMessages.URI_IBNAGRAPH) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_IBNAGRAPH) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    ibnattributegraph = MINDF.requestibnattributegraph_term!(remoteibnfhandler, ibnf)

    io = IOBuffer()
    serialize(io, ibnattributegraph)
    rawbytes = take!(io)

    if !isnothing(ibnattributegraph)
        return HTTP.Response(200, rawbytes)
    else
        return HTTP.Response(404, "Spectrum availability not found")
    end
end

@swagger """
/api/requestibnfhandlers:
  post:
    description: Request the IBNF handlers
    requestBody:
      description: . 
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
    responses:
      "200":
        description: Successfully returned the IBNF handlers.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the IBNF handlers.
"""
@post limited(MINDF.HTTPMessages.URI_REQUESTHANDLERS) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REQUESTHANDLERS) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    ibnfhandlers = MINDF.requestibnfhandlers_term(remoteibnfhandler, ibnf)
    if !isnothing(ibnfhandlers)
        return HTTP.Response(200, JSON.json(ibnfhandlers))

    else
        return HTTP.Response(404, "Handlers not found")
    end
end

@swagger """
/api/logicallliorder:
  post:
    description: Request the logical LLI order
    requestBody:
      description: The intent UUID and flags for only installed intents
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
              intentuuid:
                type: string
              onlyinstalled:
                type: boolean
    responses:
      "200":
        description: Successfully returned the logical LLI order.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the logical LLI order.
"""
@post limited(MINDF.HTTPMessages.URI_LOGICALORDER) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_LOGICALORDER) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
    onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
    logicalorder = MINDF.requestlogicallliorder_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled, verbose)

    if !isnothing(logicalorder)
        jsonready = [MINDF.serializelowlevelintent(ll) for ll in logicalorder]
        return HTTP.Response(200, JSON.json(jsonready))

    else
        return HTTP.Response(404, "Not possible to request the logical LLI order")
    end
end

@swagger """
/api/intentglobalpath:
  post:
    description: Request the intent global path
    requestBody:
      description: The intent UUID and flags for only installed intents
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
              intentuuid:
                type: string
              onlyinstalled:
                type: boolean
    responses:
      "200":
        description: Successfully returned the intent global path.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the intent global path.
"""
@post limited(MINDF.HTTPMessages.URI_INTENTGLOBALPATH) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_INTENTGLOBALPATH) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
    onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
    intentglobalpath = MINDF.requestintentglobalpath_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
    if !isnothing(intentglobalpath)
        jsonready = [MINDF.serializeglobalnode(igp) for igp in intentglobalpath]
        return HTTP.Response(200, JSON.json(jsonready))
    else
        return HTTP.Response(404, "Not possible to request the intent global path")
    end
end

@swagger """
/api/electricalpresence:
  post:
    description: Return the electrical presence of global nodes
    requestBody:
      description: The intent UUID and flags for only installed intents
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid:
                type: string
              token:
                type: string
              intentuuid:
                type: string
              onlyinstalled:
                type: boolean
    responses:
      "200":
        description: Successfully returned the electrical presence.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the electrical presence.
"""
@post limited(MINDF.HTTPMessages.URI_ELECTRICALPRESENCE) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_ELECTRICALPRESENCE) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
    onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
    electricalpresence = MINDF.requestglobalnodeelectricalpresence_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
    if !isnothing(electricalpresence)
        jsonready = [MINDF.serializeglobalnode(igp) for igp in electricalpresence]
        return HTTP.Response(200, JSON.json(jsonready))
    else
        return HTTP.Response(404, "Not possible to request the electrical presence")
    end
end

@swagger """
/api/lightpaths:
  post:
    description: Return the lightpaths for a given intent UUID
    requestBody:
      description: The intent UUID and flags for only installed intents
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              initiatoribnfid: 
                type: string
              token:
                type: string
              intentuuid:
                type: string
              onlyinstalled:
                type: boolean
    responses:
      "200":
        description: Successfully returned the light paths.
      "403":
        description: Forbidden. Invalid token.
      "404":
        description: Not possible to request the light paths.
"""
@post limited(MINDF.HTTPMessages.URI_LIGHTPATHS) function (req; context)
    ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
    if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_LIGHTPATHS) == false
        return HTTP.Response(403, "Forbidden. Invalid token")
    end

    intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
    onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
    lightpaths = MINDF.requestintentgloballightpaths_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
    if !isnothing(lightpaths)
        jsonready = [[MINDF.serializeglobalnode(gn) for gn in path] for path in lightpaths]
        return HTTP.Response(200, JSON.json(jsonready))
    else
        return HTTP.Response(404, "Not possible to request the light paths")
    end
end


# TODO ma1069
# Generating and integrating OpenAPI (Swagger) documentation the HTTP API endpoints:
info = Dict("title" => "MINDFul.jl HTTP-API endpoints", "version" => "1.0.0")
openApi = OpenAPI("3.0", info)
swaggerdocument = build(openApi)

# Merging the SwaggerMarkdown schema with the internal schema
OxygenInstance.mergeschema(swaggerdocument)
end
