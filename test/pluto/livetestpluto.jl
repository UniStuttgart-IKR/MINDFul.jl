### A Pluto.jl notebook ###
# v0.19.5

using Markdown
using InteractiveUtils

# ╔═╡ b0da29c2-9eab-11ec-2a08-9327ac3d88f3
using Pkg; Pkg.activate(".")

# ╔═╡ 0f63346f-c9f3-4faa-a79f-a3563b11bca7
using Revise

# ╔═╡ be5aa2a0-32a0-4193-9aae-6cf8a83d0a66
begin
	using Graphs, MetaGraphs, NetworkLayout
	using EzXML, GraphIO
	using IBNFramework
	using GraphMakie
	using CairoMakie
	using NestedGraphs
end

# ╔═╡ d95a1c89-b634-4184-84b4-b8a8d6eb72fc
using PlutoUI

# ╔═╡ b92cad09-5cde-452c-a667-e01fc7ceb7ed
md"### The network file in `.graphml` format"

# ╔═╡ 85aa8796-f7ec-4dfb-8473-12c8b3a61ec3
md"
```xml
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\" 
	xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
	xsi:schemaLocation=\"http://graphml.graphdrawing.org/xmlns
	 http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd\">
	<key attr.name=\"ycoord\" attr.type=\"double\" for=\"node\" id=\"ycoord\" />
	<key attr.name=\"xcoord\" attr.type=\"double\" for=\"node\" id=\"xcoord\" />
	<key attr.name=\"routerports\" attr.type=\"int\" for=\"node\" id=\"ports\" />
    <key attr.name=\"linkcapacity\" attr.type=\"int\" for=\"edge\" id=\"capacity\">
        <default>100</default>
    </key>
    <graph id=\"global-network\" edgedefault=\"directed\">
        <node id=\"ibn1\">
            <graph id=\"ibn1\" edgedefault=\"directed\">
                <node id=\"ibn1:sdn1\">
                    <graph id=\"ibn1:sdn1\" edgedefault=\"directed\">
                        <node id=\"ibn1:sdn1:N1\">
                            <data key=\"xcoord\">0.0</data>
                            <data key=\"ycoord\">0.0</data>
                            <data key=\"ports\">11</data>
                        </node>
                        <node id=\"ibn1:sdn1:N2\">
                            <data key=\"xcoord\">4.0</data>
                            <data key=\"ycoord\">5.0</data>
                            <data key=\"ports\">12</data>
                        </node>
                        <node id=\"ibn1:sdn1:N3\">
                            <data key=\"xcoord\">10.0</data>
                            <data key=\"ycoord\">-2.0</data>
                            <data key=\"ports\">13</data>
                        </node>
                        <node id=\"ibn1:sdn1:N4\">
                            <data key=\"xcoord\">5.0</data>
                            <data key=\"ycoord\">-10.0</data>
                            <data key=\"ports\">14</data>
                        </node>
                        <edge id=\"ibn1:sdn2:N1-ibn1:sdn2:N2\" source=\"ibn1:sdn1:N1\" target=\"ibn1:sdn1:N2\"/>
                        <edge id=\"ibn1:sdn2:N2-ibn1:sdn2:N1\" source=\"ibn1:sdn1:N2\" target=\"ibn1:sdn1:N1\"/>

                        <edge id=\"ibn1:sdn2:N2-ibn1:sdn2:N3\" source=\"ibn1:sdn1:N2\" target=\"ibn1:sdn1:N3\"/>
                        <edge id=\"ibn1:sdn2:N3-ibn1:sdn2:N2\" source=\"ibn1:sdn1:N3\" target=\"ibn1:sdn1:N2\"/>

                        <edge id=\"ibn1:sdn2:N1-ibn1:sdn2:N4\" source=\"ibn1:sdn1:N1\" target=\"ibn1:sdn1:N4\"/>
                        <edge id=\"ibn1:sdn2:N4-ibn1:sdn2:N1\" source=\"ibn1:sdn1:N4\" target=\"ibn1:sdn1:N1\"/>

                        <edge id=\"ibn1:sdn2:N2-ibn1:sdn2:N4\" source=\"ibn1:sdn1:N2\" target=\"ibn1:sdn1:N4\"/>
                        <edge id=\"ibn1:sdn2:N4-ibn1:sdn2:N2\" source=\"ibn1:sdn1:N4\" target=\"ibn1:sdn1:N2\"/>

                        <edge id=\"ibn1:sdn2:N3-ibn1:sdn2:N4\" source=\"ibn1:sdn1:N3\" target=\"ibn1:sdn1:N4\"/>
                        <edge id=\"ibn1:sdn2:N4-ibn1:sdn2:N3\" source=\"ibn1:sdn1:N4\" target=\"ibn1:sdn1:N3\"/>
                    </graph>
                </node>
                <node id=\"ibn1:sdn2\">
                    <graph id=\"ibn1:sdn2\" edgedefault=\"directed\">
                        <node id=\"ibn1:sdn2:N1\">
                            <data key=\"xcoord\">15.0</data>
                            <data key=\"ycoord\">2.0</data>
                            <data key=\"ports\">21</data>
                        </node>
                        <node id=\"ibn1:sdn2:N2\">
                            <data key=\"xcoord\">20.0</data>
                            <data key=\"ycoord\">7.0</data>
                            <data key=\"ports\">22</data>
                        </node>
                        <node id=\"ibn1:sdn2:N3\">
                            <data key=\"xcoord\">18.5</data>
                            <data key=\"ycoord\">-2.0</data>
                            <data key=\"ports\">23</data>
                        </node>
                        <node id=\"ibn1:sdn2:N4\">
                            <data key=\"xcoord\">16.0</data>
                            <data key=\"ycoord\">-12.0</data>
                            <data key=\"ports\">24</data>
                        </node>
                        <node id=\"ibn1:sdn2:N5\">
                            <data key=\"xcoord\">22.0</data>
                            <data key=\"ycoord\">-10.0</data>
                            <data key=\"ports\">25</data>
                        </node>
                        <edge id=\"ibn1:sdn2:N1-ibn1:sdn2:N2\" source=\"ibn1:sdn2:N1\" target=\"ibn1:sdn2:N2\"/>
                        <edge id=\"ibn1:sdn2:N2-ibn1:sdn2:N1\" source=\"ibn1:sdn2:N2\" target=\"ibn1:sdn2:N1\"/>

                        <edge id=\"ibn1:sdn2:N2-ibn1:sdn2:N3\" source=\"ibn1:sdn2:N2\" target=\"ibn1:sdn2:N3\"/>
                        <edge id=\"ibn1:sdn2:N3-ibn1:sdn2:N2\" source=\"ibn1:sdn2:N3\" target=\"ibn1:sdn2:N2\"/>

                        <edge id=\"ibn1:sdn2:N1-ibn1:sdn2:N4\" source=\"ibn1:sdn2:N1\" target=\"ibn1:sdn2:N4\"/>
                        <edge id=\"ibn1:sdn2:N4-ibn1:sdn2:N1\" source=\"ibn1:sdn2:N4\" target=\"ibn1:sdn2:N1\"/>

                        <edge id=\"ibn1:sdn2:N3-ibn1:sdn2:N4\" source=\"ibn1:sdn2:N3\" target=\"ibn1:sdn2:N4\"/>
                        <edge id=\"ibn1:sdn2:N4-ibn1:sdn2:N3\" source=\"ibn1:sdn2:N4\" target=\"ibn1:sdn2:N3\"/>

                        <edge id=\"ibn1:sdn2:N3-ibn1:sdn2:N5\" source=\"ibn1:sdn2:N3\" target=\"ibn1:sdn2:N5\"/>
                        <edge id=\"ibn1:sdn2:N5-ibn1:sdn2:N3\" source=\"ibn1:sdn2:N5\" target=\"ibn1:sdn2:N3\"/>

                        <edge id=\"ibn1:sdn2:N4-ibn1:sdn2:N5\" source=\"ibn1:sdn2:N4\" target=\"ibn1:sdn2:N5\"/>
                        <edge id=\"ibn1:sdn2:N5-ibn1:sdn2:N4\" source=\"ibn1:sdn2:N5\" target=\"ibn1:sdn2:N4\"/>
                    </graph>
                </node>
                <edge id=\"ibn1:sdn1:N3-ibn1:sdn2:N1\" source=\"ibn1:sdn1:N3\" target=\"ibn1:sdn2:N1\"/>
                <edge id=\"ibn1:sdn2:N1-ibn1:sdn1:N3\" source=\"ibn1:sdn2:N1\" target=\"ibn1:sdn1:N3\"/>

                <edge id=\"ibn1:sdn1:N4-ibn1:sdn2:N4\" source=\"ibn1:sdn1:N4\" target=\"ibn1:sdn2:N4\"/>
                <edge id=\"ibn1:sdn2:N4-ibn1:sdn1:N4\" source=\"ibn1:sdn2:N4\" target=\"ibn1:sdn1:N4\"/>
            </graph>
        </node>
        <node id=\"ibn2\">
            <graph id=\"ibn2\" edgedefault=\"directed\">
                <node id=\"ibn2:sdn1\">
                    <graph id=\"ibn2-sdn1\" edgedefault=\"directed\">
                        <node id=\"ibn2:sdn1:N1\">
                            <data key=\"xcoord\">30.0</data>
                            <data key=\"ycoord\">2.0</data>
                            <data key=\"ports\">31</data>
                        </node>
                        <node id=\"ibn2:sdn1:N2\">
                            <data key=\"xcoord\">32.0</data>
                            <data key=\"ycoord\">-5.0</data>
                            <data key=\"ports\">32</data>
                        </node>
                        <node id=\"ibn2:sdn1:N3\">
                            <data key=\"xcoord\">35.5</data>
                            <data key=\"ycoord\">-2.0</data>
                            <data key=\"ports\">33</data>
                        </node>
                        <node id=\"ibn2:sdn1:N4\">
                            <data key=\"xcoord\">35.0</data>
                            <data key=\"ycoord\">-12.0</data>
                            <data key=\"ports\">34</data>
                        </node>
                        <edge id=\"ibn2:sdn1:N1-ibn2:sdn1:N2\" source=\"ibn2:sdn1:N1\" target=\"ibn2:sdn1:N2\"/>
                        <edge id=\"ibn2:sdn1:N2-ibn2:sdn1:N1\" source=\"ibn2:sdn1:N2\" target=\"ibn2:sdn1:N1\"/>

                        <edge id=\"ibn2:sdn1:N1-ibn2:sdn1:N3\" source=\"ibn2:sdn1:N1\" target=\"ibn2:sdn1:N3\"/>
                        <edge id=\"ibn2:sdn1:N3-ibn2:sdn1:N1\" source=\"ibn2:sdn1:N3\" target=\"ibn2:sdn1:N1\"/>

                        <edge id=\"ibn2:sdn1:N2-ibn2:sdn1:N3\" source=\"ibn2:sdn1:N2\" target=\"ibn2:sdn1:N3\"/>
                        <edge id=\"ibn2:sdn1:N3-ibn2:sdn1:N2\" source=\"ibn2:sdn1:N3\" target=\"ibn2:sdn1:N2\"/>

                        <edge id=\"ibn2:sdn1:N2-ibn2:sdn1:N4\" source=\"ibn2:sdn1:N2\" target=\"ibn2:sdn1:N4\"/>
                        <edge id=\"ibn2:sdn1:N4-ibn2:sdn1:N2\" source=\"ibn2:sdn1:N4\" target=\"ibn2:sdn1:N2\"/>

                        <edge id=\"ibn2:sdn1:N3-ibn2:sdn1:N4\" source=\"ibn2:sdn1:N3\" target=\"ibn2:sdn1:N4\"/>
                        <edge id=\"ibn2:sdn1:N4-ibn2:sdn1:N3\" source=\"ibn2:sdn1:N4\" target=\"ibn2:sdn1:N3\"/>
                    </graph>
                </node>
                <node id=\"ibn2:sdn2\">
                    <graph id=\"ibn2:sdn2\" edgedefault=\"directed\">
                        <node id=\"ibn2:sdn2:N1\">
                            <data key=\"xcoord\">39.0</data>
                            <data key=\"ycoord\">-3.0</data>
                            <data key=\"ports\">41</data>
                        </node>
                        <node id=\"ibn2:sdn2:N2\">
                            <data key=\"xcoord\">42.0</data>
                            <data key=\"ycoord\">-5.0</data>
                            <data key=\"ports\">42</data>
                        </node>
                        <node id=\"ibn2:sdn2:N3\">
                            <data key=\"xcoord\">40.0</data>
                            <data key=\"ycoord\">-11.0</data>
                            <data key=\"ports\">43</data>
                        </node>
                        <edge id=\"ibn2:sdn2:N1-ibn2:sdn2:N2\" source=\"ibn2:sdn2:N1\" target=\"ibn2:sdn2:N2\"/>
                        <edge id=\"ibn2:sdn2:N2-ibn2:sdn2:N1\" source=\"ibn2:sdn2:N2\" target=\"ibn2:sdn2:N1\"/>

                        <edge id=\"ibn2:sdn2:N1-ibn2:sdn2:N3\" source=\"ibn2:sdn2:N1\" target=\"ibn2:sdn2:N3\"/>
                        <edge id=\"ibn2:sdn2:N3-ibn2:sdn2:N1\" source=\"ibn2:sdn2:N3\" target=\"ibn2:sdn2:N1\"/>

                        <edge id=\"ibn2:sdn2:N2-ibn2:sdn2:N3\" source=\"ibn2:sdn2:N2\" target=\"ibn2:sdn2:N3\"/>
                        <edge id=\"ibn2:sdn2:N3-ibn2:sdn2:N2\" source=\"ibn2:sdn2:N3\" target=\"ibn2:sdn2:N2\"/>
                    </graph>
                </node>
                <edge id=\"ibn2:sdn1:N3-ibn2:sdn2:N1\" source=\"ibn2:sdn1:N3\" target=\"ibn2:sdn2:N1\"/>
                <edge id=\"ibn2:sdn2:N1-ibn2:sdn1:N3\" source=\"ibn2:sdn2:N1\" target=\"ibn2:sdn1:N3\"/>

                <edge id=\"ibn2:sdn1:N4-ibn2:sdn2:N3\" source=\"ibn2:sdn1:N4\" target=\"ibn2:sdn2:N3\"/>
                <edge id=\"ibn2:sdn2:N3-ibn2:sdn1:N4\" source=\"ibn2:sdn2:N3\" target=\"ibn2:sdn1:N4\"/>
            </graph>
        </node>
        <node id=\"ibn3\">
            <graph id=\"ibn3\" edgedefault=\"directed\">
                <node id=\"ibn3:sdn1\">
                    <graph id=\"ibn3:sdn1\" edgedefault=\"directed\">
                        <node id=\"ibn3:sdn1:N1\">
                            <data key=\"xcoord\">28.0</data>
                            <data key=\"ycoord\">-24.0</data>
                            <data key=\"ports\">51</data>
                        </node>
                        <node id=\"ibn3:sdn1:N2\">
                            <data key=\"xcoord\">27.0</data>
                            <data key=\"ycoord\">-26.0</data>
                            <data key=\"ports\">52</data>
                        </node>
                        <node id=\"ibn3:sdn1:N3\">
                            <data key=\"xcoord\">29.0</data>
                            <data key=\"ycoord\">-25.0</data>
                            <data key=\"ports\">53</data>
                        </node>
                        <edge id=\"ibn3:sdn1:N1-ibn3:sdn1:N2\" source=\"ibn3:sdn1:N1\" target=\"ibn3:sdn1:N2\"/>
                        <edge id=\"ibn3:sdn1:N2-ibn3:sdn1:N1\" source=\"ibn3:sdn1:N2\" target=\"ibn3:sdn1:N1\"/>

                        <edge id=\"ibn3:sdn1:N1-ibn3:sdn1:N3\" source=\"ibn3:sdn1:N1\" target=\"ibn3:sdn1:N3\"/>
                        <edge id=\"ibn3:sdn1:N3-ibn3:sdn1:N1\" source=\"ibn3:sdn1:N3\" target=\"ibn3:sdn1:N1\"/>

                        <edge id=\"ibn3:sdn1:N2-ibn3:sdn1:N3\" source=\"ibn3:sdn1:N2\" target=\"ibn3:sdn1:N3\"/>
                        <edge id=\"ibn3:sdn1:N3-ibn3:sdn1:N2\" source=\"ibn3:sdn1:N3\" target=\"ibn3:sdn1:N2\"/>
                    </graph>
                </node>
                <node id=\"ibn3:sdn2\">
                    <graph id=\"ibn3:sdn2\" edgedefault=\"directed\">
                        <node id=\"ibn3:sdn2:N1\">
                            <data key=\"xcoord\">34.0</data>
                            <data key=\"ycoord\">-23.0</data>
                            <data key=\"ports\">61</data>
                        </node>
                        <node id=\"ibn3:sdn2:N2\">
                            <data key=\"xcoord\">35.0</data>
                            <data key=\"ycoord\">-26.0</data>
                            <data key=\"ports\">62</data>
                        </node>
                        <node id=\"ibn3:sdn2:N3\">
                            <data key=\"xcoord\">40.0</data>
                            <data key=\"ycoord\">-24.0</data>
                            <data key=\"ports\">63</data>
                        </node>
                        <node id=\"ibn3:sdn2:N4\">
                            <data key=\"xcoord\">40.0</data>
                            <data key=\"ycoord\">-20.0</data>
                            <data key=\"ports\">63</data>
                        </node>
                        <edge id=\"ibn3:sdn2:N1-ibn3:sdn2:N2\" source=\"ibn3:sdn2:N1\" target=\"ibn3:sdn2:N2\"/>
                        <edge id=\"ibn3:sdn2:N2-ibn3:sdn2:N1\" source=\"ibn3:sdn2:N2\" target=\"ibn3:sdn2:N1\"/>

                        <edge id=\"ibn3:sdn2:N1-ibn3:sdn2:N3\" source=\"ibn3:sdn2:N1\" target=\"ibn3:sdn2:N3\"/>
                        <edge id=\"ibn3:sdn2:N3-ibn3:sdn2:N1\" source=\"ibn3:sdn2:N3\" target=\"ibn3:sdn2:N1\"/>

                        <edge id=\"ibn3:sdn2:N2-ibn3:sdn2:N3\" source=\"ibn3:sdn2:N2\" target=\"ibn3:sdn2:N3\"/>
                        <edge id=\"ibn3:sdn2:N3-ibn3:sdn2:N2\" source=\"ibn3:sdn2:N3\" target=\"ibn3:sdn2:N2\"/>

                        <edge id=\"ibn3:sdn2:N1-ibn3:sdn2:N4\" source=\"ibn3:sdn2:N1\" target=\"ibn3:sdn2:N4\"/>
                        <edge id=\"ibn3:sdn2:N4-ibn3:sdn2:N1\" source=\"ibn3:sdn2:N4\" target=\"ibn3:sdn2:N1\"/>

                        <edge id=\"ibn3:sdn2:N3-ibn3:sdn2:N4\" source=\"ibn3:sdn2:N3\" target=\"ibn3:sdn2:N4\"/>
                        <edge id=\"ibn3:sdn2:N4-ibn3:sdn2:N3\" source=\"ibn3:sdn2:N4\" target=\"ibn3:sdn2:N3\"/>
                    </graph>
                </node>
                <edge id=\"ibn3:sdn1:N1-ibn3:sdn2:N1\" source=\"ibn3:sdn1:N1\" target=\"ibn3:sdn2:N1\"/>
                <edge id=\"ibn3:sdn2:N1-ibn3:sdn1:N1\" source=\"ibn3:sdn2:N1\" target=\"ibn3:sdn1:N1\"/>

                <edge id=\"ibn3:sdn1:N3-ibn3:sdn2:N1\" source=\"ibn3:sdn1:N3\" target=\"ibn3:sdn2:N1\"/>
                <edge id=\"ibn3:sdn2:N1-ibn3:sdn1:N3\" source=\"ibn3:sdn2:N1\" target=\"ibn3:sdn1:N3\"/>

                <edge id=\"ibn3:sdn1:N3-ibn3:sdn2:N2\" source=\"ibn3:sdn1:N3\" target=\"ibn3:sdn2:N2\"/>
                <edge id=\"ibn3:sdn2:N2-ibn3:sdn1:N3\" source=\"ibn3:sdn2:N2\" target=\"ibn3:sdn1:N3\"/>
            </graph>
        </node>
        <edge id=\"ibn1:sdn2:N2-ibn2:sdn1:N1\" source=\"ibn1:sdn2:N2\" target=\"ibn2:sdn1:N1\"/>
        <edge id=\"ibn2:sdn1:N1-ibn1:sdn2:N2\" source=\"ibn2:sdn1:N1\" target=\"ibn1:sdn2:N2\"/>

        <edge id=\"ibn1:sdn2:N5-ibn2:sdn1:N2\" source=\"ibn1:sdn2:N5\" target=\"ibn2:sdn1:N2\"/>
        <edge id=\"ibn2:sdn1:N2-ibn1:sdn2:N5\" source=\"ibn2:sdn1:N2\" target=\"ibn1:sdn2:N5\"/>

        <edge id=\"ibn2:sdn1:N4-ibn3:sdn2:N1\" source=\"ibn2:sdn1:N4\" target=\"ibn3:sdn2:N1\"/>
        <edge id=\"ibn3:sdn2:N1-ibn2:sdn1:N4\" source=\"ibn3:sdn2:N1\" target=\"ibn2:sdn1:N4\"/>

        <edge id=\"ibn2:sdn2:N3-ibn3:sdn2:N4\" source=\"ibn2:sdn2:N3\" target=\"ibn3:sdn2:N4\"/>
        <edge id=\"ibn3:sdn2:N4-ibn2:sdn2:N3\" source=\"ibn3:sdn2:N4\" target=\"ibn2:sdn2:N3\"/>
    </graph>
</graphml>
```
"

