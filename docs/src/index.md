# Welcome to MINDFul.jl

MINDFul.jl is an open-source Julia library designed to facilitate research on multi-domain Intent-Based Networking (IBN), specifically focusing on pure IP-optical networks. It fills a noticeable gap in currently available tools by providing a stateful, modular representation of common IP-optical network equipment as well as common intent operations.

Network coordination across multiple domains is a complex task requiring seamless communication between network entities. While Software-Defined Networking (SDN) allows for efficient centralized control within domains, multi-domain networking often remains decentralized. MINDFul.jl tackles this by utilizing an intent-driven approach, which offers higher flexibility of interactions and support for much wider network capabilities than traditional protocols like BGP. 

## Key Features

- **IBN-over-SDN Architecture:** Separates intent handling into its own dedicated framework, utilizing the underlying SDN controller strictly as a device driver for physical deployment.
- **Intent DAGs & Delegation:** Uses Directed Acyclic Graphs (DAGs) to represent relationships between different intents, linking logical objectives to low-level resource allocations. If an intent spans multiple domains, it can be securely delegated to adjacent domains.
- **Event-Based Simulations:** Provides a hackable interface designed to accelerate algorithmic research and conduct (event-based) simulations under diverse scenarios.
- **Visualizations:** The companion package `MINDFulMakie.jl` offers out-of-the-box visualizations for intent DAGs and network topologies.

MINDFul.jl provides the foundation to develop experimental intent system architectures and customized algorithms to advance the adaptation of IBN in modern multi-domain networks.
