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
        return kspffintradomain(ibnf, idagnode, kspffalg)
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

function kspffintradomain_2!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, kspffalg::KShorestPathFirstFitCompilation)
    # needed variables
    ibnag = getibnag(ibnf)
    idag = getidag(ibnf)
    idagnodeid = getidagnodeid(idagnode)
    intent = getintent(idagnode)
    sourceglobalnode = getsourcenode(intent)
    sourcelocalnode = getlocalnode(sourceglobalnode)
    sourcenodeview = getnodeview(ibnag, sourcelocalnode)
    destinationglobalnode = getdestinationnode(intent)
    destlocalnode = getlocalnode(destinationglobalnode)
    destnodeview = getnodeview(ibnag, destlocalnode)
    demandrate = getrate(intent)
    constraints = getconstraints(intent)

    # start algorthim
    yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, getweights(ibnag), kspffalg.k)

    lowlevelintentstoadd = LowLevelIntent[]
    ## define a TransmissionModuleCompatibility for the destination node
    transmissionmodulecompat = nothing
    opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
    if !isnothing(opticalinitiateconstraint)
        # find router port 
        sourcerouterindex = getfirstavailablerouterportindex(getrouterview(sourcenodeview))
        if !isnothing(sourcerouterindex)
            sourcerouterportlli = RouterPortLLI(sourcelocalnode, sourcerouterindex)
            push!(lowlevelintentstoadd, sourcerouterportlli)

            for (dist, path) in zip(yenstate.dists, yenstate.paths)
                # find transmission module and mode
                sourceavailtransmdlidxs = getavailabletransmissionmoduleviewindex(sourcenodeview)
                sourcetransmissionmoduleviewpool = gettransmissionmoduleviewpool(sourcenodeview)
                for sourcetransmdlidx in sourceavailtransmdlidxs
                    sourcetransmissionmodule = sourcetransmissionmoduleviewpool[sourcetransmdlidx]
                    sourcetransmissiomodeidx = getlowestratetransmissionmode(sourcetransmissionmodule, demandrate, dist)
                    if !isnothing(sourcetransmissiomodeidx)
                        sourcetransmissionmode = gettransmissionmode(sourcetransmissionmodule, sourcetransmissiomodeidx)
                        demandslotsneeded = getspectrumslotsneeded(sourcetransmissionmode)
                        transmissionmoderate = getrate(sourcetransmissionmode)
                        transmissionmodulename = getname(sourcetransmissionmodule)

                        sourcetransmissionmodulelli = TransmissionModuleLLI(sourcelocalnode, sourcetransmdlidx, sourcetransmissiomodeidx)
                        push!(lowlevelintentstoadd, sourcetransmissionmodulelli)

                        transmissionmodulecompat = TransmissionModuleCompatibility(transmissionmoderate, demandslotsneeded, transmissionmodulename)

                        # find oxc configuration
                        pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
                        startingslot = firstfit(pathspectrumavailability, demandslotsneeded)
                        if !isnothing(startingslot)
                            # are there oxc ports in the source ?
                            sourceadddropport = getfirstavailableoxcadddropport(sourcenodeview)
                            if !isnothing(sourceadddropport)
                                oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(path, startingslot:(startingslot + demandslotsneeded - 1); sourceadddropport, destadddropport = nothing)
                                foreach(oxcadddropbypassspectrumllis) do lli
                                    push!(lowlevelintentstoadd, lli)
                                end
                                
                                # successful source-path configuration
                                opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
                                if !isnothing(opticalterminateconstraint)
                                    # no need to do something more. return true
                                    foreach(lowlevelintentstoadd) do lli
                                        addidagnode!(idag, lli; parentid = idagnodeid, intentissuer = MachineGenerated())
                                    end
                                    return true
                                else
                                    # need to allocate a router port and a transmission module and mode
                                end
                            end
                        end
                    end
                end
            end
        end
    # for different paths
    ## find src router port
    elseif !isnothing(transmissionmodulecompat)
    # no router port
    # no transmission module and mode
        transmissionmodulecompat = gettransmissionmodulecompat(opticalinitiateconstraint)
    end

    # find router ports


    # find oxc configuration
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
    constraints = getconstraints(intent)

    # start algorthim
    sourcelocalnode = getlocalnode(sourceglobalnode)
    destlocalnode = getlocalnode(destinationglobalnode)
    yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, getweights(ibnag), kspffalg.k)

    # if not OpticalInitiate
    sourcenodeview = getnodeview(ibnag, sourcelocalnode)
    sourceavailtransmdlidxs = getavailabletransmissionmoduleviewindex(sourcenodeview)
    sourcetransmissionmoduleviewpool = gettransmissionmoduleviewpool(sourcenodeview)

    # if not OpticalTerminate
    destnodeview = getnodeview(ibnag, destlocalnode)
    destavailtransmdlidxs = getavailabletransmissionmoduleviewindex(destnodeview)
    desttransmissionmoduleviewpool = gettransmissionmoduleviewpool(destnodeview)
    # try out all paths
    for (dist, path) in zip(yenstate.dists, yenstate.paths)
        for sourceavailtransmdlidx in sourceavailtransmdlidxs
            sourcetransmissionmodule = sourcetransmissionmoduleviewpool[sourceavailtransmdlidx]
            sourcetransmodeidx = getlowestratetransmissionmode(sourcetransmissionmodule, demandrate, dist)
            if !isnothing(sourcetransmodeidx)
                sourcetransmode = gettransmissionmode(sourcetransmissionmodule, sourcetransmodeidx)
                demandslotsneeded = getspectrumslotsneeded(sourcetransmode)
                transmoderate = getrate(sourcetransmode)
                transmodulename = getname(sourcetransmissionmodule)
                # found a transmission module with a transmission mode for source

                # is it available on the destination node ?
                transmissionmodulecompat = TransmissionModuleCompatibility(transmoderate, demandslotsneeded, transmodulename)
                destavailtransmdlmodeidx = getfirstcompatibletransmoduleidxandmodeidx(desttransmissionmoduleviewpool, destavailtransmdlidxs, transmissionmodulecompat)
                if !isnothing(destavailtransmdlmodeidx)
                    destavailtransmdlidx, desttransmodeidx = destavailtransmdlmodeidx[1], destavailtransmdlmodeidx[2] 
                    desttransmissionmodule = desttransmissionmoduleviewpool[destavailtransmdlidx]
                    desttransmode = gettransmissionmode(desttransmissionmodule, desttransmodeidx)

                    # found a transmission module with a transmission mode for source and destination
                    sourcetransmissionmodulelli = TransmissionModuleLLI(sourcelocalnode, sourceavailtransmdlidx, sourcetransmodeidx)
                    desttransmissionmodulelli = TransmissionModuleLLI(destlocalnode, destavailtransmdlidx, desttransmodeidx)

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
                                sourceadddropport = getfirstavailableoxcadddropport(sourcenodeview)
                                destadddropport = getfirstavailableoxcadddropport(destnodeview)
                                if !isnothing(sourceadddropport) && !isnothing(destadddropport)
                                    oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(path, startingslot:(startingslot + demandslotsneeded - 1); sourceadddropport, destadddropport)
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