# ╔═╡ 77ecd4fb-60d5-46b0-8e7a-b29a73d0bee7
md"## Reading the `graphml` file as a `NestedGraph`"

# ╔═╡ c210bd2c-4dab-4ec8-a67b-1dd9613c25e8
globalnet = loadgraph(open("../data/networksnest.graphml"), GraphMLFormat(), NestedGraphs.NestedGraphFormat())

# ╔═╡ 65d9f7b7-93c4-434e-a9a2-cd539961c5e1
NestedGraphs.cgraphplot(globalnet)

# ╔═╡ fbc8c422-af17-46ba-8991-ca7b6ecc2bd9
md"### Converting it to optical network graph and to IBNs"

# ╔═╡ ead508db-4ab1-4817-8210-179bdc9ee97c
md"Converting it to a optical network graph"

# ╔═╡ 9ce228f3-1bb5-43f6-90ff-18dc4573436d
globalnetsim = IBNFramework.simgraph(globalnet)

# ╔═╡ 019656e7-1a8d-4efc-99be-bdc2d27ff577
NestedGraphs.cgraphplot(globalnetsim, layout=IBNFramework.coordlayout, 
	nlabels=repr.(globalnetsim.vmap))

# ╔═╡ 5a5cb38f-9ce4-4c82-8de6-0c1ab39e1765
md"Converting it to IBNs"

