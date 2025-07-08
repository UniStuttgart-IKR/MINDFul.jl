module Server
using Oxygen, HTTP, SwaggerMarkdown, JSON, UUIDs, Dates
using MINDFul
using MINDFul: @recvtime, @passtime
const MINDF = MINDFul
using Serialization


module OxygenInstance using Oxygen; @oxidise end

import .OxygenInstance: @get, @put, @post, @delete, mergeschema, serve, router

export serve

    api = OxygenInstance.router("/api", tags=["api endpoint"])

    function getmyibnf(req, context)
      if context isa MINDF.IBNFramework
          #println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
          return ibnf
      elseif context isa Vector{MINDF.IBNFramework}
          println("context is of type Vector{MINDF.IBNFramework}")
          ibnfs :: Vector{MINDF.IBNFramework} = context
          host = Dict(req.headers)[MINDF.HTTPMessages.KEY_HOST]
          for ibnftemp in ibnfs
            if MINDF.getbaseurl(MINDF.getibnfhandlers(ibnftemp)[1]) == "https://$host"
              ibnf = ibnftemp
            end
          end
          return ibnf
      elseif context isa Dict{Int, MINDF.IBNFramework}
          #println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfsdict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)[MINDF.HTTPMessages.KEY_HOST]
          uri = HTTP.URI("https://$host")
          port = parse(Int, uri.port)
          ibnf = ibnfsdict[port]
          return ibnf
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
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

        if recvtoken == last(MINDF.getibnfhandlertokengen(handler))
            if MINDF.getibnfhandlerperm(handler) == "none"
                return false
            elseif MINDF.getibnfhandlerperm(handler) == "full"
                return true
            elseif MINDF.getibnfhandlerperm(handler) == "limited"
                if uri in MINDF.HTTPMessages.LIST_LIMITEDFUNCTIONS
                    return true
                else
                  return false
                end
            end
        else
            return false
        end

        # if haskey(MINDF.HTTPMessages.generatedtokens, initiatoribnfid) 
        #     if MINDF.HTTPMessages.generatedtokens[initiatoribnfid] == token
        #       return true
        #     else
        #       return false
        #     end
        # else
        #     return true
        # end
    end


    @post MINDF.HTTPMessages.URI_HANDSHAKE function (req; context)
        ibnf = getmyibnf(req, context)
        myibnfid = string(MINDF.getibnfid(ibnf))
        parsedbody = JSON.parse(String(HTTP.payload(req)))
        remoteibnfid = parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID]
        token = parsedbody[MINDF.HTTPMessages.KEY_TOKEN]
        availablefunctions = parsedbody[MINDF.HTTPMessages.KEY_AVAILABLEFUNCTIONS]
        #println("\nAvailable functions in domain $remoteibnfid for domain $myibnfid: $availablefunctions \n")
        println("\nDomain $myibnfid has access to the following functions in domain $remoteibnfid: $availablefunctions \n")
        remotehandler = MINDF.getibnfhandler(ibnf, UUID(remoteibnfid))
        
        if !isnothing(token)
            push!(MINDF.getibnfhandlertokenrecv(remotehandler), token)
            myibnfid = string(MINDF.getibnfid(ibnf))
            gentoken, availablefunctions = MINDF.handshake_term(myibnfid, remotehandler)
            return HTTP.Response(200, JSON.json(Dict(MINDF.HTTPMessages.KEY_TOKEN => gentoken,MINDF.HTTPMessages.KEY_AVAILABLEFUNCTIONS => availablefunctions)))
        else
            return HTTP.Response(403, "Token not received")
        end        
    end

    
    @swagger """
    /api/compilationalgorithms: 
      post:
        description: Return the available compilation algorithms
        responses:
          "200":
            description: Successfully returned the compilation algorithms.
    """
    @post api("/compilationalgorithms") function (req; context)
        ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_COMPILATIONALGORITHMS) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
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
    """    
    @post MINDF.HTTPMessages.URI_SPECTRUMAVAILABILITY function (req; context)
        ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_SPECTRUMAVAILABILITY) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
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


    @post MINDF.HTTPMessages.URI_CURRENTLINKSTATE function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_CURRENTLINKSTATE) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
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


    @post MINDF.HTTPMessages.URI_COMPILEINTENT function (req; context)
      #return HTTP.Response(403, "Not possible to compile the intent")
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_COMPILEINTENT) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      compilationalgorithmkey = Symbol(parsedbody[MINDF.HTTPMessages.KEY_COMPILATIONKEY])
      compilationalgorithmargs = Tuple(parsedbody[MINDF.HTTPMessages.KEY_COMPILATIONARGS])
      compileintent = MINDF.requestcompileintent_term!(remoteibnfhandler, ibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs; offsettime=otime)
      if !isnothing(compileintent)
        return HTTP.Response(200, JSON.json(string(compileintent)))
      else
        return HTTP.Response(404, "Not possible to compile the intent")
      end
      
    end


    @post MINDF.HTTPMessages.URI_DELEGATEINTENT function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_DELEGATEINTENT) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
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
      delegateintent = MINDF.requestdelegateintent_term!(remoteibnfhandler, ibnf, receivedintent, internalidagnodeid; offsettime=otime)
      if !isnothing(delegateintent)
        return HTTP.Response(200, JSON.json(delegateintent))
      else
          return HTTP.Response(404, "Delegation not worked")
      end
    end


    @post MINDF.HTTPMessages.URI_REMOTEINTENTSTATEUPDATE function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REMOTEINTENTSTATEUPDATE) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      newstate = Symbol(parsedbody[MINDF.HTTPMessages.KEY_NEWSTATE])
      state = getfield(MINDF.IntentState, newstate)
      updatedstate = MINDF.requestremoteintentstateupdate_term!(remoteibnfhandler, ibnf, idagnodeid, state; offsettime=otime)
      if !isnothing(updatedstate)
        return HTTP.Response(200, JSON.json(updatedstate))
      else
        return HTTP.Response(404, "Not possible to update the intent state")
      end
      
    end


    @post MINDF.HTTPMessages.URI_ISSATISFIED function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_ISSATISFIED) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
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


    @post MINDF.HTTPMessages.URI_INSTALLINTENT function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_INSTALLINTENT) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      installintent = MINDF.requestinstallintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose, offsettime=otime)
      if !isnothing(installintent)
        return HTTP.Response(200, JSON.json(installintent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post MINDF.HTTPMessages.URI_UNINSTALLINTENT function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_UNINSTALLINTENT) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      uninstallintent = MINDF.requestuninstallintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose, offsettime=otime)
      if !isnothing(uninstallintent)
        return HTTP.Response(200, JSON.json(uninstallintent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post MINDF.HTTPMessages.URI_UNCOMPILEINTENT function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_UNCOMPILEINTENT) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      uncompileintent = MINDF.requestuncompileintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose, offsettime=otime)
      if !isnothing(uncompileintent)
        return HTTP.Response(200, JSON.json(uncompileintent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post MINDF.HTTPMessages.URI_SETLINKSTATE function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_SETLINKSTATE) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      gedata = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
      receivedge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_SRC][MINDF.HTTPMessages.KEY_LOCALNODE]),
          MINDF.GlobalNode(UUID(gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_IBNFID]), gedata[MINDF.HTTPMessages.KEY_DST][MINDF.HTTPMessages.KEY_LOCALNODE])
      )
      operatingstate = parsedbody[MINDF.HTTPMessages.KEY_OPERATINGSTATE]
      setlinkstate = MINDF.requestsetlinkstate_term!(remoteibnfhandler, ibnf, receivedge, operatingstate; offsettime=otime)
      if !isnothing(setlinkstate)
          return HTTP.Response(200, JSON.json(setlinkstate))
      else
          return HTTP.Response(404, "Set link state not possible")
      end
    end


    @post MINDF.HTTPMessages.URI_REQUESTLINKSTATES function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REQUESTLINKSTATES) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
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

    
    @post MINDF.HTTPMessages.URI_REQUESTIDAG function (req; context)
      ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
      if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REQUESTIDAG) == false
        return HTTP.Response(403, "Forbidden: Invalid token")
      end

      idag = MINDF.requestidag_term(remoteibnfhandler, ibnf)
      # @show typeof(idag)
      # @show propertynames(idag)
      # @show fieldnames(typeof(idag))
      # @show idag

      io = IOBuffer()
      serialize(io, idag)
      rawbytes = take!(io)
  
      if !isnothing(idag)
        return HTTP.Response(200, rawbytes)
      else
        return HTTP.Response(404, "Not possible to request the idag")
      end
    end


    @post MINDF.HTTPMessages.URI_IBNAGRAPH function (req; context)
        ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_IBNAGRAPH) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
        end
        
        ibnattributegraph = MINDF.requestibnattributegraph_term!(remoteibnfhandler, ibnf)
        #@show typeof(ibnattributegraph)

        io = IOBuffer()
        serialize(io, ibnattributegraph)
        rawbytes = take!(io)
        
        if !isnothing(ibnattributegraph)
            return HTTP.Response(200, rawbytes)
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end


    @post MINDF.HTTPMessages.URI_REQUESTHANDLERS function (req; context)
       ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
       if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_REQUESTHANDLERS) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
       end  
        
        ibnfhandlers = MINDF.requestibnfhandlers_term(remoteibnfhandler, ibnf)      
        if !isnothing(ibnfhandlers)
            return HTTP.Response(200, JSON.json(ibnfhandlers))

        else
            return HTTP.Response(404, "Handlers not found")
        end
    end

    
    @post MINDF.HTTPMessages.URI_LOGICALORDER function (req; context)
        ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_LOGICALORDER) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
        end
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        logicalorder = MINDF.requestlogicallliorder_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled, verbose)
      
        if !isnothing(logicalorder)
            jsonready = [MINDF.serializelowlevelintent(ll) for ll in logicalorder]
            return HTTP.Response(200, JSON.json(jsonready))

        else
            return HTTP.Response(404, "Handlers not found")
        end
    end


    @post MINDF.HTTPMessages.URI_INTENTGLOBALPATH function (req; context)
        ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_INTENTGLOBALPATH) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
        end
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        intentglobalpath = MINDF.requestintentglobalpath_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
        if !isnothing(intentglobalpath)
            jsonready = [MINDF.serializeglobalnode(igp) for igp in intentglobalpath]
            return HTTP.Response(200, JSON.json(jsonready))
        else
            return HTTP.Response(404, "Handlers not found")
        end
    end


    @post MINDF.HTTPMessages.URI_ELECTRICALPRESENCE function (req; context)
       ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_ELECTRICALPRESENCE) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
        end
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        electricalpresence = MINDF.requestglobalnodeelectricalpresence_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
        if !isnothing(electricalpresence)
            jsonready = [MINDF.serializeglobalnode(igp) for igp in electricalpresence]
            return HTTP.Response(200, JSON.json(jsonready))
        else
            return HTTP.Response(404, "Handlers not found")
        end
    end


    @post MINDF.HTTPMessages.URI_LIGHTPATHS function (req; context)
        ibnf, parsedbody, remoteibnfhandler, verbose, otime = extractgeneraldata(req, context)
        if checktoken(ibnf, parsedbody, MINDF.HTTPMessages.URI_LIGHTPATHS) == false
            return HTTP.Response(403, "Forbidden: Invalid token")
        end
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        lightpaths = MINDF.requestintentgloballightpaths_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
        if !isnothing(lightpaths)
            jsonready = [[MINDF.serializeglobalnode(gn) for gn in path] for path in lightpaths]
            return HTTP.Response(200, JSON.json(jsonready))
        else
            return HTTP.Response(404, "Handlers not found")
        end
    end

    
    # TODO ma1069
    info = Dict("title" => "MINDFul Api", "version" => "1.0.0")
    openApi = OpenAPI("3.0", info)
    swaggerdocument = build(openApi)
    #open("swagger.json", "w") do file
    #    JSON.print(file, swagger_document)
    #end
    #println("Swagger documentation saved to swagger.json")
    # merge the SwaggerMarkdown schema with the internal schema
    OxygenInstance.mergeschema(swaggerdocument) 
     

end