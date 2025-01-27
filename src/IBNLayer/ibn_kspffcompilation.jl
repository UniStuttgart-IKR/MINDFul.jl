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
function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{ConnectivityIntent}, kspffalg::KShorestPathFirstFitCompilation)
    ibnag = getibnag(ibnf)
    intent = getintent(idagnode)
    sourceglobalnode = getsourcenode(intent)
    destinationglobalnode = getdestinationnode(intent)
    demandrate = getrate(intent)

    # intra-domain 
    if getibnfid(ibnf) == getibnfid(sourceglobalnode) == getibnfid(destinationglobalnode)
        # TODO ustrip should leave
        sourcelocalnode = getnode(sourceglobalnode)
        destlocalnode = getnode(destinationglobalnode)
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
                if !iszero(transmodeidx)
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
                        if !iszero(sourcerouterindex)
                            destrouterindex = getfirstavailablerouterportindex(getrouterview(destnodeview))
                            if !iszero(destrouterindex)
                                sourcerouterportlli = RouterPortLLI(sourcelocalnode, sourcerouterindex)
                                destrouterportlli = RouterPortLLI(destlocalnode, destrouterindex)
                                @show path
                                return true

                                # find spectrum slots
                            end
                        end
                    end
                end
            end
        end

    end
    return false
end
