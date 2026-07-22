# Architecture and Concepts

MINDFul.jl models IP-optical routing, modulation, and spectrum assignment (RMSA) operations where high-level connectivity intents are recursively compiled into lower-level intents down to router and OXC configurations.

## IBN-over-SDN

When designing a multi-domain IBN system, MINDFul.jl embraces the **IBN-over-SDN** architecture. This approach decouples intent handling from the underlying SDN paradigm. The intent handling is separated into its own dedicated framework, operating independently and utilizing the underlying SDN controller strictly as a device driver for physical deployment. This separation of concerns fosters modularity and allows each layer to evolve independently.

## IP-Optical Layer Model

The architecture modeled by MINDFul.jl holds on to the pure IP-optical architecture signified by two layers:
- **Electrical Layer:** Composed of IP routers and virtual links.
- **Optical Layer:** Composed of Optical Cross Connects (OXCs) and physical fiber links.

Currently, the library focuses on 3 primary devices:
- The network node as a whole
- The IP router
- The optical cross connect (OXC)

## Intent DAGs and Delegation

MINDFul.jl uses **intent DAGs** (Directed Acyclic Graphs) to represent relationships between different intents. This hierarchical structure connects higher-level intents, which have a logical objective (e.g., establishing a connectivity service), with low-level intents (LLIs), which are responsible for resource allocation and hardware configurations on the specific devices.

If an intent spans multiple domains, it is split at border nodes, and the external portion is securely **delegated** to the adjacent domain without exposing internal topological details. This structure enables seamless interoperability between domains.

## Intent States and Operations

Intents are highly dynamic and transition through several states during their lifecycle. MINDFul.jl commonly identifies four core intent states:
- `uncompiled`: Unprocessed intents inside the system.
- `compiled`: Processed intents with a well-defined implementation derived.
- `installed`: Active intents whose implementation has been realized in the appropriate network devices.
- `failed`: Active intents that malfunction after some failure during operation.

To enable state transitions, several operations and algorithms are modeled:
- **Intent Compilation:** Deriving an intent implementation and transitioning an intent to the `compiled` state.
- **Intent Monitoring:** Ensuring that the installed intents satisfy all the requirements and triggering fallbacks in case of failure.
- **Intent Conflict Resolution:** Handling situations when several intents require the same resources.

## References

- [F. Christou, "Decentralized Intent-driven Coordination of Multi-Domain IP-Optical Networks," 2022 18th International Conference on Network and Service Management (CNSM), Thessaloniki, Greece, 2022, pp. 359-363, doi: 10.23919/CNSM55787.2022.9964606](https://ieeexplore.ieee.org/document/9964606/)
- [F. Christou and A. Kirstaedter, "Grooming Connectivity Intents in IP-Optical Networks Using Directed Acyclic Graphs," Photonic Networks; 24th ITG-Symposium, Berlin, 2023, pp. 1-4.](https://ieeexplore.ieee.org/document/10173072)
- [F. Christou and A. Kirstädter, "Using Intent Directed Acyclic Graphs in Multi-Domain IP-Optical Networks," 2023 33rd International Telecommunication Networks and Applications Conference, Melbourne, Australia, 2023, pp. 176-179, doi: 10.1109/ITNAC59571.2023.10368533](https://ieeexplore.ieee.org/document/10368533)
