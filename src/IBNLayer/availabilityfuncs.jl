
"""
$(TYPEDSIGNATURES)

Return a dictionary with keys the edges and values the up and downtimes.
"""
function getdictlinkupdowntimes(ibnf; checkfirst = true, verbose::Bool = false, endtime=nothing)
    return Dict(ed => getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) for ed in edges(getibnag(ibnf)))
end

"""
$(TYPEDSIGNATURES)

Return a dictionary with keys the edges and values the empirical availabilities.
"""
function getdictlinkempiricalavailabilities(ibnf; checkfirst = true, verbose::Bool = false, endtime=nothing)
    return Dict(ed => 
                let 
                    ludts = getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) 
                    isempty(getuptimes(ludts)) ? 1.0 : sum(getuptimes(ludts)) / (sum(getdowntimes(ludts)) + sum(getuptimes(ludts)))
                end
                for ed in edges(getibnag(ibnf)))
end

"""
$(TYPEDSIGNATURES)

Return the up and downtimes for the specific link
"""
function getlinkupdowntimes(ibnf, edge; checkfirst = true, verbose::Bool = false, endtime=nothing)
    linkstates = getlinkstates(ibnf, edge; checkfirst, verbose)
    return getupdowntimes(linkstates, endtime)
end

"""
$(TYPEDSIGNATURES)
"""
function calculatepathavailability(availabilities::Vector{Float64})
    return reduce(*, availabilities)
end

"""
$(TYPEDSIGNATURES)
"""
function calculateprotectedpathavailability(p1edges::Vector{Edge{Int}}, p1avails::Vector{Float64}, p2edges::Vector{Edge{Int}}, p2avails::Vector{Float64})
    @assert length(p1edges) == length(p1avails)
    @assert length(p2edges) == length(p2avails)

    commonedges1inds = findall(ed -> ed in p2edges, p1edges)
    commonedges = p1edges[commonedges1inds]

    p1branchavail = 1.0
    p2branchavail = 1.0
    for p1i in 1:length(p1edges)
        if p1edges[p1i] ∉ commonedges
            p1branchavail *= p1avails[p1i]
        end
    end
    for p2i in 1:length(p2edges)
        if p2edges[p2i] ∉ commonedges
            p2branchavail *= p2avails[p2i]
        end
    end

    protectedpathavailability = 1 - (1 - p1branchavail) * (1 - p2branchavail)
    protectedpathavailability *= reduce(*, p1avails[commonedges1inds])

    return protectedpathavailability
end
