# How to instantiate MINDFul.jl Docker containers
Each MINDFul.jl instance is responsible of one domain. The Docker image is built once and run as many times as different domains exist in the network.

## Building the Docker image
```bash
docker build --build-arg COPY_MANIFEST=<bool> -t mindful_docker:latest .
```

This command must be executed at MINDFul.jl directory. `COPY_MANIFEST` variable allows the user to include the existing `Manifest.toml` (true), or create it when building the Docker image (false).

## Running MINDFul.jl containers
```bash
docker run -it -e configpath="path/to/<configX.toml>" --network host mindful_docker:latest
```

Repeat this instruction for each domain with the corresponding configuration file. The `configpath` variable expects the absolute or relative path (w.r.t. the MINDFul.jl directory) of the configuration file for each domain in a TOML format. The corresponding RSA keys must be previously included and referenced in the configuration file with the absolute or relative path (w.r.t. the `configX.toml` directory). Examples of configuration files are available at `test/data`.