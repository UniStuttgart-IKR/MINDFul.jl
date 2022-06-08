### A Pluto.jl notebook ###
# v0.19.5

using Markdown
using InteractiveUtils

# ╔═╡ 3a888dca-4b70-4edd-a2c0-3896eb22c493
using Pkg; Pkg.activate(".")

# ╔═╡ adf0e85c-b4d8-11ec-16ec-132ce68b0b0e
using Revise

# ╔═╡ d81a46f9-f9ab-4e3e-998c-dc7447c79531
begin
	using Chain, Parameters
	using Test
	using Graphs, MetaGraphs, NetworkLayout
	using EzXML, GraphIO
	using IBNFramework
	using CompositeGraphs
	using TestSetExtensions
	using GraphMakie
	using Logging
	using WGLMakie
end

# ╔═╡ 822d0620-0f86-46e9-9145-eadcb581e0e9
using PlutoUI, D3Trees

# ╔═╡ 5eff8477-a61b-444f-a0bd-6fddf32154aa
using GraphMakie: plot_controlpoints!

# ╔═╡ a057e3d2-f3ce-4d61-98fc-1b03e97b7c30
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

# ╔═╡ 64452559-0692-4dcb-b54f-8007e12eb3b8
begin
	globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
	globalnet = simgraph(globalnet)
end


# ╔═╡ 233fb4c2-e844-42da-bad5-ee702287567a
myibns = compositeGraph2IBNs!(globalnet)

# ╔═╡ 844534b2-ab28-4405-be3a-5debfa8541db
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1],myibns, layout=IBNFramework.coordlayout, curve_distance=0.2)
	f
end

# ╔═╡ 3a2e6829-df5a-4fd5-8c51-7d67398fc619
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1], myibns[1], layout=IBNFramework.coordlayout, curve_distance=0.2, subnetwork_view=true)
	ibnplot(f[1,2], myibns[2], layout=IBNFramework.coordlayout, curve_distance=0.2, subnetwork_view=true)
	ibnplot(f[2,2], myibns[3], layout=IBNFramework.coordlayout, curve_distance=0.2, subnetwork_view=true)
	f
end

# ╔═╡ b1f27467-5df6-4c96-b709-c2fc23df3541
myibns[1].cgr.vmap[10]

# ╔═╡ 69636ed7-163a-4628-9747-a5ffcba64321
getid(myibns[1].controllers[3])

# ╔═╡ 6d425122-6772-45c5-a255-40a367273a86


# ╔═╡ e07bee89-0479-4751-8f10-bc85f04f9e72
md"# IBN Framework Progress
1. Developed proof-of-concept methodology for ConnectivityIntents
2. Intra-IBN, Inter-IBN, Intra-SDN, Inter-SDN intent deployment
3. Worked towards an `IBNFramework` methodology interface
4. Intent Tree partial automatization
5. Effort on visualization methods"

# ╔═╡ 1e932ffd-ee78-4c82-b661-5cc3ae20b522
md"# IBNConnectivityIntent
- Untill now we had only `ConnectivityIntents` connecting 2 nodes.
- `IBNConnectivityIntent` connects a node with an IBN domain.
- Essentially `IBNConnectivityIntent` finds a path between a specific node and a cross-node leading to the desired IBN domain."

# ╔═╡ 582c7895-700a-4aae-aecb-3ef636903450
let
	conint = IBNConnectivityIntent((myibns[1].id,4), myibns[2].id, [CapacityConstraint(5)])
	intidx = addintent!(myibns[1], conint)
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
	f=IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
	(intidx,f)
end


# ╔═╡ 334665f2-cd2a-4b01-be40-cd22a7883d42
myibns[1].intents[1].data

# ╔═╡ 8b535f02-2391-4e30-b9be-38e2bf55a198
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1],myibns[1], layout=IBNFramework.coordlayout, show_routers=true, show_links=true, curve_distance=0.3, intentidx=1)
	f
end

# ╔═╡ b4f4f85c-9d68-4317-a745-3f4054d02469
md"# SimpleIBNModus"

# ╔═╡ 0237859c-9e2a-4958-a934-2b729c686109
let
	simpleibnmodgr = SimpleGraph(3); add_edge!(simpleibnmodgr, 1, 2); add_edge!(simpleibnmodgr, 2, 3)
	f,a,p = graphplot(simpleibnmodgr; layout=SquareGrid(cols=3, dy=-0.5),
		nlabels=["uncompiled", "compiled", "installed"], 
		nlabels_align=(:center,:top), 
		elabels=["docompile","doinstall"],
		edge_color=:green,
		elabels_color=:green,
		arrow_show=true,
		arrow_size=20,
		elabels_distance=20)
	hidedecorations!(a); hidespines!(a);
	f
