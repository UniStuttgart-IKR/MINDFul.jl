using Makie
using GraphMakie
import Colors

isvvi(x::Vector{Vector{T}}) where T = all(i -> i isa Integer, Iterators.flatten(x))
isvvi(j) = false

struct DummyPlotIBN{R,T}
    cgr::CompositeGraph{R,T}
end

function coordlayout(gr::AbstractGraph, xcoord::Symbol=:xcoord, ycoord::Symbol=:ycoord)
    try 
        xs = [[get_prop(gr, v, xcoord), get_prop(gr,v, ycoord)] for v in vertices(gr)]
        return [Point(x...) for x in xs ]
    catch e
        return NetworkLayout.spring(gr)
    end
end

@recipe(IBNPlot, ibn) do scene
    Attributes(
        show_routers = false,
        show_links = false,
        subnetwork_view = false,
        color_paths_obs = nothing,
        color_paths = nothing,
        color_edges = nothing,
        intentidx = nothing
    )
end

function nodelabel(cgr::CompositeGraph, v::Integer, show_router=false, subnetwork_view=false) 
    nodelabs = subnetwork_view ? string(cgr.vmap[v]) : string(v)
    noderouter = string()
    if show_router
        if has_prop(cgr, v, :router)
            noderouter = string(get_prop(cgr, v, :router).rezports, "/",get_prop(cgr, v, :router).nports)
        else
            noderouter = "?"
        end
    end
    isempty(noderouter) ? nodelabs : nodelabs * "," * noderouter
end

function edgelabel(cgr::CompositeGraph, e::Edge, show_links=false)
    edgelabs = show_links ? string(get_prop(cgr, e, :link).rezcapacity,"/",get_prop(cgr, e, :link).capacity) : string()
end

function Makie.plot!(ibnp::IBNPlot)
    ibn = ibnp[:ibn]
    nodelabels = @lift [nodelabel($(ibn).cgr, v, $(ibnp.show_routers), $(ibnp.subnetwork_view)) for v in vertices($(ibn).cgr)]
    edgelabels = @lift [edgelabel($(ibn).cgr, e, $(ibnp.show_links)) for e in edges($(ibn).cgr)]

    edgecolors = @lift begin
        if isvvi($(ibnp.color_paths_obs))
            distcolors = Colors.distinguishable_colors(length($(ibnp.color_paths_obs)) + 3, [Colors.RGB(1,1,1), Colors.RGB(0,0,0)])[2:end]
            edgcs = fill(distcolors[1], ne($(ibn).cgr))
            for (ie,e) in enumerate(edges($(ibn).cgr))
                for (ip,path) in enumerate($(ibnp.color_paths_obs))
                    if e in edgeify(path)
                        edgcs[ie] = distcolors[ip+1]
                    end
                end
            end
            return edgcs
        end
        return :black
    end
    CompositeGraphs.cgraphplot!(ibnp, ibnp[:ibn][].cgr; 
                                merge((nlabels=nodelabels, elabels=edgelabels, edge_color=edgecolors),
                                      NamedTuple(Makie.attributes_from(CompositeGraphs.CGraphPlot, ibnp)), 
                                      NamedTuple(Makie.attributes_from(GraphMakie.GraphPlot, ibnp)))...)

    #TODO with observable
    edps = ibnp.plots[1].plots[1].edge_paths[]
    lwd = ibnp.plots[1].plots[1].edge_width[]

    
    colorpaths = Vector{Vector}()
    if isvvi(ibnp.color_paths[])
        for path in ibnp.color_paths[]
            idxs = find_edge_index.([ibn[].cgr],edgeify(path))
            push!(colorpaths, edps[broadcast(in, 1:end, [idxs])])
        end
    elseif ibnp.intentidx[] != nothing
        concomps = [filter(x -> x isa ConnectivityIntentCompilation, getcompilation.(family(ibn[], idx; intraibn=false, ibnidfilter=getid(ibn[])))) for idx in ibnp.intentidx[]]
        pathsperint = [getfield.(concomp, :path) for concomp in concomps]
        for paths in pathsperint
            cpaths = [let
                          idxs = find_edge_index.([ibn[].cgr],edgeify(path));
                          edps[broadcast(in, 1:end, [idxs])]
                      end
                      for path in paths]
            push!(colorpaths, cpaths...)
        end
    elseif ibnp.color_edges[] != nothing
        for edges in ibnp.color_edges[]
            idxs = find_edge_index.([ibn[].cgr],edges)
            push!(colorpaths, edps[broadcast(in, 1:end, [idxs])])
        end
    end
    for (i,colorpath) in enumerate(colorpaths)
        distcolors = Colors.distinguishable_colors(length(colorpaths) + 3, [Colors.RGB(1,1,1), Colors.RGB(0,0,0)])[3:end]
        GraphMakie.edgeplot!(ibnp, colorpath, linewidth=lwd[]*5 ,color=(distcolors[i],0.5))
    end


    return ibnp
