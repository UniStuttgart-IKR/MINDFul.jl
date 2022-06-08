# IBNFramework
A full stack IBN Framework.
It is envisioned to work flexibly with several SDN controllers (e.g. ONOS, ODL), once the appropriate interfaces are built.

For testing purposes and easier research on algorithms a dummy SDN controller is provided to connect with simulated network resources (`SimNetResou.jl`)
For the initial purpose of the package only the simulated network will be developed.

# Multi Domains
A basic priority of the package is to consider multi-domain networks with partial knowledge.

# Modularity
The package is built in a way to allow experimentation with different algorithms and dynamic relationships between the domains.

# SimNetResou
represtens the PHY layer of a simulated network

# Encorporating network faults
Uses event-based simulation for network fauls
Bind with Reactive.jl

# TODOs

## Priority
- when intent is being realized in another IBN the Compilation should be `RemoteCompilation` or similar [WIP]
- Intent is installed only if all kids are installed (use Observable?)
- Intent is fulfilled only if all kids are fulfilled

## General
- write tests
- introduce entity types (nodes, global nodes, local nodes, domain)
- implement network faults
- port details
- port level faults ?
- asychronous/sychronous information propagation from data layer to management layer
- each IBN could be a different task
- partial knowledge of a graph 

# Guidelines
When adding a new intent:

When adding a new solution to an intent:

When adding a new constraint:
- define how is it satisfied for all relevant intents (issatisfied)
- define if constraint propagates in a specific way (adjustNpropagate_constraints!, getcompliantintent)

When adding new permissions:

When changing the intent state machine:
- use a different `IBNMode`
