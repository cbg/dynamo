# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# OpenRouter benchmark harness (https://github.com/OpenRouterTeam/benchmark-harness),
# pinned to one upstream commit and run unmodified except for the patch below.
# Code: Apache-2.0 (OpenRouter). toolcall-schema-fuzz dataset: CC-BY-4.0 (OpenRouter).
#
# Build:
#   docker build --build-arg HARNESS_COMMIT=<sha> -t <registry>/openrouter-bench-harness:<sha> .
# Run (see e2e_verifier/cli.py `_run_openrouter`):
#   docker run --network host -e OPENROUTER_BASE_URL=http://127.0.0.1:8000/v1 \
#     -e OPENROUTER_API_KEY=unused -v $PWD/out:/results <image> \
#     bench --benchmark toolcall_schema_fuzz --model <served model> ...
FROM docker.io/oven/bun:1.4.4

ARG HARNESS_REPO=https://github.com/OpenRouterTeam/benchmark-harness.git
ARG HARNESS_COMMIT=c9633333c5c4a158eae059bd257f81229ff4589c

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /harness
RUN git init -q . \
    && git remote add origin "${HARNESS_REPO}" \
    && git fetch -q --depth 1 origin "${HARNESS_COMMIT}" \
    && git checkout -q FETCH_HEAD

# Local patch, applied at build time so the upstream tree stays byte-identical
# in git terms. Remove once the equivalent change lands upstream.
COPY 0001-score-direct-endpoint-rejections.patch /harness/patches/0001-score-direct-endpoint-rejections.patch
RUN git apply --check patches/0001-score-direct-endpoint-rejections.patch \
    && git apply patches/0001-score-direct-endpoint-rejections.patch

RUN bun install --frozen-lockfile

# Record provenance for the verifier.
RUN printf '{"repo":"%s","commit":"%s","patches":["0001-score-direct-endpoint-rejections.patch"]}\n' \
      "${HARNESS_REPO}" "${HARNESS_COMMIT}" > /harness/PROVENANCE.json

COPY entrypoint.sh /usr/local/bin/harness-entrypoint
RUN chmod +x /usr/local/bin/harness-entrypoint
VOLUME ["/results"]
ENTRYPOINT ["/usr/local/bin/harness-entrypoint"]
CMD ["--help"]
