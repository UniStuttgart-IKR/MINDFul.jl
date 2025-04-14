# Every function in this file should be implemented for all `AbstractIBNFHandler`
# MA1069
# each function should have an _init and a _term version
# _init is to construct the data structures, send them and initiate connection
# _init functions should be different for RemoteIBNFHandler and IBNFramework but `term` should be the same
# _term is for the terminal entity to do the job
# the operation might  depend on the relation of `myibnf`, and `remoteibnf`.
 
"""
$(TYPEDSIGNATURES) 

Request topology information
"""
#function requestibnattributegraph(myibnf::IBNFramework, remoteibnf::IBNFramework)
#    return getibnag(remoteibnf)
#end

"""
$(TYPEDSIGNATURES) 

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestspectrumavailability(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
    remoteibnag = getibnag(remoteibnf)
    nodeviewsrc = getnodeview(remoteibnag, src(ge))
    nodeviewdst = getnodeview(remoteibnag, dst(ge))
    localnodesrc = something(getlocalnode(remoteibnag, src(ge)))
    localnodedst = something(getlocalnode(remoteibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(myibnf)
        # src is remote, dst is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewdst)))[le]
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(myibnf)
        # dst is remote, src is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewsrc)))[le]
    end

    return nothing
end

"""
$(TYPEDSIGNATURES) 

Return the id of the new dag node if successful and `nothing` otherwise
"""
function requestdelegateintent!(myibnf::IBNFramework, remoteibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
    remoteintent = RemoteIntent(getibnfid(myibnf), internalidagnodeid, intent, false)
    remoteintentdagnode = addidagnode!(getidag(remoteibnf), remoteintent)
    return getidagnodeid(remoteintentdagnode)
end

"""
$(TYPEDSIGNATURES)

Compilation algorithms are given as symbols because they might not be available programmatically to different IBN frameworks
"""
function requestavailablecompilationalgorithms(myibnf::IBNFramework, remoteibnf::IBNFramework{<:AbstractOperationMode})
    compalglist = [KSPFFalg]
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `myibnf` asks `remoteibnf` to compile the external remote intent `idagnodeid` with the specified compilation algorithm
"""
function requestcompileintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    requestcompileintent_term!(myibnf, remoteibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs)
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
function requestcompileintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    # get the algorithm
    compilationalgorithm = getcompilationalgorithm(myibnf, compilationalgorithmkey, compilationalgorithmargs)
    return compileintent!(myibnf, idagnodeid, compilationalgorithm)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestinstallintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return requestinstallintent_term!(myibnf, remoteibnf, idagnodeid; verbose=false)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestinstallintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return installintent!(myibnf, idagnodeid; verbose)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestuninstallintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return requestuninstallintent_term!(myibnf, remoteibnf, idagnodeid; verbose=false)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestuninstallintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return uninstallintent!(myibnf, idagnodeid; verbose)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestuncompileintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return requestuncompileintent_term!(myibnf, remoteibnf, idagnodeid; verbose=false)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestuncompileintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    uncompiledflag = uncompileintent!(myibnf, idagnodeid; verbose)
    if uncompiledflag
        # delete also the intent
        return removeintent!(myibnf, idagnodeid; verbose)
    else
        return false
    end
end

"""
$(TYPEDSIGNATURES) 

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
"""
function requestissatisfied(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; onlyinstalled::Bool, noextrallis::Bool)
    return issatisfied(remoteibnf, idagnodeid; onlyinstalled, noextrallis)
end

