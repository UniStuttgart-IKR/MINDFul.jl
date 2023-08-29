# `MINDFul.jl`

`MINDFul.jl` is a Framework for Intent-driven Multi-Domain Networks coordination.
It provides the means for algorithmic research in the field of IP-Optical networking.
It includes a stateful representation of common networking equipment and facilitates event-based simulations.

# Companion repos
Companion repositories:
- [MINDFulMakie.jl](https://github.com/UniStuttgart-IKR/MINDFulMakie.jl) for visualization purposes
- [MINDFulCompanion.jl](https://github.com/UniStuttgart-IKR/MINDFulCompanion.jl) planned for several algorithms and utilities.
- [MINDFulNotebookExamples](https://github.com/UniStuttgart-IKR/MINDFulNotebookExamples.jl) for some examples in the form of [Pluto](https://github.com/fonsp/Pluto.jl) notebooks.\
For example, [have a look](https://unistuttgart-ikr.github.io/MINDFulNotebookExamples.jl/intentDAGinMD.html) in a notebook related to our latest work on using intent DAGs in multi-domain IP-optical networks.
- [MINDFulGLMakieApp.jl](https://github.com/UniStuttgart-IKR/MINDFulGLMakieApp.jl) for a (WIP) experimental GUI application.

# Introduction to intent-driven networking

Intent-driven Networking, or Intent-based Networking (IBN), is a paradigm that enables network operators to manage their network by expressing high-level desires (or intentions).
Contrary to traditional rule-based or policy-based networking, in IBN, the network operator only needs to express WHAT needs to be done and not HOW.
That means there is a shift towards a more declarative way of thinking.

## Intents
The building blocks of operating an intent-driven network are the *intents*, which, as described before, are the desires.
The intents specify in an abstract way what needs to be done and under what requirements.
From this point on, it is the task of the *intent framework* and not the network operator to process these intents and successfully produce an appropriate network configuration.

Each intent, once entered the network, is described by a state, the most common of which are:
- `uncompiled`: intent is just registered in the system and nothing more
- `compiled`: there is an implementation of an intent
- `compiledfailed`: compilation of the intent failed (e.g., due to scarce resources)
- `uninstalled`: intent is compiled but still not active in the network
- `installed`: intent is compiled and installed in the appropriate network elements
- `installfailed`: installation of the intent failed (e.g., due to network fault)

To compile an intent, `MINDful.jl` follows a novel technique where system-generated intents are produced and compiled, forming an intent tree.
The more down we traverse the tree, the less abstract the intents become.
The leaves of the tree are called low-level intents and are device-level intents.

IBN can be applied anywhere in the OSI layers.
However, `MINDFul.jl` is focused on the IP-Optical layers.
An example of such an intent would be a connectivity intent between 2 nodes with specific QoS requirements.

## Software-Defined Networking (SDN)
IBN is commonly placed on top of an SDN controller.
SDN separates the control and the data plane in a network.
In other words, and as the name might suggest, SDN provides programmable reconfigurable networks.
This is commonly achieved by having a centralized controller with global network knowledge and the ability to control and monitor the network elements.

## IBN over SDN architecture
`MINDFul.jl` follows the common architecture of placing the IBN framework on top of the SDN controller.
The IBN framework contains all the logic and the intent system, and the SDN controller is the mediator that talks to the network devices.
The SDN controller is necessary the same way a driver is for a computer.
We might even have a stack of IBN framework instances before we end up with the driver being the SDN controller.
This might be common for centralized multi-domain control.

## Multi-Domain (MD) networking
MD networking is a rather broad term and can span across different scenarios, such as:
- centralized-controlled domains with global knowledge
- decentralized-controlled domains with global knowledge
- decentralized-controlled domains with partial knowledge
The last scenario can be applied to domains belonging to different organizations, which is what the current package targets at best.

## Role of MINDFul.jl
`MINDFul.jl` is a tool to facilitate research on state-of-the-art algorithms in decentralized multi-domain intent-driven networking.
It provides interfaces to investigate various coordination and intent provision mechanisms.

