# SPDX-FileCopyrightText: Copyright 2024 LG Electronics Inc.
# SPDX-License-Identifier: Apache-2.0

ARG COMPONENT
ARG BUILDER_IMAGE=ghcr.io/eclipse-pullpiri/pullpiribuilder:latest
ARG RUNTIME_IMAGE=ghcr.io/eclipse-pullpiri/pullpirirelease:latest

# =====================
# Stage 1: Builder
# =====================
FROM ${BUILDER_IMAGE} AS builder
ARG COMPONENT
WORKDIR /piccolo

COPY ./src/common/ /piccolo/common

# Copy component source
COPY ./src/${COMPONENT}/ /piccolo/${COMPONENT}

WORKDIR /piccolo/${COMPONENT}
RUN cargo build --release

# =====================
# Stage 2: Runtime
# =====================
FROM ${RUNTIME_IMAGE} AS runtime
ARG COMPONENT
WORKDIR /piccolo

COPY ./src/settings.yaml .

# Copy binaries based on component
# All in one CMD block so it’s reused by build context
# For `COPY --from`, these must match actual binary paths

# Server
COPY --from=builder /piccolo/server/target/release/apiserver /piccolo/apiserver
COPY --from=builder /piccolo/server/target/release/monitoringserver /piccolo/monitoringserver
COPY --from=builder /piccolo/server/target/release/policymanager /piccolo/policymanager

# Player
COPY --from=builder /piccolo/player/target/release/actioncontroller /piccolo/actioncontroller
COPY --from=builder /piccolo/player/target/release/filtergateway /piccolo/filtergateway
COPY --from=builder /piccolo/player/target/release/statemanager /piccolo/statemanager

# Agent
COPY --from=builder /piccolo/agent/target/release/nodeagent /piccolo/nodeagent

CMD ["sh"]