# ╔═╡ 7eaeb91a-6466-4194-acd7-30d317987c03
myibns = IBNFramework.nestedGraph2IBNs!(globalnetsim)

# ╔═╡ a81d1de4-70bc-4e5f-90f4-04fb3845e325
md"IBN 1"

# ╔═╡ 09e623b2-cc63-41bc-b382-024917328f17
IBNFramework.ibnplot(myibns[1], subnetwork_view=false, layout=IBNFramework.coordlayout, 
	axis=(title="IBN1", limits = (nothing, 36, nothing, nothing)))

# ╔═╡ e2d11e46-4304-4c72-8ee8-293592a76e24
IBNFramework.ibnplot(myibns[2], subnetwork_view=true,
	layout=IBNFramework.coordlayout, 
	axis=(title="IBN2", limits = (nothing, 45, nothing, nothing)))

# ╔═╡ 082075a2-4626-4a9d-aff2-c683350c30f9
IBNFramework.ibnplot(myibns[3], subnetwork_view=true,
	layout=IBNFramework.coordlayout, 
	axis=(title="IBN3", limits = (nothing, 43, nothing, nothing)))

# ╔═╡ fd4b9846-4e3c-4295-82ac-530cd7885615
md"### intra SDN, intra IBN intent"

# ╔═╡ e6724f48-e140-4aae-8188-542c1a0dd7b5
begin 
	conint1 = ConnectivityIntent((myibns[1].id,1), (myibns[1].id,3), [CapacityConstraint(25)])
	intidx1 = addintent(myibns[1], conint1)
	IBNFramework.step!(myibns[1],intidx1, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())
