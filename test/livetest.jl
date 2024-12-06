using MINDFul
using JLD2, AttributeGraphs, Graphs

const MINDF = MINDFul

ag4nets = JLD2.load("../data/attributegraphs4nets.jld2")

ag1 = MINDF.IBNAttributeGraph(ag4nets["ags"][1])
