using JLD2
using Graphs
using GraphMakie
using CairoMakie

# Load the .jld2 file
file_path = TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"
data = JLD2.load(file_path)

# Inspect the structure of the loaded data
#@show data

# Extract the graph data (adjust based on the structure of your file)
domains_name_graph = first(data)[2]  # Assuming the graph data is in the second element
graph = domains_name_graph[1][2]     # Adjust indexing based on your file structure

# Create a Graph object
g = SimpleGraph(length(vertices(graph)))
for edge in edges(graph)
    add_edge!(g, src(edge), dst(edge))
end

# Visualize the graph with Makie
fig, ax, p = graphplot(g, node_size=15, edge_width=2, node_color=:blue)
fig