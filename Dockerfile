FROM julia:latest AS builder

WORKDIR /MINDFul.jl

COPY Project.toml Manifest.toml ./

ARG COPY_MANIFEST

RUN if [ "$COPY_MANIFEST" = "false" ]; then \
        echo "Not copying Manifest.toml"; \
        rm Manifest.toml; \
    else \
        echo "Copying Manifest.toml"; \
    fi

RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'

COPY src/ ./src/
COPY ext/ ./ext/
COPY docs/ ./docs/
COPY test/ ./test/


FROM julia:latest

WORKDIR /MINDFul.jl

COPY --from=builder /root/.julia /root/.julia
COPY --from=builder /MINDFul.jl /MINDFul.jl

RUN julia --project=. -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'

CMD julia --project=. -i -e 'using MINDFul; MINDFul.main()' $configpath