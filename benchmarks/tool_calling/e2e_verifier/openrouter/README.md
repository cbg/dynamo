# OpenRouter toolcall-schema-fuzz image

Container for the `openrouter` suite. It runs OpenRouter's benchmark harness
(https://github.com/OpenRouterTeam/benchmark-harness, Apache-2.0; dataset
CC-BY-4.0) pinned to one commit, with one build-time patch.

## Why the patch

Upstream scores an HTTP 400/422 as `request_rejected` only when the body carries
OpenRouter's provider envelope (`error.metadata.provider_name`). A direct serving
stack such as Dynamo answers without it, so the first unsupported schema turned
into a `SolverError` and aborted the whole run. The patch treats every 400/422
from a non-`openrouter.ai` base URL as `request_rejected`; behaviour against
openrouter.ai is unchanged. Drop the patch once the equivalent change lands
upstream.

## Build and publish

```bash
cd benchmarks/tool_calling/e2e_verifier/openrouter
docker build --build-arg HARNESS_COMMIT=c9633333c5c4a158eae059bd257f81229ff4589c \
  -t ghcr.io/<org>/openrouter-bench-harness:c963333-p2 .
docker push ghcr.io/<org>/openrouter-bench-harness:c963333-p2
```

Record the pushed digest in `e2e_verifier/profiles.json` (`openrouter.image`).

## Manual run

```bash
docker run --rm --network host \
  -e OPENROUTER_BASE_URL=http://127.0.0.1:8000/v1 -e OPENROUTER_API_KEY=unused \
  -v "$PWD/out:/results" ghcr.io/<org>/openrouter-bench-harness:c963333-p2 \
  bench --benchmark toolcall_schema_fuzz --model Qwen/Qwen3.6-35B-A3B \
  --reasoning-effort low --concurrency 8 \
  --solver-config '{"generator":"sentinel","maxTokens":2048,"timeoutMs":300000}'
docker run --rm -v "$PWD/out:/results" <image> report /results/*.parquet > report.json
```

`generator`: `sentinel` (187 cases, qualification) or `realistic` (2668, nightly).
Set `timeoutMs` to at least 300 s; runaway generations otherwise show up as
unrun samples instead of failures.

## Control group

A score alone does not say whether a miss is Dynamo's. Run the same suite
against the native engine serving the same model with the same parser names
(the harness's `vllm-serve` / `sglang-serve` variants; by hand,
`control-vllm-serve.example.yaml`), then diff the two results case by case:

```bash
python3 -m benchmarks.tool_calling.e2e_verifier.compare \
  --candidate out/dynamo/suite-result.json --control out/native/suite-result.json
```

Shared failures belong to the engine or the model; `candidate_only_failures`
are the ones Dynamo introduced and the number a relative verdict should gate
on. On Qwen3.6-35B-A3B (2026-10-30) Dynamo 1.6.1 and native vLLM shared 16
of Dynamo's 19 sentinel misses; Dynamo-only were `type: [object, null]` and
`allOf` object parameters (3), native-only were 13 (duplicate calls, `"null"`
strings).