"""
$(TYPEDSIGNATURES) 

Request the initiator `remoteibnf` to update the state of its mirrored remote intent
"""
function requestremoteintentstateupdate!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
    oldstate = getidagnodestate(getidag(remoteibnf), idagnodeid)
    if oldstate != newstate
        idagnode = getidagnode(getidag(remoteibnf), idagnodeid)
        pushstatetoidagnode!(idagnode, now(), newstate)
        foreach(getidagnodeparents(getidag(remoteibnf), idagnodeid)) do idagnodeparent
            updateidagnodestates!(remoteibnf, idagnodeparent)
        end
    end
    return oldstate != newstate
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation
If far away, think about authorization and permissions.
That's the reason why there are 2 arguments: The first argument should have the authorization.
"""
function requestibnattributegraph(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    status, response = send_request(remoteibnfhandler, "/api/ibnattributegraph", Dict("ibnfid" => string(myibnf.ibnfid)))
    if status == 200
        return response  # Parse and return the graph
    else
        error("Failed to request IBN Attribute Graph: $(response)")
    end

end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""

function requestspectrumavailability_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
    server2 = start_ibn_server_ge(remoteibnf, ge)
    
    sel_handler = myibnf.ibnfhandlers[1]
    base_url = sel_handler.handlerproperties.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    
    #server1 = HTTP.serve!(ip_address, port) do
    local status, response
        try
            status, response = send_request(remoteibnf, "/api/spectrum_availability", Dict("ibnfid" => string(myibnf.ibnfid)))
        catch
            close(server2)
        else
            if status == 200
                return response  
            else
                error("Failed to request spectrum availability: $(response)")
            end
        end
            
    #end
    #close(server1)
    #close(server2)
end

function requestspectrumavailability_term!(myibnf::IBNFramework, ge::GlobalEdge)
    
    remoteibnag = getibnag(myibnf)
    #remoteibnag = requestibnattributegraph(myibnf, remoteibnfhandler) 

    nodeviewsrc = getnodeview(remoteibnag, src(ge))
    nodeviewdst = getnodeview(remoteibnag, dst(ge))
    localnodesrc = something(getlocalnode(remoteibnag, src(ge)))
    localnodedst = something(getlocalnode(remoteibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(myibnf)
        # src is remote, dst is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewdst)))[le]
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(myibnf)
        # dst is remote, src is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewsrc)))[le]
    end

    return nothing
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation

Delegates an intent to another domain

Return the id of the new dag node if successful and `nothing` otherwise
"""
function requestdelegateintent!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, intent::AbstractIntent, internalidagnodeid::UUID)
    error("not implemented")
end

"""
$(TYPEDSIGNATURES)

Fabian Gobantes implementation
"""
#=
function requestavailablecompilationalgorithms_init!(myibnf::IBNFramework, remoteibnf::IBNFramework)
    server2 = start_ibn_server(remoteibnf)
    
    sel_handler = myibnf.ibnfhandlers[1]
    base_url = sel_handler.handlerproperties.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)


    
    #server1 = HTTP.serve!(ip_address, port) do
    local status, response
        try
            status, response = send_request(remoteibnf, "/api/compilation_algorithms", Dict("ibnfid" => string(myibnf.ibnfid)))
        catch
            close(server2)
        else
            if status == 200
                return response
                close(server2)  
            else
                error("Failed to request compilation algorithms: $(response)")
            end
        end
end
=#



function requestavailablecompilationalgorithms_init!(myibnf::IBNFramework, remoteibnf::IBNFramework)
    server2 = start_ibn_server(remoteibnf)
    
    req_handler = myibnf.ibnfhandlers[1]
    req_url = req_handler.handlerproperties.base_url
    uri = HTTP.URI(req_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    

    server1 = HTTP.serve!(ip_address, port) do req
        response = send_request(remoteibnf, "/api/compilation_algorithms", Dict("ibnfid" => string(myibnf.ibnfid)))
        if response.status == 200
            return HTTP.Response(response.body)
        else
            error("Failed to request compilation algorithms")
        end 
        #return response.status, JSON.parse(String(response.body))
        
        #= status, response = send_request(remoteibnf, "/api/compilation_algorithms", Dict("ibnfid" => string(myibnf.ibnfid)))
        @show response
        if status == 200
            return response
            close(server2)  
        else
            error("Failed to request compilation algorithms: $(response)")
        end =#
    end

    resp = send_request(myibnf, "/api/compilation_algorithms", Dict("ibnfid" => string(remoteibnf.ibnfid)))
    
    close(server1)
    close(server2)

    return JSON.parse(String(resp.body))
    
end

function requestavailablecompilationalgorithms_term!(myibnf::IBNFramework)
    compalglist = [KSPFFalg]
    return compalglist
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation
"""
function requestcompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, compilationalgorithm::Symbol=:default, compilationalgorithmkey::Tuple=())
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 
Fabian Gobantes implementation

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
function requestcompileintent_term!(remoteibnfhandler::RemoteIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
"""
function requestissatisfied(myibnf::IBNFramework, remoteibnf::RemoteIBNFHandler, idagnode::IntentDAGNode; onlyinstalled::Bool, noextrallis::Bool)
    error("not implemented")
end