end

function Makie.plot!(ibnp::IBNPlot{<:Tuple{Vector{IBN{R,T}}}}) where {R,T}
    distcolors = Colors.distinguishable_colors(length(ibnp[1][]))
    ibnplot!(ibnp, ibnp[1][][1]; node_color=distcolors[1], node_invis=transnodes(ibnp[1][][1], subnetwork_view=false), ibnp.attributes...)
    ibnplot!(ibnp, ibnp[1][][2]; node_color=distcolors[2], node_invis=transnodes(ibnp[1][][2], subnetwork_view=false), ibnp.attributes...)
    ibnplot!(ibnp, ibnp[1][][3]; node_color=distcolors[3], node_invis=transnodes(ibnp[1][][3], subnetwork_view=false), ibnp.attributes...)
    return ibnp
end

"""
Plot intent on all IBNs given.
Intent index is based on the first element of the IBNs given
"""
function Makie.plot!(ibnp::IBNPlot{<:Tuple{Vector{IBN{R,T}}, <:Integer}}) where {R,T}
    distcolors = Colors.distinguishable_colors(length(ibnp[1][]))
    intentidx = ibnp[2][]
    divint = dividefamily(ibnp[1][][1], intentidx)

    paths1 = haskey(divint,getid(ibnp[1][][1])) ? edgeify(divint[getid(ibnp[1][][1])], ConnectivityIntentCompilation) : nothing
    ibnplot!(ibnp, ibnp[1][][1]; ibnp.attributes..., color_edges=paths1, node_color=distcolors[1], node_invis=transnodes(ibnp[1][][1], subnetwork_view=false))


    paths2 = haskey(divint,getid(ibnp[1][][2])) ? edgeify(divint[getid(ibnp[1][][2])], ConnectivityIntentCompilation) : nothing
    ibnplot!(ibnp, ibnp[1][][2]; ibnp.attributes..., color_edges=paths2, node_color=distcolors[2], node_invis=transnodes(ibnp[1][][2], subnetwork_view=false))

    paths3 = haskey(divint,getid(ibnp[1][][3])) ? edgeify(divint[getid(ibnp[1][][3])], ConnectivityIntentCompilation) : nothing
    ibnplot!(ibnp, ibnp[1][][3]; ibnp.attributes..., color_edges=paths3, node_color=distcolors[3], node_invis=transnodes(ibnp[1][][3], subnetwork_view=false))
    return ibnp
end

getlegendplots(ibnp::IBNPlot) = return ibnp.plots[2:end]

"""
Create legend with (e.g.)
```
Legend(f[1,1], IBNFramework.getlegendplots(p), ["Intent5","Intent3"], tellheight=false, tellwidth=false, halign=:right)
```
"""
function find_edge_index(gr::AbstractGraph, e::Edge)
    findfirst(==(e), collect(edges(gr)))
end
