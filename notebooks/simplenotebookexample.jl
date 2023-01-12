### A Pluto.jl notebook ###
# v0.19.19

using Markdown
using InteractiveUtils

# ╔═╡ 442e4738-9246-11ed-18bc-3d0b1c400eca
import Pkg

# ╔═╡ 7f5da610-0fcc-4000-ae2d-55c404b95cc5
Pkg.activate(".")

# ╔═╡ 4a446235-18c2-4d82-8480-fbc4ca2eb814
using Revise

# ╔═╡ 97de85e8-6efd-4153-943f-794a003797f4
using MINDFul, GraphIO, NestedGraphsIO, NestedGraphs, Graphs, MetaGraphs

# ╔═╡ 58f3950b-114f-4a08-b14d-49f78242ea5c
using MINDFulMakie, CairoMakie, Unitful

# ╔═╡ 0949e348-477f-42eb-ad02-a4c54e5276f2
using PlutoUI

# ╔═╡ 33f1d64a-0c07-4cfd-a901-7e9a2b4adf4a
html"""
<style>
	main {
		margin: 0 auto;
		max-width: 2000px;
    	padding-left: max(160px, 10%);
    	padding-right: max(160px, 10%);
	}
</style>
"""

# ╔═╡ 9a460ae7-a468-489e-a0ff-93507a68a793
md"# Notebook example for `MINDFul.jl`"

# ╔═╡ 294ead79-e37e-4619-b192-88e9643f00cd
md"First, activate the notebooks environment"

# ╔═╡ 8fe8e74b-c5d0-4da0-8572-f43a8a6abbcd
md"Due to some unregistered and forked packages, this is currently more complicated than usual. In the future this will be addressed."

# ╔═╡ b8deb081-9c6d-4f7c-b1e1-557d2bc58e52
MINDF = MINDFul

# ╔═╡ d496ab73-643a-4e13-b460-63222392c7ab
myibns = 
let
	# read in the NestedGraph
	globalnet = open(joinpath("../data/4nets.graphml")) do io
	    loadgraph(io, "global-network", GraphMLFormat(), NestedGraphs.NestedGraphFormat())
	end
	# convert it to a NestedGraph compliant with the simulation specifications
	globalsimgraph = MINDFul.simgraph(globalnet)
	# convert it to IBNs
	myibns = MINDFul.nestedGraph2IBNs!(globalsimgraph)
end

# ╔═╡ e706ea18-3979-45de-922c-6c8abeb41555
myibns[1]

# ╔═╡ c4edef24-83f7-4813-9c6b-83d9844f08ed
let
	f,a,p  = ibnplot(myibns; axis=(title="Complete multi-domain network",))
	hidedecorations!(a)
	f
end

# ╔═╡ b445e9d2-3486-41f7-a7a7-f9e66447608b
md"The are 4 networks, each visualized with a different color. The 4 network domain operate in a decentralized fashion; that is they belong to different organizations."

# ╔═╡ 778ceea9-0b17-49d4-8b59-09fb100d18c8
let
	f = Figure()
	a,p = ibnplot(f[1,1], myibns[1]; axis=(title="myibns[1]",))
	hidedecorations!(a)
	a,p = ibnplot(f[1,2], myibns[2]; axis=(title="myibns[2]",))
	hidedecorations!(a)
	a,p = ibnplot(f[2,2], myibns[3]; axis=(title="myibns[3]",))
	hidedecorations!(a)
	a,p = ibnplot(f[2,1], myibns[4]; axis=(title="myibns[4]",))
	hidedecorations!(a)
	f
end

# ╔═╡ 007a85c3-7bf1-4b50-91c4-31b3111be181
md"Each IBN is composed by several subgraphs, visualized with different colors. The different subgraphs denote different domains inside the network. The different domains can be either SDN-separated domains or the neighboring border nodes belonging to a different network entity.

Each plot above visualizes how the 4 different network operators see the global network. As you can see there is no global knowledge and a network operator can only know the border nodes of the neighboring networks."

# ╔═╡ 1533e48b-a908-421c-a5e8-41e660ea4d95
md"The scenario is well described the following publication: 

> F. Christou, \"Decentralized Intent-driven Coordination of Multi-Domain IP-Optical Networks,\" 2022 18th International Conference on Network and Service Management (CNSM), 2022, pp. 359-363, doi: 10.23919/CNSM55787.2022.9964606.

A introduction notebook to the basic ideas can be found [here](google.com)"


# ╔═╡ 13c4807b-176b-48e6-815a-e79151fa90ef
md"In this simulation we will impersonate the network operator of `myibns[1]`"

# ╔═╡ e2381f46-e0df-4fc2-982a-04a5e13eddb0
md"## IBN"

# ╔═╡ d2a8ace9-148b-4d39-a854-f3f663272b7e
myibns[1]