end


# ╔═╡ a1bd8d4f-b0c1-4dd3-9ee2-c3456eb1e7f6
md"### inter SDN, intra IBN intent"

# ╔═╡ c35dc450-7cf3-4bf4-b250-cf2af79cbff3
begin
	conint2 = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(15)])
	intidx2 = addintent(myibns[1], conint2)
	s2 = IBNFramework.step!(myibns[1],intidx2, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())
	
end

# ╔═╡ 1cb01270-bbdf-43d7-aec2-4bb4a263e640
md"### inter SDN, inter IBN intent (WIP)"

# ╔═╡ 8db1580d-d94a-46c7-b94c-c7fbdf08978a
begin
	conint3 = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,3), [CapacityConstraint(15)])
	intidx3 = addintent(myibns[1], conint3)
	s3 = IBNFramework.step!(myibns[1],intidx3, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())
	
end

# ╔═╡ b4143533-0f5c-48d5-ae1f-733f5126c4cb
begin
	fig = Figure(resolution=(1000,1000))
	IBNFramework.ibnplot(fig[1,1],myibns[1], layout=IBNFramework.coordlayout,
	show_links=true, show_routers=true,
	curve_distance_usage = false, elabels_rotation=nothing,
	axis=(title="IBN1 resource allocations", limits = (nothing, 35, nothing, nothing)))
	fig
