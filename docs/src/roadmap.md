# Roadmap

`MINDFul.jl` is an effort meant to help parties interested in the reasearch of intent-driven network coordination.
Future additions are going to be determined by our research directions.
However the following consitute a list of plans that are irrelevant to research purposes
- complete substitution of [`MetaGraphs`](https://github.com/JuliaGraphs/MetaGraphs.jl) by [`MetaGraphsNext`](https://github.com/JuliaGraphs/MetaGraphsNext.jl)
- integration of [`Term.jl`](https://github.com/FedeClaudi/Term.jl) for more beautifl command-line operation
- definition of line rate units with [`Unitful.jl`](https://painterqubits.github.io/Unitful.jl/stable/)
- more user-friendly interfaces and improved docs

Although much of similar software is commonly proprietary, there has been some development for open-source SDN controllers, among which the ones used for serious deployment are [ONOS](https://opennetworking.org/onos/) and [OpenDaylight](https://www.opendaylight.org/) (ODL), written in Java. These frameworks adapted to the IBN paradigm by gradually enhancing their architecture, resulting in an unclear separation between SDN and IBN. While MINDFul.jl cannot be compared with ONOS or ODL, to our knowledge, it is unique in that it offers a clear distinction between IBN and SDN, where the focus indisputably resides on the IBN side. However, future aspirations include binding MINDFul.jl with real-life SDN controllers. Due to the clear decoupling in MINDFul.jl this is possible, but we need to accept that it will require a serious amount of developer time. Another obstacle is the unstandardized IBN Southbound-Interface (SBI), which leaves a customized binding with the chosen SDN controller as the only option. Instead, for now, MINDFul.jl only provides a dummy SDN Controller, which supports only simulations.
