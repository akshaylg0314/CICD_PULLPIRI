# ====== Build Stage ======
FROM ghcr.io/eclipse-pullpiri/pullpiribuilder:latest AS builder

ARG COMPONENT
ARG TARGETARCH

WORKDIR /pullpiri

COPY ./src/common ./common
COPY ./src/${COMPONENT} ./${COMPONENT}

RUN cd ./${COMPONENT} && cargo build --release

# ====== Runtime Stage ======
FROM alpine:3.21.3

ARG COMPONENT
ARG TARGETARCH

# Copy dynamically linked libraries from builder stage into minimal runtime
COPY --from=builder /dummy /lib

# Additional per-arch setup
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        mkdir -p /lib64 && \
        cp -rf /lib/lib64/ld-linux-x86-64.so.2 /lib64/; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        true; \
    else \
        exit 1; \
    fi

WORKDIR /pullpiri

COPY ./src/settings.yaml .

COPY --from=builder /pullpiri/${COMPONENT}/target/release/${COMPONENT} .

CMD ["sh"]