end

# ╔═╡ 61e019ef-d450-4565-879a-3a9b7becc0ba
md"# Methodology kshortestpath
There are 2 cases for a methodology IBN methodology:
- Interdomain version
- Intradomain version
(*kshortestpath* for between domain and cross-node is considred intradomain)

## kshortestpath(Intradomain)
1. Finds the k-shortestpaths between source node and destination node.
2. And applies the first one that is available.

## kshortestpath(Interdomain)
```
if (I the IBN do not participate in the Intent)
	forward the intent
else 
	create an IBNConnectivity intent between my domain and another one
 	compile the IBNConnectivityIntent
  	produce a concrete ConnectivityIntent for the fellow domains
end
```
## kshortestpath for IBNConnectivityIntent
1. find all shortest paths connecting the concrete node with the possible cross-nodes
2. sort them according to a metric (distane length)
3. take first that is available"

# ╔═╡ 2a86e619-ede4-4fbf-a4b2-8c42b180be7a
md"# Demo"

# ╔═╡ a680f922-ac71-4f2c-ad44-ef82f96d4f90
md"### across the same node. must be false"

# ╔═╡ f18daef5-0555-4e5b-953e-efb47143a3a9
# across the same node. must be false
let
	conint = ConnectivityIntent((myibns[1].id,4), (myibns[1].id,4), [CapacityConstraint(5)])
	intidx = addintent!(myibns[1], conint)
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
end


# ╔═╡ 2be92e6a-6d73-49a1-8669-48ce2d15517c
md"### intra SDN, intra IBN intent"

# ╔═╡ 2a042c49-73b7-437d-89fd-89616b073aa3
        # intra SDN, intra IBN intent
let
	conint = ConnectivityIntent((myibns[1].id,1), (myibns[1].id,3), [CapacityConstraint(5)]);
	intidx = addintent!(myibns[1], conint);
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!);
	success = IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization);
	(intidx, success)
end


# ╔═╡ 27afca4e-5a09-466c-9e77-9abcbd1c570e
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1],myibns[1], layout=IBNFramework.coordlayout, show_routers=true, show_links=true, curve_distance=0.3, intentidx=3)
	f
end

# ╔═╡ 653aea0d-1f3d-4176-ac7e-12b1c7328a5a
md"### inter SDN, intra IBN intent"

# ╔═╡ 04b2d1ed-bbe8-49e6-a6d4-1b5fa616c749
# inter SDN, intra IBN intent
let
	conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
	intidx = addintent!(myibns[1], conint);
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!);
	f=IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization);
	(intidx,f)
end


# ╔═╡ df5dfe5e-08e1-4b6f-a2e2-be951634e72a
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1], myibns[1], layout=IBNFramework.coordlayout, show_routers=true, show_links=true, curve_distance=0.3, intentidx=4)
	f
end

# ╔═╡ 9449d34f-b805-4e2a-8bf0-c54bf158ad95
md"### inter IBN Intent: src the IBN, destination known"

# ╔═╡ b1168e5f-ede2-4bd0-a144-cd8b89ca13be
let
	conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,3), [CapacityConstraint(5)])
	intidx = addintent!(myibns[1], conint)
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
	f=IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
	(f, intidx)
end


# ╔═╡ dfc3982e-3da2-41d1-a085-ff4d1c4f9f3f
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1], myibns[1:2], intentidx=5,layout=IBNFramework.coordlayout, show_routers=true, show_links=false, curve_distance=0.5)
	f
end

# ╔═╡ eb15c9fd-8a18-4062-bd5a-77ced26f58af
with_terminal() do
print_tree_extended(myibns[1].intents[5])
end

# ╔═╡ d8d53d27-e41d-46a3-9a80-09ca582f08a9
D3Tree(IBNFramework.ExtendedIntentTree(myibns[1], 5), svg_height=300)

# ╔═╡ ca459f61-bef2-458e-9aa8-cbf1aa5db361
myibns[2].intentissuers[1]

# ╔═╡ 2326b8b9-b812-4087-9c6c-ede534e0461e
md"### inter IBN Intent: src the IBN, destination unknown"

