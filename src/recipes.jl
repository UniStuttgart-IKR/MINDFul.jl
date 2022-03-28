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
        colors = Makie.automatic,
        color_paths = nothing
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
        if isvvi($(ibnp.color_paths))
            distcolors = Colors.distinguishable_colors(length($(ibnp.color_paths)) + 3, [Colors.RGB(1,1,1), Colors.RGB(0,0,0)])[2:end]
            edgcs = fill(distcolors[1], ne($(ibn).cgr))
            for (ie,e) in enumerate(edges($(ibn).cgr))
                for (ip,path) in enumerate($(ibnp.color_paths))
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
                                      
    return ibnp
end

 "draw network w/ resources"
function draw_ibn(ibn::IBN)
    f=draw_network(ibn.cgr.flatgr, 
            nlabels = [string(v, ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
            elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)])
    f[1]
end

function draw_ibn_loc(ibn::IBN)
    f=draw_network(ibn.cgr.flatgr, layout=GraphMakieUtils.coordlayout,
            nlabels = [string(v, ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
            elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)])
    f[1]
end

"draw network intent with resources"
function draw_ibn(ibn::IBN, paths::Vector{Vector{Int}})
    f=draw_network(ibn.cgr.flatgr, 
            nlabels = [string(v, ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
            elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)], 
            paths=[IBNFramework.compilation(ibn.intents[1]).path]);f
    f[1]
end

"with initial annotation"
function draw_ibn_2(ibn::IBN)
    f =draw_network(ibn.cgr.flatgr, 
           nlabels = [string(ibn.cgr.vmap[v], ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
           elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)])
    f[1]
end

function draw_ibn_2(cgr::CompositeGraph)
    f =draw_network(cgr.flatgr, 
           nlabels = [string(cgr.vmap[v], ",", get_prop(cgr, v, :router).rezports, "/",get_prop(cgr, v, :router).nports) for v in vertices(cgr)], 
           elabels = [string(get_prop(cgr, l, :link).rezcapacity,"/",get_prop(cgr, l, :link).capacity) for l in edges(gr)])
    f[1]
end
