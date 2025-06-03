module Server
using Oxygen, HTTP, SwaggerMarkdown, JSON, UUIDs
#using Oxygen: serve 
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
            if ibnf_temp.ibnfhandlers[1].base_url == "http://$host"
              ibnf = ibnf_temp
            end
          end
          return ibnf
      elseif context isa Dict{Int, MINDF.IBNFramework}
          #println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          #@show host
          uri = HTTP.URI("http://$host")
          #@show uri
          port = parse(Int, uri.port)
          ibnf = ibnfs_dict[port]
          return ibnf
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
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
        initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
        remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

        compilation_algorithms = MINDF.requestavailablecompilationalgorithms_term!(remoteibnf_handler, ibnf)
        if !isnothing(compilation_algorithms)
            return HTTP.Response(200, JSON.json(compilation_algorithms))
        else
            return HTTP.Response(404, JSON.json(Dict("error" => "Compilation algorithms not found")))
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
        ibnf = getmyibnf(req, context)        
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        ge_data = parsed_body[MINDF.HTTPMessages.GLOBAL_EDGE]
        received_ge = MINDF.GlobalEdge(
            MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
            MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
        )
        initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
        remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

        @show ibnf.ibnfid
        
        spectrum_availability = MINDF.requestspectrumavailability_term!(remoteibnf_handler, ibnf, received_ge)
        #@show spectrum_availability
        if !isnothing(spectrum_availability)
            return HTTP.Response(200, JSON.json(spectrum_availability))
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end



    @post "/api/current_linkstate" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      ge_data = parsed_body[MINDF.HTTPMessages.GLOBAL_EDGE]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      
      current_linkstate = MINDF.requestcurrentlinkstate_term(remoteibnf_handler, ibnf, received_ge)
      if !isnothing(current_linkstate)
          return HTTP.Response(200, JSON.json(current_linkstate))
      else
          return HTTP.Response(404, "Currently link not available")
      end
    end



    @post "/api/compile_intent" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      idagnodeid = UUID(parsed_body[MINDF.HTTPMessages.IDAGNODEID])
      compilationalgorithmkey = Symbol(parsed_body[MINDF.HTTPMessages.COMPILATION_KEY])
      compilationalgorithmargs = Tuple(parsed_body[MINDF.HTTPMessages.COMPILATION_ARGS])
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

      compile_intent = MINDF.requestcompileintent_term!(remoteibnf_handler, ibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs)
      if !isnothing(compile_intent)
        return HTTP.Response(200, JSON.json(string(compile_intent)))
      else
        return HTTP.Response(404, "Not possible to compile the intent")
      end
      
    end



    @post "api/delegate_intent" function (req; context)
      function reconvert_constraint(constraint)
          if constraint["type"] == "OpticalInitiateConstraint"
              return MINDF.OpticalInitiateConstraint(
                  MINDF.GlobalNode(UUID(constraint["globalnode_input"]["ibnfid"]), constraint["globalnode_input"]["localnode"]),
                  constraint["spectrumslotsrange"][1]:constraint["spectrumslotsrange"][2],
                  MINDF.KMf(parse(Float64, replace(constraint["opticalreach"], " km" => ""))),
                  MINDF.TransmissionModuleCompatibility(MINDF.GBPSf(parse(Float64, replace(constraint["transmissionmodulecompat"]["rate"], " Gbps" => ""))), constraint["transmissionmodulecompat"]["spectrumslotsneeded"], constraint["transmissionmodulecompat"]["name"])
              )
          elseif constraint["type"] == "OpticalTerminateConstraint"
              return nothing
          else
              error("Unknown constraint type")
          end
      end
      
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      internalidagnodeid = UUID(parsed_body[MINDF.HTTPMessages.INTERNAL_IDAGNODEID])
      intent_data = parsed_body[MINDF.HTTPMessages.INTENT]
      rate = MINDF.GBPSf(parse(Float64, replace(intent_data["rate"], " Gbps" => "")))
      #@show rate
      received_constraints = [reconvert_constraint(constraint) for constraint in intent_data["constraints"]] 
      #@show received_constraints
      received_intent = MINDF.ConnectivityIntent(
          MINDF.GlobalNode(UUID(intent_data["src"]["ibnfid"]), intent_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(intent_data["dst"]["ibnfid"]), intent_data["dst"]["localnode"]),
          rate,
          received_constraints
      )
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

      delegate_intent = MINDF.requestdelegateintent_term!(remoteibnf_handler, ibnf, received_intent, internalidagnodeid)
      if !isnothing(delegate_intent)
        return HTTP.Response(200, JSON.json(delegate_intent))
      else
          return HTTP.Response(404, "Delegation not worked")
      end
    end


    @post "api/remoteintent_stateupdate" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      idagnodeid = UUID(parsed_body[MINDF.HTTPMessages.IDAGNODEID])
      newstate = Symbol(parsed_body[MINDF.HTTPMessages.NEWSTATE])
      state = getfield(MINDF.IntentState, newstate)
      #@show state
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      #=if idagnodeid == UUID(0xc) && MINDF.getibnfid(ibnf) == UUID(0x3) && state == MINDF.IntentState.Compiled        
        println("TEST CASE QWERTY_SERVER")        
      end=#

      updated_state = MINDF.requestremoteintentstateupdate_term!(remoteibnf_handler, ibnf, idagnodeid, state)
      #@show updated_state
      if !isnothing(updated_state)
        return HTTP.Response(200, JSON.json(updated_state))
      else
        return HTTP.Response(404, "Not possible to update the intent state")
      end
      
    end


    @post "api/requestissatisfied" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))

      idagnodeid = UUID(parsed_body[MINDF.HTTPMessages.IDAGNODEID])
      onlyinstalled = parsed_body[MINDF.HTTPMessages.ONLY_INSTALLED]
      noextrallis = parsed_body[MINDF.HTTPMessages.NOEXTRALLIS]
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

      issatisfied_result = MINDF.requestissatisfied_term!(remoteibnf_handler, ibnf, idagnodeid; onlyinstalled, noextrallis)
      #@show issatisfied_result
      if !isnothing(issatisfied_result)
        return HTTP.Response(200, JSON.json(issatisfied_result))
      else
        return HTTP.Response(404, "Not possible to check if the intent is satisfied")
      end
    end


    @post "/api/install_intent" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))

      idagnodeid = UUID(parsed_body[MINDF.HTTPMessages.IDAGNODEID])
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      verbose = parsed_body[MINDF.HTTPMessages.VERBOSE]

      install_intent = MINDF.requestinstallintent_term!(remoteibnf_handler, ibnf, idagnodeid; verbose)
      if !isnothing(install_intent)
        return HTTP.Response(200, JSON.json(install_intent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post "/api/uninstall_intent" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))

      idagnodeid = UUID(parsed_body[MINDF.HTTPMessages.IDAGNODEID])
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      verbose = parsed_body[MINDF.HTTPMessages.VERBOSE]

      uninstall_intent = MINDF.requestuninstallintent_term!(remoteibnf_handler, ibnf, idagnodeid; verbose)
      if !isnothing(uninstall_intent)
        return HTTP.Response(200, JSON.json(uninstall_intent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post "/api/uncompile_intent" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))

      idagnodeid = UUID(parsed_body[MINDF.HTTPMessages.IDAGNODEID])
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      verbose = parsed_body[MINDF.HTTPMessages.VERBOSE]

      uncompile_intent = MINDF.requestuncompileintent_term!(remoteibnf_handler, ibnf, idagnodeid; verbose)
      if !isnothing(uncompile_intent)
        return HTTP.Response(200, JSON.json(uncompile_intent))
      else
        return HTTP.Response(404, "Not possible to install the intent")
      end
    end


    @post "/api/set_linkstate" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      ge_data = parsed_body[MINDF.HTTPMessages.GLOBAL_EDGE]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      operatingstate = parsed_body[MINDF.HTTPMessages.OPERATINGSTATE]
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      
      set_linkstate = MINDF.requestsetlinkstate_term!(remoteibnf_handler, ibnf, received_ge, operatingstate)
      if !isnothing(set_linkstate)
          return HTTP.Response(200, JSON.json(set_linkstate))
      else
          return HTTP.Response(404, "Set link state not possible")
      end
    end


    @post "/api/request_linkstates" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      ge_data = parsed_body[MINDF.HTTPMessages.GLOBAL_EDGE]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
      
      request_linkstates = MINDF.requestlinkstates_term(remoteibnf_handler, ibnf, received_ge)
      #@show request_linkstates
      if !isnothing(request_linkstates)
          json_ready = [Dict(MINDF.HTTPMessages.LINK_DATETIME => string(dt), MINDF.HTTPMessages.LINK_STATE => s) for (dt, s) in request_linkstates]
          return HTTP.Response(200, JSON.json(json_ready))
      else
          return HTTP.Response(404, "Set link state not possible")
      end
    end


    function serialize_idag(idag)
        #@show typeof(idag)
        #@show idag.edge_list
        
        #@show idag.vertex_attr
        #@show idag.graph_attr
        @show idag.edge_attr
        return Dict(
            "graph" => serialize_simpledigraph(idag.graph),
            "nodes" => [serialize_intentdagnode(n) for n in idag.vertex_attr],
            "info" => serialize_idaginfo(idag.graph_attr)
        )
    end

    function serialize_simpledigraph(g)
        return Dict(
            "nv" => g.nv,
            "outneighbors" => g.outneighbors,
            "inneighbors" => g.inneighbors
        )
    end

    function serialize_idaginfo(info)
        return Dict("count" => info.count)
    end

    function serialize_intentdagnode(node)
        return Dict(
            "type" => string(typeof(node)),
            "uuid" => string(node.uuid),
            "data" => serialize_node_data(node.data),
            "generator" => string(typeof(node.generator)),
            "statelog" => [Dict("datetime" => string(dt), "state" => string(state)) for (dt, state) in node.statelog]
        )
    end

    function serialize_node_data(data)
        if typeof(data) <: MINDFul.RemoteIntent
            return serialize_remoteintent(data)
        elseif typeof(data) <: MINDFul.ConnectivityIntent
            return serialize_connectivityintent(data)
        elseif typeof(data) <: MINDFul.RouterPortLLI
            return serialize_routerportlli(data)
        elseif typeof(data) <: MINDFul.OXCAddDropBypassSpectrumLLI
            return serialize_oxcadddropbypassspectrumlli(data)
        elseif typeof(data) <: MINDFul.TransmissionModuleLLI
            return serialize_transmissionmodulelli(data)
        else
            return string(data)
        end
    end

    function serialize_remoteintent(ri)
        return Dict(
            "remote_ibnfid" => string(ri.remote_ibnfid),
            "internal_idagnodeid" => string(ri.internal_idagnodeid),
            "intent" => serialize_connectivityintent(ri.intent),
            "is_terminal" => ri.is_terminal
        )
    end

    function serialize_connectivityintent(ci)
        return Dict(
            "src" => serialize_globalnode(ci.src),
            "dst" => serialize_globalnode(ci.dst),
            "rate" => string(ci.rate),
            "constraints" => [string(c) for c in ci.constraints] # You can expand this if you want detailed constraint serialization
        )
    end

    function serialize_globalnode(gn)
        return Dict(
            "ibnfid" => string(gn.ibnfid),
            "localnode" => gn.localnode
        )
    end

    function serialize_routerportlli(rp)
        return Dict(
            "node" => rp.node,
            "port" => rp.port
        )
    end

    function serialize_oxcadddropbypassspectrumlli(oxc)
        return Dict(
            "node" => oxc.node,
            "port" => oxc.port,
            "direction" => oxc.direction,
            "adddrop" => oxc.adddrop,
            "slots" => collect(oxc.slots)
        )
    end

    function serialize_transmissionmodulelli(tm)
        return Dict(
            "srcnode" => tm.srcnode,
            "dstnode" => tm.dstnode,
            "srcport" => tm.srcport,
            "dstport" => tm.dstport,
            "modulation" => tm.modulation
        )
    end
    

    @post "/api/request_idag" function (req; context)
      ibnf = getmyibnf(req, context)
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)

      idag = MINDF.requestidag_term(remoteibnf_handler, ibnf)
      @show typeof(idag)
      @show propertynames(idag)
      @show fieldnames(typeof(idag))
      @show idag

      io = IOBuffer()
      serialize(io, idag)
      raw_bytes = take!(io)
      #idag_stream::IO
      #serialize(idag_stream, idag)
      
      # serialized_idag = serialize_idag(idag)
      # @show serialized_idag
      if !isnothing(idag)
        #return HTTP.Response(200, JSON.json(string(idag)))
        return HTTP.Response(200, raw_bytes)
      else
        return HTTP.Response(404, "Not possible to request the idag")
      end
    end


    @post "/api/ibnattributegraph" function (req; context)
        ibnf = getmyibnf(req, context)        
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
        remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
        
        ibnattributegraph = MINDF.requestibnattributegraph_term!(remoteibnf_handler, ibnf)
        @show typeof(ibnattributegraph)

        io = IOBuffer()
        serialize(io, ibnattributegraph)
        raw_bytes = take!(io)
        if !isnothing(ibnattributegraph)
            #return HTTP.Response(200, JSON.json(string(ibnattributegraph)))
            return HTTP.Response(200, raw_bytes)

        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end

    @post "/api/request_handlers" function (req; context)
        ibnf = getmyibnf(req, context)        
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
        remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
        
        ibnfhandlers = MINDF.requestibnfhandlers_term(remoteibnf_handler, ibnf)

        @show ibnfhandlers
      
        if !isnothing(ibnfhandlers)
            #return HTTP.Response(200, JSON.json(string(ibnattributegraph)))
            return HTTP.Response(200, ibnfhandlers)

        else
            return HTTP.Response(404, "Handlers not found")
        end
    end

    function serialize_lowlevelintent(ll)
        if ll isa MINDFul.OXCAddDropBypassSpectrumLLI
            return Dict(
                "type" => "OXCAddDropBypassSpectrumLLI",
                "node" => ll.localnode,
                "input" => ll.localnode_input,
                "adddropport" => ll.adddropport,
                "output" => ll.localnode_output,
                "slots" => [ll.spectrumslotsrange.start, ll.spectrumslotsrange.stop]
            )
        elseif ll isa MINDFul.TransmissionModuleLLI
            return Dict(
                "type" => "TransmissionModuleLLI",
                "node" => ll.localnode,
                "poolindex" => ll.transmissionmoduleviewpoolindex,
                "modesindex" => ll.transmissionmodesindex,
                "port" => ll.routerportindex,
                "adddropport" => ll.adddropport
            )
        elseif ll isa MINDFul.RouterPortLLI
            return Dict(
                "type" => "RouterPortLLI",
                "node" => ll.localnode,
                "port" => ll.routerportindex
            )
        else
            error("Unknown LowLevelIntent type: $(typeof(ll))")
        end
    end

    @post "/api/logical_order" function (req; context)
        ibnf = getmyibnf(req, context)        
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        initiator_ibnfid = UUID(parsed_body[MINDF.HTTPMessages.INITIATOR_IBNFID])
        remoteibnf_handler = MINDF.getibnfhandler(ibnf, initiator_ibnfid)
        
        intentuuid = UUID(parsed_body[MINDF.HTTPMessages.INTENTUUID])
        onlyinstalled = parsed_body[MINDF.HTTPMessages.ONLY_INSTALLED]
        verbose = parsed_body[MINDF.HTTPMessages.VERBOSE]
        logical_order = MINDF.requestlogicallliorder_term(remoteibnf_handler, ibnf, intentuuid; onlyinstalled, verbose)

        @show logical_order
      
        if !isnothing(logical_order)
            json_ready = [serialize_lowlevelintent(ll) for ll in logical_order]
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