end

# ╔═╡ bcd59a69-4f21-4f0a-a6ed-e2770c608faf
getfield.(myibns[1].intents, :data)

# ╔═╡ 581e1b2d-19ed-4391-a64f-f9fb4f917dfa
myibns[1]

# ╔═╡ 14a2ea48-3299-4af0-a8ac-ceec9a39775c
myibns[1].cgr.flatgr

# ╔═╡ f684b147-d211-4d0e-8a38-9e47310d9d9a
myibns[1].cgr.grv

# ╔═╡ 8faf476c-4e2f-44f2-841a-d5a3a14bc4a2
myibns[1].cgr.vmap

# ╔═╡ 9d1de2df-ab62-4d98-9968-57cbe18d05d4
myibns[1].cgr.ceds

# ╔═╡ ae250b96-e5a1-4212-b747-a02e8c86df0e
md"## Demonstrate Intent Tree functionality (manually)"

# ╔═╡ 64cd6e01-3e0a-4026-9229-62d83c146ae3
md"The root intent"

# ╔═╡ 7f74e0f7-c218-41cd-a772-e9fece87814d
intent13 = ConnectivityIntent((myibns[1].id,2), (myibns[3].id,1), [CapacityConstraint(50)])

# ╔═╡ 119c2172-8320-49f7-9a5e-0399aba02dbd
md"Creating the Intent Tree"

