"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct KShorestPathFirstFitCompilation <: IntentCompilationAlgorithm
    "How many k paths to check"
    k::Int
end

"""
$(TYPEDSIGNATURES)
"""
function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, kspffalg::KShorestPathFirstFitCompilation)
    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))

    if getibnfid(ibnf) == getibnfid(sourceglobalnode) == getibnfid(destinationglobalnode)
        # intra-domain
        kspffintradomain(ibnf, idagnode, kspffalg)
    elseif getibnfid(ibnf) == getibnfid(sourceglobalnode) && getibnfid(ibnf) !== getibnfid(destinationglobalnode)
        # source intra-domain , destination cross-domain
        # border-node
        if isbordernode(destinationglobalnode, ibnf)
            @info "inside"
        end
        # unvisible cross-domain node
    end

    return false
end

function kspffintradomain(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, kspffalg::KShorestPathFirstFitCompilation)
    # needed variables
    ibnag = getibnag(ibnf)
    idag = getidag(ibnf)
    idagnodeid = getidagnodeid(idagnode)
    intent = getintent(idagnode)
    sourceglobalnode = getsourcenode(intent)
    destinationglobalnode = getdestinationnode(intent)
    demandrate = getrate(intent)

    # start algorthim
    sourcelocalnode = getlocalnode(sourceglobalnode)
    destlocalnode = getlocalnode(destinationglobalnode)
    yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, getweights(ibnag), kspffalg.k)
    # try out all paths
    sourcenodeview = getnodeview(ibnag, sourcelocalnode)
    destnodeview = getnodeview(ibnag, destlocalnode)
    sourceavailtransmdlidxs = getavailabletransmissionmoduleviewindex(sourcenodeview)
    sourcetransmissionmoduleviewpool = gettransmissionmoduleviewpool(sourcenodeview)
    destavailtransmdlidxs = getavailabletransmissionmoduleviewindex(destnodeview)
    desttransmissionmoduleviewpool = gettransmissionmoduleviewpool(destnodeview)
    for (dist, path) in zip(yenstate.dists, yenstate.paths)
        for sourceavailtransmdlidx in sourceavailtransmdlidxs
            sourcetransmissionmodule = sourcetransmissionmoduleviewpool[sourceavailtransmdlidx]
            transmodeidx = getlowestratetransmissionmode(sourcetransmissionmodule, demandrate, dist)
            if !isnothing(transmodeidx)
                transmode = gettransmissionmode(sourcetransmissionmodule, transmodeidx)
                demandslotsneeded = getspectrumslotsneeded(transmode)
                # found a transmission module with a transmission mode for source
                # is it available on the destination node ?
                destavailtransmdlidx = getfirst(destavailtransmdlidxs) do destavailtransmdlidx
                    aretransmissionmodulescompatible(sourcetransmissionmodule, desttransmissionmoduleviewpool[destavailtransmdlidx])
                end
                if !isnothing(destavailtransmdlidx)
                    # found a transmission module with a transmission mode for source and destination
                    sourcetransmissionmodulelli = TransmissionModuleLLI(sourcelocalnode, sourceavailtransmdlidx, transmodeidx)
                    desttransmissionmodulelli = TransmissionModuleLLI(destlocalnode, destavailtransmdlidx, transmodeidx)

                    # find router ports
                    sourcerouterindex = getfirstavailablerouterportindex(getrouterview(sourcenodeview))
                    if !isnothing(sourcerouterindex)
                        destrouterindex = getfirstavailablerouterportindex(getrouterview(destnodeview))
                        if !isnothing(destrouterindex)
                            sourcerouterportlli = RouterPortLLI(sourcelocalnode, sourcerouterindex)
                            destrouterportlli = RouterPortLLI(destlocalnode, destrouterindex)

                            # find spectrum slots
                            # get path availabilities
                            pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
                            startingslot = firstfit(pathspectrumavailability, demandslotsneeded)
                            if !isnothing(startingslot)
                                # is there oxc ports in the source and destination ?
                                sourceadddropport = getfirstavailablerouterportindex(sourcenodeview)
                                destadddropport = getfirstavailablerouterportindex(destnodeview)
                                if !isnothing(sourceadddropport) && !isnothing(destadddropport)
                                    oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(path, sourceadddropport, destadddropport, startingslot:(startingslot + demandslotsneeded - 1))
                                    # we have the TransmissionModuleLLI, RouterPortLLI and OXCAddDropBypassSpectrumLLI
                                    addidagnode!(idag, sourcetransmissionmodulelli; parentid = idagnodeid, intentissuer = MachineGenerated())
                                    addidagnode!(idag, desttransmissionmodulelli; parentid = idagnodeid, intentissuer = MachineGenerated())
                                    addidagnode!(idag, sourcerouterportlli; parentid = idagnodeid, intentissuer = MachineGenerated())
                                    addidagnode!(idag, destrouterportlli; parentid = idagnodeid, intentissuer = MachineGenerated())
                                    foreach(oxcadddropbypassspectrumllis) do oxcadddropbypassspectrumlli
                                        addidagnode!(idag, oxcadddropbypassspectrumlli; parentid = idagnodeid, intentissuer = MachineGenerated())
                                    end
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
