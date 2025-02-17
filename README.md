<div align="center"> 
<img src="images/MINDFul-wtext.svg" alt="MINDFul-wtext" width="30%"></img>

[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://UniStuttgart-IKR.github.io/MINDFul.jl/dev)
[![codecov.io](http://codecov.io/github/UniStuttgart-IKR/MINDFul.jl/coverage.svg?branch=main)](http://codecov.io/github/UniStuttgart-IKR/MINDFul.jl?branch=main)

</div>

*A Framework for Intent-driven Multi-Domain Network coordination*

`MINDFul.jl` is a young project aiming to research coordination algorithms of intent-driven multi-domain (MD) networks.
It offers interfaces for the development of resource-allocation algorithms and MD coordination mechanisms.

For now, `MINDFul.jl` only supports simulation, but [future work](https://unistuttgart-ikr.github.io/MINDFul.jl/dev/roadmap/) may bind `MINDFul.jl` with real-life Software Defined Network (SDN) controllers like [ODL](https://www.opendaylight.org/) or [ONOS](https://opennetworking.org/onos/) 

This package is in an early development stage and might break often.
If you have problems, try updating to the latest Julia version, as we closely follow the new releases and backwards compatibility is not promised.

Companion repositories:
- [MINDFulMakie.jl](https://github.com/UniStuttgart-IKR/MINDFulMakie.jl) for visualization purposes
- [MINDFulCompanion.jl](https://github.com/UniStuttgart-IKR/MINDFulCompanion.jl) planned for several algorithms and utilities.
- [MINDFulNotebookExamples](https://github.com/UniStuttgart-IKR/MINDFulNotebookExamples.jl) for some examples in the form of [Pluto](https://github.com/fonsp/Pluto.jl) notebooks.\
For example, [have a look](https://unistuttgart-ikr.github.io/MINDFulNotebookExamples.jl/intentDAGinMD.html) in a notebook related to our latest work on using intent DAGs in multi-domain IP-optical networks.
- [MINDFulGLMakieApp.jl](https://github.com/UniStuttgart-IKR/MINDFulGLMakieApp.jl) for a (WIP) experimental GUI application.

Currently, as you will find in [MINDFulNotebookExamples](https://github.com/UniStuttgart-IKR/MINDFulNotebookExamples.jl) there are some workflow dependencies on forked/unregistered packages due to pending PRs. These will be handled in time.

Watch our JuliaCon2023 presentation to learn more on [YouTube](https://www.youtube.com/watch?v=LrCFRWym0Lc)

[![Click to watch video](https://img.youtube.com/vi/LrCFRWym0Lc/0.jpg)](https://www.youtube.com/watch?v=LrCFRWym0Lc)

To expand upon:
allocate - deallocate
reserve - unreserve
function getters
get... -> get field
new... -> construct something new

New TODOs
- do install
- do multidomain