# ╔═╡ 1c4ed4ac-dc11-43ad-8c4d-12d399a2ce6d
intree = IntentTree(intent13)

# ╔═╡ 8acd7bb7-afb9-40a3-ba80-d71b63baf7b1
md"The intents to be provisioned recursively"

# ╔═╡ b6f8ae29-666b-4436-933a-ee21e5667b50
begin
	intent12 = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,1), [CapacityConstraint(50)])
	intent23 = ConnectivityIntent((myibns[2].id,1), (myibns[3].id,1), [CapacityConstraint(50)])
end

# ╔═╡ 5effca2b-256a-4738-865e-479c7984de19
md"Add the intents to the tree"

# ╔═╡ ddd22f79-a199-4f89-a0f8-58d0d1cddc63
begin 
	IBNFramework.addchild!(intree, intent12)
	IBNFramework.addchild!(intree, intent23)
end

# ╔═╡ 315ef037-bb11-4a0c-a29f-1146d6d3afea
md"Root Intent depends on the children"

# ╔═╡ 1283cc5a-fda4-4958-a402-1d336e8ba466
IBNFramework.setcompilation!(intree, IBNFramework.InheritIntentCompilation())

# ╔═╡ dbef7a78-3c9a-478e-a702-b303555ec9d4
md"First child intent is handled internalyl in the IBN"