# ╔═╡ 1ccdda82-057f-436d-8ba5-542aaf134239
let
	conint = ConnectivityIntent((myibns[1].id,1), (myibns[3].id,1), [CapacityConstraint(5)]);
	intidx = addintent!(myibns[1], conint);
	IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!);
	f=IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization);
	(intidx,f)
end


# ╔═╡ 0f338b1a-29a9-47bb-a8ce-9f020657f74b
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1], myibns[1:3], intentidx=6,layout=IBNFramework.coordlayout, show_routers=false, show_links=false)
	f
end

# ╔═╡ 92a80526-77f1-40a3-966f-2354c561a67c
D3Tree(IBNFramework.ExtendedIntentTree(myibns[1], 6), svg_height=400)

# ╔═╡ a7f81724-4b81-423d-94e8-009943836640
md"### inter IBN Intent: src known, destination known (passing through)"

# ╔═╡ e59b414b-ac7f-4d88-8e88-194ccca53f04
let
	conint = ConnectivityIntent((myibns[1].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
	intidx = addintent!(myibns[2], conint)
	IBNFramework.deploy!(myibns[2],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
	f=IBNFramework.deploy!(myibns[2],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
	(intidx,f)
end


# ╔═╡ 7ef6171a-1cc5-4253-8a21-033045a2e217
let
	f= Figure(resolution=(2000,1000))
	ibnplot(f[1,1], myibns[[2,1,3]], intentidx=3,layout=IBNFramework.coordlayout, show_routers=false, show_links=false)
	f
end

# ╔═╡ c8a1f62a-c6b1-423e-87c4-86175d688591
t = D3Tree(IBNFramework.ExtendedIntentTree(myibns[2], 3), svg_height=400)

# ╔═╡ c9b63408-0224-4dd1-8796-33111f8c3f07
md"# IBNFramework Plan
The short term plans for the IBNFramework:
## 1. Check if intents are satisfied
Important because it's part of the **intent lifetime**
- Now there is not a detailed enough resource view:
  - Ports
  - Capacity
- Intents not strictly bounded with available resources
- Create a simple but more concrete resources scheme
  - Router ports
  - Frequency slots
  - ...
- Bind each intent to specific resources.
- Enforce single resource allocation

## 2. Work on the state machine
- Uninstall intents
- Recompile intents
- Decompile intents ?
- Propagate changes throughout the intent tree (Observable)

## 3. Resource collision detection
- Upon an invalid compilation throw a collision event
- Handle the collision event according to the compilation methodology given.
- Integrate that as to the method interface of IBNFramework

## 4. Simulate a multi layer network
- Now the network works on a full electrical layer
- Introduce architecture model of ITG-2022 paper:
    - CDC ROADMs (subset of network nodes)
    - Transmission modules (Pluggables or Transponders)
    - Router line cards

## 5. Invest on visualization
- Invest time in visualization infrastructure for easy intepretability

## 6. Network faults
- Network faults is a major use case in IBN

## 7. Event-based simulation
- Still not a requirement
- Enables big scale and generic simulations
- Need to wrap the `IBNFramework` package around the Event-based simulation library
"

# ╔═╡ b850abdf-0f8f-425b-94dd-80208f872d39
md"# IBN Research Plan
Last meeting we identified 3 research directions:
- Towards an Intent architecture
  - Intent state machine
  - Intent types
  - IBN intent permissions
  - Monitoring Methodologies (collision detection)
- Towards methodologies
  - Resource Allocation Methodologies
    - Shortest-path proo-of-concept
    - Heuristics
      - A*
      - K shortest path with adapting weights
      - Simulated Annealing
    - ILP
    - RL
  - Partial Knoweledge Modeling
    - Bayesian Inference
- Towards integration with ONOS
   - Interface IBNFramework with ONOS

# Papers
First try a conference proof-on-concept paper and then focus more on the above 3 aspects that could give more papers"

# ╔═╡ 7ccc9791-f0db-4f32-8e78-0904601c3729
md"# ECOC Paper
Effort and thoughts on writing a proof-of-concept paper for ECOC 2022 (deadline May 10)

## Paper idea:
*The importance of a common intent-based Networking North-Bound Interface in multi domain Networks*

Introduce the problem of multi domain coordination:
- network operator responsibility is hard to track
- end-to-end QoS assurance is problematic
- protocol approach can be too strict or too loose
- inter SDN case requires the construction of a management layer on top

Stretch a solution by using common IBN-NBIs:
- a step towards automatization
  - IBNs can talk to one another, rather network operators
- domain interoperability my using the already management layer of IBN
- Network operators are still free to implement their own methodologies
- Tracking and monitoring intents is accountability

Paper objective:
- provide a view of what common IBN-NBI means for multidomain metro/core networks
- provide a minimilstic Intent architecture and how this is enough for orchestration
  - Intent State machine (Installed, Compiled, Uncompiled)
  - Intent permissions
- provide a proof-of-concept scenario to showcase interoperability
- stimulate the interest around the field of IBN-NBI standardization


## What needs to be done
- Advancements on the IBNFramework
- Develop an easy proof-of-concept methodology
- showcase end-to-end QoS guarantee and responsibilities
- Some more literature research
"

# ╔═╡ Cell order:
# ╠═adf0e85c-b4d8-11ec-16ec-132ce68b0b0e
# ╠═3a888dca-4b70-4edd-a2c0-3896eb22c493
# ╠═d81a46f9-f9ab-4e3e-998c-dc7447c79531
# ╠═822d0620-0f86-46e9-9145-eadcb581e0e9
# ╠═5eff8477-a61b-444f-a0bd-6fddf32154aa
# ╠═a057e3d2-f3ce-4d61-98fc-1b03e97b7c30
# ╠═64452559-0692-4dcb-b54f-8007e12eb3b8
# ╠═233fb4c2-e844-42da-bad5-ee702287567a
# ╠═844534b2-ab28-4405-be3a-5debfa8541db
# ╠═3a2e6829-df5a-4fd5-8c51-7d67398fc619
# ╠═b1f27467-5df6-4c96-b709-c2fc23df3541
# ╠═69636ed7-163a-4628-9747-a5ffcba64321
# ╠═6d425122-6772-45c5-a255-40a367273a86
# ╟─e07bee89-0479-4751-8f10-bc85f04f9e72
# ╟─1e932ffd-ee78-4c82-b661-5cc3ae20b522
# ╠═582c7895-700a-4aae-aecb-3ef636903450
# ╠═334665f2-cd2a-4b01-be40-cd22a7883d42
# ╠═8b535f02-2391-4e30-b9be-38e2bf55a198
# ╟─b4f4f85c-9d68-4317-a745-3f4054d02469
# ╟─0237859c-9e2a-4958-a934-2b729c686109
# ╟─61e019ef-d450-4565-879a-3a9b7becc0ba
# ╟─2a86e619-ede4-4fbf-a4b2-8c42b180be7a
# ╟─a680f922-ac71-4f2c-ad44-ef82f96d4f90
# ╠═f18daef5-0555-4e5b-953e-efb47143a3a9
# ╟─2be92e6a-6d73-49a1-8669-48ce2d15517c
# ╠═2a042c49-73b7-437d-89fd-89616b073aa3
# ╠═27afca4e-5a09-466c-9e77-9abcbd1c570e
# ╟─653aea0d-1f3d-4176-ac7e-12b1c7328a5a
# ╠═04b2d1ed-bbe8-49e6-a6d4-1b5fa616c749
# ╠═df5dfe5e-08e1-4b6f-a2e2-be951634e72a
# ╠═9449d34f-b805-4e2a-8bf0-c54bf158ad95
# ╠═b1168e5f-ede2-4bd0-a144-cd8b89ca13be
# ╠═dfc3982e-3da2-41d1-a085-ff4d1c4f9f3f
# ╠═eb15c9fd-8a18-4062-bd5a-77ced26f58af
# ╠═d8d53d27-e41d-46a3-9a80-09ca582f08a9
# ╠═ca459f61-bef2-458e-9aa8-cbf1aa5db361
# ╠═2326b8b9-b812-4087-9c6c-ede534e0461e
# ╠═1ccdda82-057f-436d-8ba5-542aaf134239
# ╠═0f338b1a-29a9-47bb-a8ce-9f020657f74b
# ╠═92a80526-77f1-40a3-966f-2354c561a67c
# ╠═a7f81724-4b81-423d-94e8-009943836640
# ╠═e59b414b-ac7f-4d88-8e88-194ccca53f04
# ╠═7ef6171a-1cc5-4253-8a21-033045a2e217
# ╠═c8a1f62a-c6b1-423e-87c4-86175d688591
# ╟─c9b63408-0224-4dd1-8796-33111f8c3f07
# ╟─b850abdf-0f8f-425b-94dd-80208f872d39
# ╟─7ccc9791-f0db-4f32-8e78-0904601c3729
