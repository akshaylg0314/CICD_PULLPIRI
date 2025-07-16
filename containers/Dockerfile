# SPDX-FileCopyrightText: Copyright 2024 LG Electronics Inc.
# SPDX-License-Identifier: Apache-2.0

# ===== Build Stage =====
FROM rust:1.78.0-slim AS builder

ARG COMPONENT
ENV COMPONENT=${COMPONENT}

WORKDIR /pullpiri

# Copy common and component-specific code
COPY ./src/common /pullpiri/common
COPY ./src/${COMPONENT} /pullpiri/${COMPONENT}

# Set working dir manually in RUN since ARGs can't be interpolated in WORKDIR
RUN apt update -y && \
    apt install -y libdbus-1-dev pkg-config protobuf-compiler libssl-dev && \
    cd /pullpiri/${COMPONENT} && cargo build --release

# ===== Runtime Stage =====
FROM alpine:3.20.3

ARG COMPONENT
ENV COMPONENT=${COMPONENT}

WORKDIR /pullpiri

COPY ./src/settings.yaml .

# Copy all built binaries from release folder to runtime image
COPY --from=builder /pullpiri/${COMPONENT}/target/release /pullpiri/

CMD [ "sh" ]