# ╔═╡ 76dec0fa-b465-4561-83d5-a213e0dcbc03
IBNFramework.setcompilation!(intree.children[1], IBNFramework.ConnectivityIntentCompilation([2,3,4,5,6,10], 50))

# ╔═╡ 1b7c7812-1ec2-4785-b176-21ee45e35819
md"Second child intent is an external one"

# ╔═╡ c00de4ac-3de5-42d9-9b58-62a4d173d1b9
IBNFramework.setcompilation!(intree.children[2], IBNFramework.RemoteIntentCompilation())

# ╔═╡ 4880903c-41e4-4923-ae2c-95a44e3030b4
md"When child intents appear both as `InstalledIntent`, then the root intent can also be labeld as installed"

# ╔═╡ 8470b675-a959-4585-9a87-32908802385d
IBNFramework.setstate!(intree.children[1], IBNFramework.InstalledIntent())

# ╔═╡ e1377d29-9670-4c12-9e21-d7549e71f24a
IBNFramework.setstate!(intree.children[2], IBNFramework.InstalledIntent())

# ╔═╡ 6ff336b8-bc87-45b1-85c1-1588c5477bbe
if all(x -> x isa IBNFramework.InstalledIntent ,IBNFramework.state.(intree.children))
	IBNFramework.setstate!(intree, IBNFramework.InstalledIntent())
end

# ╔═╡ 353c3448-a855-49a2-a16a-0429cc78c6e8
with_terminal() do
	print_tree(intree)
end

# ╔═╡ 8c341b6b-a224-4763-89c2-26288e5b06a1
[intree.data, intree.children[1].data, intree.children[2].data]

# ╔═╡ 0f30ec75-19b2-41a9-940f-8bb4d8c27426
md"## Sum up"

# ╔═╡ 4954447e-8abf-4346-ba51-dd8863706bf2
md"The basic implementation is there:
- NestedGraphs functionality
- reproducability & easy scenario modifications with `graphml` format
- Intent Tree to store intents in IBN
- intra IBN inter SDN intent provision"

# ╔═╡ 5afa144f-6fe8-4b2f-8408-559e748beea5
md"Future work that needs to be done:
- inter IBN intent provision
- Intent Tree callbacks
- deeper optical model
  - spectrum
  - OXCs
  - optical transceivers
  - amplifiers (?)
- network faults"

# ╔═╡ 5164bc99-f054-4c9b-9f1f-35c79e0c0e21
md"The future directions include
- concentrate on Intent architectures
  - State machines
  - Intent types
  - IBN intent permissions
  - monitoring
- work on the methodologies
  - Heuristics
  - Reinforcement Learning
  - ILP
  - Bayesian Approach (?)
- integrate with ONOS
  - IBNs must be able to speak to SDNs like ONOS
  - the same interface to speak to `SDNdummy` and `SDNonos`"

