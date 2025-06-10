module Server
using Oxygen, HTTP, SwaggerMarkdown, JSON, UUIDs
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
          println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
          return ibnf
      elseif context isa Vector{MINDF.IBNFramework}
          println("context is of type Vector{MINDF.IBNFramework}")
          ibnfs :: Vector{MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          for ibnf_temp in ibnfs
            if ibnf_temp.ibnfhandlers[1].baseurl == "http://$host"
              ibnf = ibnf_temp
            end
          end
          return ibnf
      elseif context isa Dict{Int, MINDF.IBNFramework}
          #println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          uri = HTTP.URI("http://$host")
          port = parse(Int, uri.port)
          ibnf = ibnfs_dict[port]
          return ibnf
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
    end

    function extractgeneraldata(req, context)
        ibnf = getmyibnf(req, context)
        body = HTTP.payload(req)
        parsedbody = JSON.parse(String(body))
        initiator_ibnfid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID])
        remoteibnfhandler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
        return (ibnf, parsedbody, remoteibnfhandler)
    end

    
    @swagger """
    /api/compilation_algorithms: 
      post:
        description: Return the available compilation algorithms
        responses:
          "200":
            description: Successfully returned the compilation algorithms.
    """
    @post api("/compilation_algorithms") function (req; context)
        ibnf = getmyibnf(req, context)
        initiator_ibnfid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID])
        remoteibnfhandler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

        compilation_algorithms = MINDF.requestavailablecompilationalgorithms_term!(remoteibnfhandler, ibnf)
        if !isnothing(compilation_algorithms)
            return HTTP.Response(200, JSON.json(compilation_algorithms))
        else
            return HTTP.Response(404, "Compilation algorithms not found")
        end
    end


    @swagger """
    /api/spectrum_availability:
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
    @post "/api/spectrum_availability" function (req; context)
        ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

        ge_data = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
        received_ge = MINDF.GlobalEdge(
            MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
            MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
        )
        spectrum_availability = MINDF.requestspectrumavailability_term!(remoteibnfhandler, ibnf, received_ge)
        if !isnothing(spectrum_availability)
            return HTTP.Response(200, JSON.json(spectrum_availability))
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end


    @post "/api/current_linkstate" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      ge_data = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      current_linkstate = MINDF.requestcurrentlinkstate_term(remoteibnfhandler, ibnf, received_ge)
      if !isnothing(current_linkstate)
          return HTTP.Response(200, JSON.json(current_linkstate))
      else
          return HTTP.Response(404, "Currently link not available")
      end
    end


    @post "/api/compile_intent" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      compilationalgorithmkey = Symbol(parsedbody[MINDF.HTTPMessages.KEY_COMPILATIONKEY])
      compilationalgorithmargs = Tuple(parsedbody[MINDF.HTTPMessages.KEY_COMPILATIONARGS])
      compile_intent = MINDF.requestcompileintent_term!(remoteibnfhandler, ibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs)
      if !isnothing(compile_intent)
        return HTTP.Response(200, JSON.json(string(compile_intent)))
      else
        return HTTP.Response(404, "Not possible to compile the intent")
      end
      
    end


    @post "api/delegate_intent" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
      
      internalidagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTERNALIDAGNODEID])
      intent_data = parsedbody[MINDF.HTTPMessages.KEY_INTENT]
      rate = MINDF.GBPSf(parse(Float64, replace(intent_data["rate"], " Gbps" => "")))
      received_constraints = [MINDF.reconvert_constraint(constraint) for constraint in intent_data["constraints"]] 
      received_intent = MINDF.ConnectivityIntent(
          MINDF.GlobalNode(UUID(intent_data["src"]["ibnfid"]), intent_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(intent_data["dst"]["ibnfid"]), intent_data["dst"]["localnode"]),
          rate,
          received_constraints
      )
      delegate_intent = MINDF.requestdelegateintent_term!(remoteibnfhandler, ibnf, received_intent, internalidagnodeid)
      if !isnothing(delegate_intent)
        return HTTP.Response(200, JSON.json(delegate_intent))
      else
          return HTTP.Response(404, "Delegation not worked")
      end
    end


    @post "api/remoteintent_stateupdate" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      newstate = Symbol(parsedbody[MINDF.HTTPMessages.KEY_NEWSTATE])
      state = getfield(MINDF.IntentState, newstate)
      updated_state = MINDF.requestremoteintentstateupdate_term!(remoteibnfhandler, ibnf, idagnodeid, state)
      if !isnothing(updated_state)
        return HTTP.Response(200, JSON.json(updated_state))
      else
        return HTTP.Response(404, "Not possible to update the intent state")
      end
      
    end


    @post "api/requestissatisfied" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
      noextrallis = parsedbody[MINDF.HTTPMessages.KEY_NOEXTRALLIS]
      issatisfied_result = MINDF.requestissatisfied_term!(remoteibnfhandler, ibnf, idagnodeid; onlyinstalled, noextrallis)
      if !isnothing(issatisfied_result)
        return HTTP.Response(200, JSON.json(issatisfied_result))
      else
        return HTTP.Response(404, "Not possible to check if the intent is satisfied")
      end
    end


    @post "/api/install_intent" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      verbose = parsedbody[MINDF.HTTPMessages.KEY_VERBOSE]
      install_intent = MINDF.requestinstallintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose)
      if !isnothing(install_intent)
        return HTTP.Response(200, JSON.json(install_intent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post "/api/uninstall_intent" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      verbose = parsedbody[MINDF.HTTPMessages.KEY_VERBOSE]
      uninstall_intent = MINDF.requestuninstallintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose)
      if !isnothing(uninstall_intent)
        return HTTP.Response(200, JSON.json(uninstall_intent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post "/api/uncompile_intent" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idagnodeid = UUID(parsedbody[MINDF.HTTPMessages.KEY_IDAGNODEID])
      verbose = parsedbody[MINDF.HTTPMessages.KEY_VERBOSE]
      uncompile_intent = MINDF.requestuncompileintent_term!(remoteibnfhandler, ibnf, idagnodeid; verbose)
      if !isnothing(uncompile_intent)
        return HTTP.Response(200, JSON.json(uncompile_intent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post "/api/set_linkstate" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      ge_data = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      operatingstate = parsedbody[MINDF.HTTPMessages.KEY_OPERATINGSTATE]
      set_linkstate = MINDF.requestsetlinkstate_term!(remoteibnfhandler, ibnf, received_ge, operatingstate)
      if !isnothing(set_linkstate)
          return HTTP.Response(200, JSON.json(set_linkstate))
      else
          return HTTP.Response(404, "Set link state not possible")
      end
    end


    @post "/api/request_linkstates" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
      
      ge_data = parsedbody[MINDF.HTTPMessages.KEY_GLOBALEDGE]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      request_linkstates = MINDF.requestlinkstates_term(remoteibnfhandler, ibnf, received_ge)
      if !isnothing(request_linkstates)
          json_ready = [Dict(MINDF.HTTPMessages.KEY_LINKDATETIME => string(dt), MINDF.HTTPMessages.KEY_LINKSTATE => s) for (dt, s) in request_linkstates]
          return HTTP.Response(200, JSON.json(json_ready))
      else
          return HTTP.Response(404, "Set link state not possible")
      end
    end

    
    @post "/api/request_idag" function (req; context)
      ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)

      idag = MINDF.requestidag_term(remoteibnfhandler, ibnf)
      # @show typeof(idag)
      # @show propertynames(idag)
      # @show fieldnames(typeof(idag))
      # @show idag

      io = IOBuffer()
      serialize(io, idag)
      raw_bytes = take!(io)
  
      if !isnothing(idag)
        return HTTP.Response(200, raw_bytes)
      else
        return HTTP.Response(404, "Not possible to request the idag")
      end
    end


    @post "/api/ibnattributegraph" function (req; context)
        ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
        
        ibnattributegraph = MINDF.requestibnattributegraph_term!(remoteibnfhandler, ibnf)
        #@show typeof(ibnattributegraph)

        io = IOBuffer()
        serialize(io, ibnattributegraph)
        raw_bytes = take!(io)
        
        if !isnothing(ibnattributegraph)
            return HTTP.Response(200, raw_bytes)
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end


    @post "/api/request_handlers" function (req; context)
       ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
        
        ibnfhandlers = MINDF.requestibnfhandlers_term(remoteibnfhandler, ibnf)      
        if !isnothing(ibnfhandlers)
            return HTTP.Response(200, JSON.json(ibnfhandlers))

        else
            return HTTP.Response(404, "Handlers not found")
        end
    end

    
    @post "/api/logical_order" function (req; context)
        ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        verbose = parsedbody[MINDF.HTTPMessages.KEY_VERBOSE]
        logical_order = MINDF.requestlogicallliorder_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled, verbose)
      
        if !isnothing(logical_order)
            json_ready = [MINDF.serialize_lowlevelintent(ll) for ll in logical_order]
            return HTTP.Response(200, JSON.json(json_ready))

        else
            return HTTP.Response(404, "Handlers not found")
        end
    end


    @post "/api/intentglobalpath" function (req; context)
        ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        intentglobalpath = MINDF.requestintentglobalpath_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
        if !isnothing(intentglobalpath)
            json_ready = [MINDF.serialize_globalnode(igp) for igp in intentglobalpath]
            return HTTP.Response(200, JSON.json(json_ready))
        else
            return HTTP.Response(404, "Handlers not found")
        end
    end


    @post "/api/electricalpresence" function (req; context)
       ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        electricalpresence = MINDF.requestglobalnodeelectricalpresence_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
        if !isnothing(electricalpresence)
            json_ready = [MINDF.serialize_globalnode(igp) for igp in electricalpresence]
            return HTTP.Response(200, JSON.json(json_ready))
        else
            return HTTP.Response(404, "Handlers not found")
        end
    end


    @post "/api/lightpaths" function (req; context)
        ibnf, parsedbody, remoteibnfhandler = extractgeneraldata(req, context)
        
        intentuuid = UUID(parsedbody[MINDF.HTTPMessages.KEY_INTENTUUID])
        onlyinstalled = parsedbody[MINDF.HTTPMessages.KEY_ONLYINSTALLED]
        lightpaths = MINDF.requestintentgloballightpaths_term(remoteibnfhandler, ibnf, intentuuid; onlyinstalled)
        if !isnothing(lightpaths)
            json_ready = [[MINDF.serialize_globalnode(gn) for gn in path] for path in lightpaths]
            return HTTP.Response(200, JSON.json(json_ready))
        else
            return HTTP.Response(404, "Handlers not found")
        end
    end

    
    # TODO ma1069
    info = Dict("title" => "MINDFul Api", "version" => "1.0.0")
    openApi = OpenAPI("3.0", info)
    swagger_document = build(openApi)
    #open("swagger.json", "w") do file
    #    JSON.print(file, swagger_document)
    #end
    #println("Swagger documentation saved to swagger.json")
    # merge the SwaggerMarkdown schema with the internal schema
    OxygenInstance.mergeschema(swagger_document) 
     

end