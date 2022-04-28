using Makie
using GraphMakie
using NetworkLayout
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
                                merge((nlabels=nodelabels, elabels=edgelabels, edge_color=edgecolors, layout=coordlayout),
                                      NamedTuple(Makie.attributes_from(CompositeGraphs.CGraphPlot, ibnp)), 
                                      NamedTuple(Makie.attributes_from(GraphMakie.GraphPlot, ibnp)))...)

    #TODO with observable
    gmp = ibnp.plots[1].plots[1]
    edps = gmp.edge_paths[]
    lwd = gmp.edge_width[]
    ns = gmp.node_size[]

    
    colorpaths = Vector{Vector}()
    scatternodes = Vector{Vector}()
    if isvvi(ibnp.color_paths[])
        for path in ibnp.color_paths[]
            idxs = find_edge_index.([ibn[].cgr],edgeify(path))
            push!(colorpaths, edps[broadcast(in, 1:end, [idxs])])
        end
    elseif ibnp.intentidx[] != nothing
#        concomps = [filter(x -> x isa ConnectivityIntentCompilation, getcompilation.(family(ibn[], idx; intraibn=false, ibnidfilter=getid(ibn[])))) for idx in ibnp.intentidx[]]
#        pathsperint = [getfield.(concomp, :path) for concomp in concomps]
#        for paths in pathsperint
#            cpaths = [let
#                          idxs = find_edge_index.([ibn[].cgr],edgeify(path));
#                          edps[broadcast(in, 1:end, [idxs])]
#                      end
#                      for path in paths]
#            push!(colorpaths, cpaths...)
#        end
        dag = ibn[].intents[ibnp.intentidx[]]
        idnllis = filter(x -> x isa LowLevelIntent, getfield.(getleafs(dag),:intent))
        noderouterintents = filter(x -> x isa NodeRouterIntent, getfield.(getleafs(dag),:intent))
        push!(scatternodes, getfield.(noderouterintents, :node))
        nodespectrumintents = filter(x -> x isa NodeSpectrumIntent, getfield.(getleafs(dag),:intent))
        cedges = getfield.(nodespectrumintents, :edge)
        idxs = find_edge_index.([ibn[].cgr],cedges)
        push!(colorpaths, edps[broadcast(in, 1:end, [idxs])])
    elseif ibnp.color_edges[] != nothing
        for cedges in ibnp.color_edges[]
            idxs = find_edge_index.([ibn[].cgr],cedges)
            push!(colorpaths, edps[broadcast(in, 1:end, [idxs])])
        end
    end
    for (i,colorpath) in enumerate(colorpaths)
        distcolors = Colors.distinguishable_colors(length(colorpaths) + 3, [Colors.RGB(1,1,1), Colors.RGB(0,0,0)])[3:end]
        GraphMakie.edgeplot!(ibnp, colorpath, linewidth=lwd[]*5 ,color=(distcolors[i],0.3))
    end
    for (i,scattnod) in enumerate(scatternodes)
        distcolors = Colors.distinguishable_colors(length(scatternodes) + 3, [Colors.RGB(1,1,1), Colors.RGB(0,0,0)])[3:end]
        scatter!(ibnp, gmp.node_pos[][scattnod], markersize=gmp.node_size[]*3, 
                 strokecolor=distcolors[i], strokewidth=2, color=(:black, 0.0))
    end


    return ibnp
end

function Makie.plot!(ibnp::IBNPlot{<:Tuple{Vector{IBN{R}}}}) where {R}
    distcolors = Colors.distinguishable_colors(length(ibnp[1][]))
    if ibnp.intentidx[] != nothing
        divint = dividefamily(ibnp[1][][1], ibnp.intentidx[])
    end
    for (i,ibn) in enumerate(ibnp[1][])
        if ibnp.intentidx[] != nothing
            paths = haskey(divint,getid(ibn)) ? edgeify(divint[getid(ibn)], ConnectivityIntentCompilation) : nothing
            ibnplot!(ibnp, ibn; ibnp.attributes..., color_edges=paths, node_color=distcolors[i], node_invis=transnodes(ibn, subnetwork_view=false), intentidx=nothing)
        else
            ibnplot!(ibnp, ibn; ibnp.attributes..., node_color=distcolors[i], node_invis=transnodes(ibn, subnetwork_view=false))
        end
    end
    return ibnp
end

getlegendplots(ibnp::IBNPlot) = return ibnp.plots[2:end]

"Plots the `idx`st intent of `ibn`"
@recipe(IntentPlot, ibn, idx) do scene
    Attributes(
               interdomain = false,
               show_state = true,
    )
end

function Makie.plot!(intplot::IntentPlot)
    ibn = intplot[:ibn]
    idx = intplot[:idx]

    dag = ibn[].intents[idx[]]
    if intplot.show_state[] == false
        labs = [dagtext(dag[MGN.label_for(dag,v)].intent) for v in  vertices(dag)]
    else 
        labs = [let dagnode=dag[MGN.label_for(dag,v)]; dagtext(dagnode.intent)*"\nstate=$(dagnode.state)"; end for v in  vertices(dag)]
    end
    labsalign = [length(outneighbors(dag, v)) == 0 ? (:center, :top) : (:center, :bottom)  for v in vertices(dag)]
    GraphMakie.graphplot!(intplot, dag, layout=NetworkLayout.Buchheim(), nlabels=labs, nlabels_align=labsalign)

    return intplot
end
"""
Create legend with (e.g.)
```
Legend(f[1,1], IBNFramework.getlegendplots(p), ["Intent5","Intent3"], tellheight=false, tellwidth=false, halign=:right)
```
"""
function find_edge_index(gr::AbstractGraph, e::Edge)
    findfirst(==(e), collect(edges(gr)))
end

struct ExtendedIntentTree{T<:Intent}
    idx::Int
    ibn::IBN
    intent::T
    parent::Union{Nothing, ExtendedIntentTree}
    children::Vector{ExtendedIntentTree}
end
AbstractTrees.printnode(io::IO, node::ExtendedIntentTree) = print(io, "IBN:$(getid(node.ibn)), IntentIdx:$(node.idx)\n$(normaltext(node.intent))")
AbstractTrees.children(node::ExtendedIntentTree) = node.children
AbstractTrees.has_children(node::ExtendedIntentTree) = length(node.children) > 0
AbstractTrees.parent(node::ExtendedIntentTree) = node.parent
AbstractTrees.isroot(node::ExtendedIntentTree) = parent(node) === nothing

function ExtendedIntentTree(ibn::IBN, intentidx::Int)
    intentr = ibn.intents[intentidx]
    eit = ExtendedIntentTree(intentidx, ibn, intentr.data, nothing, Vector{ExtendedIntentTree}())
    populatechildren!(eit, intentr)
    return eit
end

function ExtendedIntentTree(ibn::IBN, intentr::IntentDAG, parent::ExtendedIntentTree)
    eit = ExtendedIntentTree(intentr.idx, ibn, intentr.data, parent, Vector{ExtendedIntentTree}())
    populatechildren!(eit, intentr)
    return eit
end

function populatechildren!(eit::ExtendedIntentTree, intentr::IntentDAG)
    ibnchintentrs = extendedchildren(eit.ibn, intentr)
    if ibnchintentrs !== nothing
        for (chibn, chintentr) in ibnchintentrs
            push!(eit.children, ExtendedIntentTree(chibn, chintentr, eit))
        end
    end
end
