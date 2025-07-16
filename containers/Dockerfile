# SPDX-FileCopyrightText: Copyright 2024 LG Electronics Inc.
# SPDX-License-Identifier: Apache-2.0

# ===== Builder Stage =====
FROM ghcr.io/eclipse-pullpiri/pullpiribuilder:latest AS builder

ARG COMPONENT=server
ARG TARGETARCH
ENV COMPONENT=${COMPONENT}

WORKDIR /pullpiri

# Copy source
COPY ./src/common ./common
COPY ./src/${COMPONENT} ./${COMPONENT}

# Build binaries
RUN cd ./${COMPONENT} && cargo build --release

# ===== Runtime Stage =====
FROM alpine:3.21.3
ARG COMPONENT
ARG TARGETARCH

# Copy necessary libs
COPY --from=builder /dummy /lib

# Setup arch-specific ld-linux path
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        mkdir -p /lib64 && \
        cp -rf /lib/lib64/ld-linux-x86-64.so.2 /lib64/; \
    fi

WORKDIR /pullpiri

COPY ./src/settings.yaml .

# Copy built binaries
COPY --from=builder /pullpiri/${COMPONENT}/target/release/apiserver .
COPY --from=builder /pullpiri/${COMPONENT}/target/release/policymanager .
COPY --from=builder /pullpiri/${COMPONENT}/target/release/monitoringserver .

CMD ["sh"]
