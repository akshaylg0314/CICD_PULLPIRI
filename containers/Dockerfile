# SPDX-FileCopyrightText: Copyright 2024 LG Electronics Inc.
# SPDX-License-Identifier: Apache-2.0

# ===== Build Stage =====
FROM rust:1.78.0-slim AS builder

ARG COMPONENT
ENV COMPONENT=${COMPONENT}

WORKDIR /pullpiri

# Copy shared and component-specific source code
COPY ./src/common /pullpiri/common
COPY ./src/${COMPONENT} /pullpiri/${COMPONENT}

# Install build dependencies and compile
RUN apt update -y && \
    apt install -y libdbus-1-dev pkg-config protobuf-compiler libssl-dev && \
    cd /pullpiri/${COMPONENT} && cargo build --release

# ===== Runtime Stage =====
FROM alpine:3.20.3

ARG COMPONENT
ENV COMPONENT=${COMPONENT}

WORKDIR /pullpiri

# Add runtime settings
COPY ./src/settings.yaml .

# Copy built binary(ies) from builder stage
COPY --from=builder /pullpiri/${COMPONENT}/target/release /pullpiri/

CMD ["sh"]
