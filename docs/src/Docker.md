# How to instantiate MINDFul.jl docker
Each MINDFul.jl instance is responsible of one domain. The docker image is builded once and run as many times as different domains exist in the network.

## Building the docker image
```bash
docker build --build-arg COPY_MANIFEST=<bool> -t mindful_docker:latest .
```

COPY_MANIFEST variable allows the user to include the existing Manifest.toml (true), or create it when building the docker image (false).

## Running MINDFul.jl instances
```bash
docker run -it -e configpath="path/to/<configX.toml>" --network host mindful_docker:latest
```

Repeat this instruction for each domain with the corresponding configuration file. The "configpath" variable expects the absolute or relative path to the configuration file of each domain in a TOML format. Examples of configuration files are available at `test/data`.