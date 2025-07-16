# SPDX-License-Identifier: Apache-2.0

ARG COMPONENT
FROM rust:1.78.0-slim AS builder
WORKDIR /piccolo

# Install dependencies
RUN apt update -y && \
    apt install -y libdbus-1-dev pkg-config protobuf-compiler libssl-dev

# Copy shared and component source
COPY ./src/common /piccolo/common
COPY ./src/${COMPONENT} /piccolo/${COMPONENT}

WORKDIR /piccolo/${COMPONENT}
RUN cargo build --release

# Final runtime image
FROM alpine:3.20.3
WORKDIR /piccolo

COPY ./src/settings.yaml .

# Copy built binaries dynamically
ARG COMPONENT
COPY --from=builder /piccolo/${COMPONENT}/target/release /piccolo/

CMD ["sh"]
