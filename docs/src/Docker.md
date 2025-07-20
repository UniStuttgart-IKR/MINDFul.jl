# How to instantiate MINDFul docker
Each MINDFul instance is responsible of one domain. The docker image is builded once and run as many times as different domains exist in the network.

## Building the docker image
```docker build --build-arg COPY_MANIFEST=<bool> -t mindful_docker:latest .```

COPY_MANIFEST variable allows the user to include the existing Manifest.toml (true), or create it when building the docker image (false).

## Running MINDFul instances
```docker run -it -e configpath="test/data/<configX.toml>" --network host mindful_docker:latest```

Repeat this instruction for each domain with the corresponding configuration file. "configpath" variable contains the path to the configuration file of each domain in a TOML format. 