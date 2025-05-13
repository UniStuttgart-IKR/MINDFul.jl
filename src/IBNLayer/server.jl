module Server
using Oxygen, HTTP, SwaggerMarkdown, JSON, UUIDs
#using Oxygen: serve 
using MINDFul
using MINDFul: @recvtime, @passtime
const MINDF = MINDFul


module OxygenInstance using Oxygen; @oxidise end

import .OxygenInstance: @get, @put, @post, @delete, mergeschema, serve, router

export serve

    api = OxygenInstance.router("/api", tags=["api endpoint"])
    
    @swagger """
    /api/compilation_algorithms: 
      post:
        description: Return the available compilation algorithms
        responses:
          "200":
            description: Successfully returned the compilation algorithms.
    """
    @post api("/compilation_algorithms") function (req)
        compilation_algorithms = MINDF.requestavailablecompilationalgorithms_term!()
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
        #body = JSON.parse(String(req.body))

        if context isa MINDF.IBNFramework
          println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
        elseif context isa Vector{MINDF.IBNFramework}
            println("context is of type Vector{MINDF.IBNFramework}")
            ibnfs :: Vector{MINDF.IBNFramework} = context
            host = Dict(req.headers)["Host"]
            @show host
            for ibnf_temp in ibnfs
              if ibnf_temp.ibnfhandlers[1].base_url == "http://$host"
                ibnf = ibnf_temp
              end
            end
            @show ibnf.ibnfid
        elseif context isa Dict{Int, MINDF.IBNFramework}
            println("context is of type Dict{Int, MINDF.IBNFramework}")
            ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
            host = Dict(req.headers)["Host"]
            @show host
            uri = HTTP.URI("http://$host")
            @show uri
            port = parse(Int, uri.port)
            ibnf = ibnfs_dict[port]
            
            @show ibnf.ibnfid
        else
            println("context is of an unexpected type: $(typeof(context))")
        end
        
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        ge_data = parsed_body["global_edge"]
        received_ge = MINDF.GlobalEdge(
            MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
            MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
        )
        remoteibnf_handler = nothing
        src_domain_id = UUID(parsed_body["src_domain"])
        handlers = MINDF.getibnfhandlers(ibnf)
        for handler in handlers
            if MINDF.getibnfid(handler) == src_domain_id
                remoteibnf_handler = handler
            end
        end
        #remoteibnf = MINDF.getibnfhandlers(ibnf)[src_domain]
        @show remoteibnf_handler
        spectrum_availability = MINDF.requestspectrumavailability_term!(ibnf, remoteibnf_handler, received_ge)
        #@show spectrum_availability
        if !isnothing(spectrum_availability)
            return HTTP.Response(200, JSON.json(spectrum_availability))
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end



    @post "/api/current_linkstate" function (req; context)
      #body = JSON.parse(String(req.body))
      if context isa MINDF.IBNFramework
          println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
      elseif context isa Vector{MINDF.IBNFramework}
          println("context is of type Vector{MINDF.IBNFramework}")
          ibnfs :: Vector{MINDF.IBNFramework} = context
          #@show req.headers
          host = Dict(req.headers)["Host"]
          @show host
          # uri = HTTP.URI("http://$host")
          # @show uri
          # port = parse(Int, uri.port)
          # @show port
          for ibnf_temp in ibnfs
            if ibnf_temp.ibnfhandlers[1].base_url == "http://$host"
              ibnf = ibnf_temp
            end
          end
          @show ibnf.ibnfid
      elseif context isa Dict{Int, MINDF.IBNFramework}
          println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          uri = HTTP.URI("http://$host")
          @show uri
          port = parse(Int, uri.port)
          ibnf = ibnfs_dict[port]
          
          @show ibnf.ibnfid
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      ge_data = parsed_body["global_edge"]
      received_ge = MINDF.GlobalEdge(
          MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
      )
      remoteibnf_handler = nothing
      src_domain_id = UUID(parsed_body["src_domain"])
      handlers = MINDF.getibnfhandlers(ibnf)
      for handler in handlers
          if MINDF.getibnfid(handler) == src_domain_id
              remoteibnf_handler = handler
          end
      end
      #remoteibnf = MINDF.getibnfhandlers(ibnf)[src_domain]
      @show remoteibnf_handler
      current_linkstate = MINDF.requestcurrentlinkstate_term(remoteibnf_handler, ibnf, received_ge)
      if !isnothing(current_linkstate)
          return HTTP.Response(200, JSON.json(current_linkstate))
      else
          return HTTP.Response(404, "Currently link not available")
      end
    end



    @post "/api/compile_intent" function (req; context)
      if context isa MINDF.IBNFramework
          println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
      elseif context isa Vector{MINDF.IBNFramework}
          println("context is of type Vector{MINDF.IBNFramework}")
          ibnfs :: Vector{MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          for ibnf_temp in ibnfs
            if ibnf_temp.ibnfhandlers[1].base_url == "http://$host"
              ibnf = ibnf_temp
            end
          end
          @show ibnf.ibnfid
      elseif context isa Dict{Int, MINDF.IBNFramework}
          println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          uri = HTTP.URI("http://$host")
          @show uri
          port = parse(Int, uri.port)
          ibnf = ibnfs_dict[port]
          
          @show ibnf.ibnfid
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      idagnodeid = UUID(parsed_body["idagnodeid"])
      compilationalgorithmkey = Symbol(parsed_body["compilationalgorithmkey"])
      compilationalgorithmargs = Tuple(parsed_body["compilationalgorithmargs"])

      remoteibnf_handler = nothing
      src_domain_id = UUID(parsed_body["src_domain"])
      handlers = MINDF.getibnfhandlers(ibnf)
      for handler in handlers
          if MINDF.getibnfid(handler) == src_domain_id
              remoteibnf_handler = handler
          end
      end

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
      
      if context isa MINDF.IBNFramework
          println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
      elseif context isa Vector{MINDF.IBNFramework}
          println("context is of type Vector{MINDF.IBNFramework}")
          ibnfs :: Vector{MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          for ibnf_temp in ibnfs
            if ibnf_temp.ibnfhandlers[1].base_url == "http://$host"
              ibnf = ibnf_temp
            end
          end
          @show ibnf.ibnfid
      elseif context isa Dict{Int, MINDF.IBNFramework}
          println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          uri = HTTP.URI("http://$host")
          @show uri
          port = parse(Int, uri.port)
          ibnf = ibnfs_dict[port]
          
          @show ibnf.ibnfid
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      internalidagnodeid = UUID(parsed_body["internalidagnodeid"])

      intent_data = parsed_body["intent"]
      
      rate = MINDF.GBPSf(parse(Float64, replace(intent_data["rate"], " Gbps" => "")))
      @show rate
      received_constraints = [reconvert_constraint(constraint) for constraint in intent_data["constraints"]] 
      @show received_constraints
      received_intent = MINDF.ConnectivityIntent(
          MINDF.GlobalNode(UUID(intent_data["src"]["ibnfid"]), intent_data["src"]["localnode"]),
          MINDF.GlobalNode(UUID(intent_data["dst"]["ibnfid"]), intent_data["dst"]["localnode"]),
          rate,
          received_constraints
      )

      remoteibnf_handler = nothing
      src_domain_id = UUID(parsed_body["src_domain"])
      handlers = MINDF.getibnfhandlers(ibnf)
      for handler in handlers
          if MINDF.getibnfid(handler) == src_domain_id
              remoteibnf_handler = handler
          end
      end

      delegate_intent = MINDF.requestdelegateintent_term!(remoteibnf_handler, ibnf, received_intent, internalidagnodeid)
      if !isnothing(delegate_intent)
        return HTTP.Response(200, JSON.json(delegate_intent))
      else
          return HTTP.Response(404, "Delegation not worked")
      end
      
    end



    @post "api/remoteintent_stateupdate" function (req; context)
      println("remoteintent_stateupdate")
      if context isa MINDF.IBNFramework
          println("context is of type MINDF.IBNFramework")
          ibnf :: MINDF.IBNFramework = context
      elseif context isa Vector{MINDF.IBNFramework}
          println("context is of type Vector{MINDF.IBNFramework}")
          ibnfs :: Vector{MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          for ibnf_temp in ibnfs
            if ibnf_temp.ibnfhandlers[1].base_url == "http://$host"
              ibnf = ibnf_temp
            end
          end
          @show ibnf.ibnfid
      elseif context isa Dict{Int, MINDF.IBNFramework}
          println("context is of type Dict{Int, MINDF.IBNFramework}")
          ibnfs_dict :: Dict{Int, MINDF.IBNFramework} = context
          host = Dict(req.headers)["Host"]
          @show host
          uri = HTTP.URI("http://$host")
          @show uri
          port = parse(Int, uri.port)
          ibnf = ibnfs_dict[port]
          
          @show ibnf.ibnfid
      else
          println("context is of an unexpected type: $(typeof(context))")
      end
      @show ibnf.ibnfid
      body = HTTP.payload(req)
      parsed_body = JSON.parse(String(body))
      idagnodeid = UUID(parsed_body["idagnodeid"])
      newstate = Symbol(parsed_body["newstate"])
      state = getfield(MINDF.IntentState, newstate)
      @show state

      remoteibnf_handler = nothing
      src_domain_id = UUID(parsed_body["src_domain"])
      # handlers = MINDF.getibnfhandlers(ibnf)
      # for handler in handlers
      #     if MINDF.getibnfid(handler) == src_domain_id
      #         remoteibnf_handler = handler
      #     end
      # end
      remoteibnf_handler = MINDF.getibnfhandler(ibnf, src_domain_id)

      if idagnodeid == UUID(0xc) && MINDF.getibnfid(ibnf) == UUID(0x3) && state == MINDF.IntentState.Compiled
        # This is a test case for the interdomain interface
        # It should be removed in the future
        println("TEST CASE QWERTY_SERVER")
        
        
      end

      updated_state = MINDF.requestremoteintentstateupdate_term!(remoteibnf_handler, ibnf, idagnodeid, state)
      @show updated_state
      if !isnothing(updated_state)
        return HTTP.Response(200, JSON.json(updated_state))
      else
        return HTTP.Response(404, "Not possible to update the intent state")
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