# ╔═╡ Cell order:
# ╠═b0da29c2-9eab-11ec-2a08-9327ac3d88f3
# ╠═0f63346f-c9f3-4faa-a79f-a3563b11bca7
# ╠═be5aa2a0-32a0-4193-9aae-6cf8a83d0a66
# ╠═d95a1c89-b634-4184-84b4-b8a8d6eb72fc
# ╟─b92cad09-5cde-452c-a667-e01fc7ceb7ed
# ╟─85aa8796-f7ec-4dfb-8473-12c8b3a61ec3
# ╟─77ecd4fb-60d5-46b0-8e7a-b29a73d0bee7
# ╠═c210bd2c-4dab-4ec8-a67b-1dd9613c25e8
# ╠═65d9f7b7-93c4-434e-a9a2-cd539961c5e1
# ╠═fbc8c422-af17-46ba-8991-ca7b6ecc2bd9
# ╟─ead508db-4ab1-4817-8210-179bdc9ee97c
# ╠═9ce228f3-1bb5-43f6-90ff-18dc4573436d
# ╠═019656e7-1a8d-4efc-99be-bdc2d27ff577
# ╟─5a5cb38f-9ce4-4c82-8de6-0c1ab39e1765
# ╠═7eaeb91a-6466-4194-acd7-30d317987c03
# ╟─a81d1de4-70bc-4e5f-90f4-04fb3845e325
# ╠═09e623b2-cc63-41bc-b382-024917328f17
# ╠═e2d11e46-4304-4c72-8ee8-293592a76e24
# ╠═082075a2-4626-4a9d-aff2-c683350c30f9
# ╟─fd4b9846-4e3c-4295-82ac-530cd7885615
# ╠═e6724f48-e140-4aae-8188-542c1a0dd7b5
# ╟─a1bd8d4f-b0c1-4dd3-9ee2-c3456eb1e7f6
# ╠═c35dc450-7cf3-4bf4-b250-cf2af79cbff3
# ╟─1cb01270-bbdf-43d7-aec2-4bb4a263e640
# ╠═8db1580d-d94a-46c7-b94c-c7fbdf08978a
# ╠═b4143533-0f5c-48d5-ae1f-733f5126c4cb
# ╠═bcd59a69-4f21-4f0a-a6ed-e2770c608faf
# ╠═581e1b2d-19ed-4391-a64f-f9fb4f917dfa
# ╠═14a2ea48-3299-4af0-a8ac-ceec9a39775c
# ╠═f684b147-d211-4d0e-8a38-9e47310d9d9a
# ╠═8faf476c-4e2f-44f2-841a-d5a3a14bc4a2
# ╠═9d1de2df-ab62-4d98-9968-57cbe18d05d4
# ╟─ae250b96-e5a1-4212-b747-a02e8c86df0e
# ╟─64cd6e01-3e0a-4026-9229-62d83c146ae3
# ╠═7f74e0f7-c218-41cd-a772-e9fece87814d
# ╟─119c2172-8320-49f7-9a5e-0399aba02dbd
# ╟─1c4ed4ac-dc11-43ad-8c4d-12d399a2ce6d
# ╟─8acd7bb7-afb9-40a3-ba80-d71b63baf7b1
# ╟─b6f8ae29-666b-4436-933a-ee21e5667b50
# ╟─5effca2b-256a-4738-865e-479c7984de19
# ╠═ddd22f79-a199-4f89-a0f8-58d0d1cddc63
# ╟─315ef037-bb11-4a0c-a29f-1146d6d3afea
# ╠═1283cc5a-fda4-4958-a402-1d336e8ba466
# ╟─dbef7a78-3c9a-478e-a702-b303555ec9d4
# ╠═76dec0fa-b465-4561-83d5-a213e0dcbc03
# ╟─1b7c7812-1ec2-4785-b176-21ee45e35819
# ╠═c00de4ac-3de5-42d9-9b58-62a4d173d1b9
# ╟─4880903c-41e4-4923-ae2c-95a44e3030b4
# ╠═8470b675-a959-4585-9a87-32908802385d
# ╠═e1377d29-9670-4c12-9e21-d7549e71f24a
# ╠═6ff336b8-bc87-45b1-85c1-1588c5477bbe
# ╠═353c3448-a855-49a2-a16a-0429cc78c6e8
# ╠═8c341b6b-a224-4763-89c2-26288e5b06a1
# ╟─0f30ec75-19b2-41a9-940f-8bb4d8c27426
# ╟─4954447e-8abf-4346-ba51-dd8863706bf2
# ╟─5afa144f-6fe8-4b2f-8408-559e748beea5
# ╟─5164bc99-f054-4c9b-9f1f-35c79e0c0e21
