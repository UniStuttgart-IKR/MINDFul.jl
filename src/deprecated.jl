"""
$(TYPEDSIGNATURES)
Implementation of Diffiie-Hellman exchange for authentication. The shared secret serves as unilateral authentication challenge.
The post macro is used to handle the Diffie-Hellman exchange inside the Oxygen server module.
Also, the agreed prime number and one of its roots must be stored in the corresponding handlers of each domain.
"""
function diffiehellman_init(ibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler)
    initiatoribnfid = string(getibnfid(ibnf))

    publicnumber, privatenumber = diffiehellman_term(remoteibnfhandler)

    url = getbaseurl(remoteibnfhandler) * HTTPMessages.URI_DIFFIEHELLMAN
    headers = Dict("Content-Type" => "application/json")
    data = Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, HTTPMessages.KEY_PUBLICNUMBER => publicnumber)
    body = JSON.json(data)

    response = HTTP.post(url, headers, body; keepalive = false, require_ssl_verification = false)
    if response.status == 200
        parsedresponse = JSON.parse(String(response.body))
        recievednumber = parsedresponse[HTTPMessages.KEY_PUBLICNUMBER]
        receivedsecret = parsedresponse[HTTPMessages.KEY_DHSECRET]
        return (receivedsecret == powermod(recievednumber, privatenumber, remoteibnfhandler.prime))
    else
        error("DH failed with $remoteibnfhandler: $(response.status)")
    end
end

function diffiehellman_term(remoteibnfhandler::RemoteHTTPHandler)
    prime = remoteibnfhandler.prime
    root = remoteibnfhandler.root
    privatenumber = rand(1:100)
    publicnumber = powermod(root, privatenumber, prime)
    return publicnumber, privatenumber
end


#=
@post api("/diffiehellman") function (req; context)
        ibnf = getmyibnf(req, context)
        
        parsedbody = JSON.parse(String(HTTP.payload(req)))
        remoteibnfid = parsedbody[MINDF.HTTPMessages.KEY_INITIATORIBNFID]
        publicnumberA = parsedbody[MINDF.HTTPMessages.KEY_PUBLICNUMBER]
        
        remotehandler = MINDF.getibnfhandler(ibnf, UUID(remoteibnfid))
     
        if !isnothing(publicnumberA) 
            publicnumberB, privatenumber = MINDF.diffiehellman_term(remotehandler)
            dhsecret = powermod(publicnumberA, privatenumber, remotehandler.prime)
            return HTTP.Response(200, JSON.json(Dict(MINDF.HTTPMessages.KEY_PUBLICNUMBER => publicnumberB, MINDF.HTTPMessages.KEY_DHSECRET => dhsecret)))
        else
            return HTTP.Response(403, "Nonce not received")
        end        
    end
=#

"""
$(TYPEDSIGNATURES)
    Return a Vector of grooming possibilities.
    Suggest grooming only if remains on the same path.
    Suggest grooming only if one extra router port pair is used.

    Return a `Vector` of grooming possibilities: `Vector{Vector{Union{UUID, Edge{Int}}}}`
    Each element is a `Vector` of either an intent `UUID` or a new connectivity intent defined with `Edge`.

    Sorting of the grooming possibilities is done just by minimizing lightpaths used
"""
function prioritizegrooming_default(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}; candidatepaths::Vector{Vector{Vector{LocalNode}}} = Vector{Vector{Vector{LocalNode}}}())
    intent = getintent(idagnode)
    srcglobalnode = getsourcenode(intent)
    dstglobalnode = getdestinationnode(intent)
    srcnode = getlocalnode(getibnag(ibnf), srcglobalnode)
    dstnode = getlocalnode(getibnag(ibnf), dstglobalnode)

    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()

    if !(getibnfid(ibnf) == getibnfid(srcglobalnode) == getibnfid(dstglobalnode))
        if isbordernode(ibnf, srcglobalnode)
            any(x -> x isa OpticalInitiateConstraint, getconstraints(intent)) || return groomingpossibilities
        elseif isbordernode(ibnf, dstglobalnode)
            any(x -> x isa OpticalTerminateConstraint, getconstraints(intent)) || return groomingpossibilities
        else
            # cross domain intent
            # find lightpath combinations regardless of paths
            return groomingpossibilities
        end
    end

    # these are already fail-free
    if isempty(candidatepaths)
        candidatepaths = prioritizepaths_shortest(ibnf, idagnode)
    end

    # intentuuid => LightpathRepresentation
    installedlightpaths = collect(pairs(getinstalledlightpaths(getidaginfo(getidag(ibnf)))))
    filter!(installedlightpaths) do (lightpathuuid, lightpathrepresentation)
        getresidualbandwidth(ibnf, lightpathuuid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent) &&
            getidagnodestate(getidag(ibnf), lightpathuuid) == IntentState.Installed
    end

    for candidatepath in Iterators.flatten(candidatepaths)
        containedlightpaths = Vector{Vector{Int}}()
        containedlpuuids = UUID[]
        for (intentid, lightpathrepresentation) in installedlightpaths
            ff = findfirst( path -> issubpath(candidatepath, path), getpath(lightpathrepresentation))
            if !isnothing(ff)
                pathlightpathrepresentation = getpath(lightpathrepresentation)[ff]
                opttermconstraint = getfirst(c -> c isa OpticalTerminateConstraint, getconstraints(intent))
                if pathlightpathrepresentation[end] == dstnode && !isnothing(opttermconstraint)
                    if getterminatessoptically(lightpathrepresentation) && getdestinationnode(lightpathrepresentation) == getdestinationnode(opttermconstraint)
                        push!(containedlightpaths, pathlightpathrepresentation)
                        push!(containedlpuuids, intentid)
                    end
                else
                    push!(containedlightpaths, pathlightpathrepresentation)
                    push!(containedlpuuids, intentid)
                end
            end
        end

        ## starting lightpaths
        startinglightpathscollections = consecutivelightpathsidx(containedlightpaths, srcnode; startingnode = true)

        ## ending lightpaths
        endinglightpathscollections = consecutivelightpathsidx(containedlightpaths, dstnode; startingnode = false)

        for lightpathcollection in Iterators.flatten((startinglightpathscollections, endinglightpathscollections))
            lpc2insert = Vector{Union{UUID, Edge{Int}}}()
            for lpidx in lightpathcollection
                push!(lpc2insert, containedlpuuids[lpidx])
            end

            firstlightpath = containedlightpaths[lightpathcollection[1]]
            if firstlightpath[1] != srcnode
                pushfirst!(lpc2insert, Edge(srcnode, firstlightpath[1]))
            end
            lastlightpath = containedlightpaths[lightpathcollection[end]]
            if lastlightpath[end] != dstnode
                push!(lpc2insert, Edge(lastlightpath[end], dstnode))
            end

            # is it low-priority or high-priority ?
            index = searchsortedfirst(groomingpossibilities, lpc2insert; by = length)

            if index > length(groomingpossibilities) || groomingpossibilities[index] != lpc2insert #if not already inside
                insert!(groomingpossibilities, index, lpc2insert)
            end
        end

    end

    return groomingpossibilities
end#