# ╔═╡ ae04da87-98f9-45ad-bdbb-2b25adfb2645
md"The fields of the IBN struct are
- `id`: the unique id for the specific IBN domain
- `intents`: the registed intents
- `intentissuers`: who issued the corresponding `intent`
- `controllers`: all SDN subdomains and the neighboring domains
- `ngr`: The `NestedGraph` describing the IBN domain
- `interprops`: storing the permissions of neighboring IBN domains"

# ╔═╡ caf64cc9-1f0b-4311-91ba-af8ff318e39d
md"At first and after initialization there are no intents in the network."

# ╔═╡ 1a83766b-da55-4ee2-8dad-db86ff0efc20
md"## Intents
Intents define high-level objectives of the network operators. `MINDFul.jl` defines a handful of intents that focus on connectivity. 

We follow a tactic of further describing an intent given some *constraints*.
This paradigm is not new and is also used by frameworks like [ONOS](https://wiki.onosproject.org/display/ONOS/Intent+Framework).

Following we define a connectivity intent from the 1st node of IBN1 to the 9th node of IBN1 carrying 50 Gbps"

# ╔═╡ d95a36e4-0c72-4eac-b7ac-58cd2fe46c91
myintent = ConnectivityIntent((myibns[1].id, 1), (myibns[1].id, 9), [CapacityConstraint(50)])

# ╔═╡ 4eec91ea-9485-4302-98cd-c07ad7c77f54
md"We add this intent to the IBN framework"

# ╔═╡ f9f75535-0066-401f-8325-4f3a2044a295
idi = addintent!(myibns[1], myintent)

# ╔═╡ a22395bf-d0e8-45b1-ad33-0698d0c013b9
md"We compile the intent. To do it we need to specify the simulation time this happened. `MINDFul.jl` is developed to log all such state transitions. This functionality is especially useful for event-based simulations.

Since now we are no interested into holding an event-based simulation, we define this short function to everytime return a timestamp with a difference of 1 hour."

# ╔═╡ 1ae38bb5-fe3c-466b-8842-05da76a71331
nexttime() = MINDF.COUNTER("time")u"hr"

# ╔═╡ 0f5c3eda-fe78-49fe-9ae9-63e11f9c0171
md"!!! note

`MINDFul.COUNTER` is a `const` that is used in some parts of the package to produce a sequence of unique automatically generated `id`s. `COUNTER` counts all the times you called it by passing in a specific argument. Here we pass in the string `\"time\"`."

# ╔═╡ 903dd513-2b1a-4fd3-8794-8549ecf126ce
deploy!(myibns[1], idi, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time=nexttime());

# ╔═╡ 9a5308bc-ff2c-4589-b907-647d13850a2c
md"We can introspect the logs of the intent, yielding that at `1.0 hr` we compiled this intent"

# ╔═╡ 04540e14-d6bb-4350-92fa-77045ed0ec0c
getroot(getintent(myibns[1], idi)).logstate.logtime

# ╔═╡ bb54227a-f2ea-41a4-a8b2-c04d56d28542
md"We can inspect the compilation by displaying the intent tree. (Better use GLMakie or WGLMakie to have interactive control of the plot)"

# ╔═╡ 4683e35d-69eb-4d43-b24e-da67eeb216bd
let
	f = Figure(resolution=(2000,500))
	a = Axis(f[1, 1], yautolimitmargin = (0.6, 0.2), title="Compiled intent")
	intentplot!(a, myibns[1], idi)
	hidedecorations!(a)
	f
end

# ╔═╡ 45ce090a-6377-4824-9733-8e4f76912dc4
md"We see that the user intent is registered as the root in the Intent Tree. 
Compilation forces the Intent Tree to expand vertically by adding children to each node.
The tree leaves are called low-level intents and are actually device-level intents.
This way the abstact high-level intent is gradually conretisized through the compilation process."

# ╔═╡ 61d2072a-5689-45e4-bcfb-3c213efc703d
md"After the intent is compiled, we can install it into the network"

# ╔═╡ ad1aecd8-6ae1-4b2e-a7e2-ffa1c7463418
deploy!(myibns[1], idi, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time=nexttime());

# ╔═╡ 3670dc7c-4af4-45e7-bdbb-dd9172949d7c
md"Now all nodes in the Intent Tree will be in the `installed` state"

# ╔═╡ f2555f38-b7ab-44db-93c3-b07581139e68
let
	f = Figure(resolution=(2000,500))
	a = Axis(f[1, 1], yautolimitmargin = (0.6, 0.2), title="Compiled intent")
	intentplot!(a, myibns[1], idi)
	hidedecorations!(a)
	f
end

# ╔═╡ 95a6e312-4ea7-449d-9724-f2e6bc1be771
let
	f,a,_ = ibnplot(myibns, intentidx=idi, axis=(title="Visualization of the installed intent",))
	hidedecorations!(a)
	f
end

# ╔═╡ 92e24a68-2cbd-40b5-9491-0caea27bb4cd
md"We can do the same with cross-domain intents"

# ╔═╡ 74471fd5-fa91-4275-8870-81b74dfd09da
cidi = let 
	myintent = ConnectivityIntent((myibns[1].id, 1), (myibns[3].id, 6), [CapacityConstraint(50)])
	idi = addintent!(myibns[1], myintent)
	deploy!(myibns[1], idi, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time=nexttime());
	deploy!(myibns[1], idi, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time=nexttime());
	idi
end

# ╔═╡ d4526365-257b-41b6-b7a4-8913c67a71a3
let
	f,a,_ = ibnplot(myibns, intentidx=cidi, axis=(title="Visualization of the installed multi-domain intent",))
	hidedecorations!(a)
	f
end

# ╔═╡ c80799b9-9363-467b-aec2-3d495b1cec50
md"# Extending intent compilation strategies"

# ╔═╡ 3862b9d0-e085-4efc-9838-5bc9852b65c6
md"The objective of `MINDFul.jl` is to provide the scientific community with a flexible tool for algorithmic research in multi-domain intent-driven coordination.
Following we showcase how users can add such functionality. The interface at the moment is still rather rough and hacky; in the future it will be more friendly and standardized."

# ╔═╡ Cell order:
# ╠═33f1d64a-0c07-4cfd-a901-7e9a2b4adf4a
# ╟─9a460ae7-a468-489e-a0ff-93507a68a793
# ╟─294ead79-e37e-4619-b192-88e9643f00cd
# ╠═4a446235-18c2-4d82-8480-fbc4ca2eb814
# ╠═442e4738-9246-11ed-18bc-3d0b1c400eca
# ╠═7f5da610-0fcc-4000-ae2d-55c404b95cc5
# ╟─8fe8e74b-c5d0-4da0-8572-f43a8a6abbcd
# ╠═97de85e8-6efd-4153-943f-794a003797f4
# ╟─b8deb081-9c6d-4f7c-b1e1-557d2bc58e52
# ╠═58f3950b-114f-4a08-b14d-49f78242ea5c
# ╠═0949e348-477f-42eb-ad02-a4c54e5276f2
# ╠═d496ab73-643a-4e13-b460-63222392c7ab
# ╠═e706ea18-3979-45de-922c-6c8abeb41555
# ╟─c4edef24-83f7-4813-9c6b-83d9844f08ed
# ╟─b445e9d2-3486-41f7-a7a7-f9e66447608b
# ╟─778ceea9-0b17-49d4-8b59-09fb100d18c8
# ╟─007a85c3-7bf1-4b50-91c4-31b3111be181
# ╟─1533e48b-a908-421c-a5e8-41e660ea4d95
# ╟─13c4807b-176b-48e6-815a-e79151fa90ef
# ╟─e2381f46-e0df-4fc2-982a-04a5e13eddb0
# ╠═d2a8ace9-148b-4d39-a854-f3f663272b7e
# ╟─ae04da87-98f9-45ad-bdbb-2b25adfb2645
# ╟─caf64cc9-1f0b-4311-91ba-af8ff318e39d
# ╟─1a83766b-da55-4ee2-8dad-db86ff0efc20
# ╠═d95a36e4-0c72-4eac-b7ac-58cd2fe46c91
# ╟─4eec91ea-9485-4302-98cd-c07ad7c77f54
# ╠═f9f75535-0066-401f-8325-4f3a2044a295
# ╟─a22395bf-d0e8-45b1-ad33-0698d0c013b9
# ╠═1ae38bb5-fe3c-466b-8842-05da76a71331
# ╟─0f5c3eda-fe78-49fe-9ae9-63e11f9c0171
# ╠═903dd513-2b1a-4fd3-8794-8549ecf126ce
# ╟─9a5308bc-ff2c-4589-b907-647d13850a2c
# ╟─04540e14-d6bb-4350-92fa-77045ed0ec0c
# ╟─bb54227a-f2ea-41a4-a8b2-c04d56d28542
# ╟─4683e35d-69eb-4d43-b24e-da67eeb216bd
# ╟─45ce090a-6377-4824-9733-8e4f76912dc4
# ╟─61d2072a-5689-45e4-bcfb-3c213efc703d
# ╠═ad1aecd8-6ae1-4b2e-a7e2-ffa1c7463418
# ╟─3670dc7c-4af4-45e7-bdbb-dd9172949d7c
# ╟─f2555f38-b7ab-44db-93c3-b07581139e68
# ╠═95a6e312-4ea7-449d-9724-f2e6bc1be771
# ╠═92e24a68-2cbd-40b5-9491-0caea27bb4cd
# ╠═74471fd5-fa91-4275-8870-81b74dfd09da
# ╠═d4526365-257b-41b6-b7a4-8913c67a71a3
# ╟─c80799b9-9363-467b-aec2-3d495b1cec50
# ╠═3862b9d0-e085-4efc-9838-5bc9852b65c6
