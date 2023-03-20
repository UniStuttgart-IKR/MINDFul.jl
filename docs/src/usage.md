# Usage and Examples

To see all functionalities head to the [API](@ref) documentation.
You can find some example notebooks in [this repository](https://github.com/UniStuttgart-IKR/MINDFulNotebookExamples.jl).

## Indexing nodes, edges, intents, and domains
As we deal with multi-domain scenarios with partial knowledge, it becomes obvious that there cannot be 
a single way to identify a node or edge since some nodes are not visible from outside a domain.
However, an internal node might be needed to be addressed by external parties due to an intent statement.
This leads to different indexing schemes that must be directed for intra-domain and inter-domain usage.

In `MINDFul.jl`, we follow the example of [`Graphs.jl`](https://github.com/JuliaGraphs/Graphs.jl) 
and we index nodes as a sequence of `Integer`s.

### Intra-domain indexing
The indexing of nodes for intra-domain usage is done just by a sequence of `NODE_ID::Integer` numbers.
This means that the edges are defined as `Edge(src::Integer, dst::Integer)`.

### Controller-level indexing
Intra-domain might not be so "intra".
With the term `intra-domain` network, we refer to a network that has centralized control and belongs to one entity, i.e., network operator.
However, this does not stop the network operator from logically separating the network.
This could be done by having different SDN controllers responsible for different areas.
Since the SDN controllers have partial knowledge of the network, a different indexing scheme is needed.
So the same node, indexed before with a single `Integer` number, can now also be indexed with a `Tuple{::Integer, ::Integer}`.
The first element of the `Tuple` is the id of the controller responsible for this node,
and the second element is the local indexing of this node in the controller.
In other words, a node can also be addressed as `(CONTROLLER_ID, NODE_ID_IN_CONTROLLER)`.
The `CONTROLLER_ID` might not always belong to an SDN controller as we might either have a stack of IBN framework instances,
or the referenced node is a border node, i.e., belongs to a different domain, 
and then the IBN framework instance of the neighbor domain must be referenced.

To express this structure programmatically, we make use of 
the [`NestedGraphs.jl`](https://github.com/UniStuttgart-IKR/NestedGraphs.jl) package, where nodes
are defined with a `Tuple` and edges with a `NestedEdge` where `src` and `dst` are `Tuple{::Integer, Integer}`.

### Inter-domain indexing
Scaling up the previous idea, a domain node might also be globally referenced with a Tuple {::Integer, ::Integer}.
This time the first element is the IBN domain id, and the second element is the node id inside the network as in [Intra-domain indexing](@ref).
In other words, a node can be addressed as `(DOMAIN_ID, NODE_ID)`.
The higher stacked IBN framework instance id is used to identify the domain.
An edge can also be addressed globally with a `NestedEdge`.

### Intents indexing
An intent can be globally indexed with a `Tuple{::Integer, ::UUID}`, i.e., `(DOMAIN_ID, INTENT_ID)`.
All (compiled) intents in a IBN domain are part of a DAG (Directed Acyclic Graph).
You can access the DAG of an `ibn::IBN` with the `ibn.intents` field.
