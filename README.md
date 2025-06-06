<div align="center"> 
<img src="images/MINDFul-wtext.svg" alt="MINDFul-wtext" width="30%"></img>

[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://UniStuttgart-IKR.github.io/MINDFul.jl/dev)
[![codecov.io](http://codecov.io/github/UniStuttgart-IKR/MINDFul.jl/coverage.svg?branch=main)](http://codecov.io/github/UniStuttgart-IKR/MINDFul.jl?branch=main)

</div>

*A Framework for Intent-driven Multi-Domain Network coordination*

`MINDFul.jl` is a young project aiming to research coordination algorithms of intent-driven multi-domain (MD) networks.
It offers interfaces for the development of resource-allocation algorithms and MD coordination mechanisms.

For now, `MINDFul.jl` only supports simulation, but future work will bind `MINDFul.jl` with real-life Software Defined Network (SDN) controllers. 
Currently there are [efforts](https://github.com/UniStuttgart-IKR/MINDFulTeraFlowSDN.jl) to bind it with [TeraFlowSDN](https://www.teraflow-h2020.eu/).
At the same time, [ongoing efforts](https://github.com/UniStuttgart-IKR/MINDFul.jl/pull/16) will enable distributed use of MINDFul.jl


This package is in an early development stage and might break often.
If you have problems, try updating to the latest Julia version, as we closely follow the new releases and backwards compatibility is not promised.

Version 0.3.0 has been a major rewrite.
Some of the following repositories are still not updated.

Companion repositories:
- [MINDFulMakie.jl](https://github.com/UniStuttgart-IKR/MINDFulMakie.jl) for visualization purposes
- [MINDFulCompanion.jl](https://github.com/UniStuttgart-IKR/MINDFulCompanion.jl) planned for several algorithms and utilities. (obselete)
- [MINDFulNotebookExamples](https://github.com/UniStuttgart-IKR/MINDFulNotebookExamples.jl) for some examples in the form of [Pluto](https://github.com/fonsp/Pluto.jl) notebooks.\
For example, [have a look](https://unistuttgart-ikr.github.io/MINDFulNotebookExamples.jl/intentDAGinMD.html) in a notebook related to our latest work on using intent DAGs in multi-domain IP-optical networks. (obselete)
- [MINDFulGLMakieApp.jl](https://github.com/UniStuttgart-IKR/MINDFulGLMakieApp.jl) (obselete)


Watch our JuliaCon2023 presentation to learn more on [YouTube](https://www.youtube.com/watch?v=LrCFRWym0Lc)

[![Click to watch video](https://img.youtube.com/vi/LrCFRWym0Lc/0.jpg)](https://www.youtube.com/watch?v=LrCFRWym0Lc)

