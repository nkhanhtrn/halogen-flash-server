# Flint preview

halogen now runs Flint, RecursiveSI's 40B mixture-of-experts model (about 2B active parameters), as a preview on Strix Halo. It is a separate image tag; `:latest` is unchanged and still serves Qwen3.8 Flash-Next.

## Quickstart

```bash
podman run --rm -p 8731:8731 \
  --device /dev/kfd --device /dev/dri --group-add keep-groups \
  --ipc=host --ulimit memlock=-1:-1 \
  -e HALOGEN_SERVE_MODEL=flint \
  -v ~/halogen-models:/models \
  ghcr.io/peonist-ai/halogen-flash-server:0.18.14-flint-preview
```

On first start the image downloads the weights (RecursiveSI/flint-int4, about 21 GB, Apache-2.0) into `~/halogen-models/flint-int4` and checks every file against the revision we tested. To fetch them yourself instead:

```bash
huggingface-cli download RecursiveSI/flint-int4 \
  --revision 3b93f9053b530488405ae9fca51d4900d6ce21f0 \
  --local-dir ~/halogen-models/flint-int4
```

The API is the same OpenAI-compatible endpoint as halogen's other models (`/v1/chat/completions`, `/v1/responses`, `/v1/messages`, tools, structured output, streaming).

## Speed

Measured on Strix Halo (Ryzen AI Max+ 395, 128 GB), int4 weights, one request at a time unless stated:

| | tokens/s |
|---|---|
| decode, 1k-2k context | ~97-98 (short prompts ~103) |
| decode, 32k context | ~67-70 |
| four requests at once, total | ~190 |
| prefill, 2k / 32k prompt | ~3,700 / ~2,450 |
| follow-up turn at 32k context (cached) | ~0.4 s to the first token |

## What is in it

- int4 weights (RecursiveSI's own quantization, loaded exactly as published).
- Four concurrent requests decoded together, each with output identical to running it alone.
- A prompt cache that keeps the conversation in place, so follow-up turns prefill only the new tokens.
- Tool calls and structured output with grammar-constrained decoding.

## Opt-in

- `HALOGEN_FLINT_SPEC=1`: speculative decoding from prompt lookup (greedy requests only; output is identical to decoding without it).
- `HALOGEN_FLINT_KV8=1`: an 8-bit KV cache, faster at long context (about +15% decode at 64k, +20% at 128k).

## Known limits

- Prefill slows past roughly 80-90k tokens of context (about 900 tokens/s at 256k), because Flint attends the whole context in some layers.
- Speculative decoding does not yet apply to sampled requests; that comes in a preview update.
- This is a preview: Flint is not part of the regular release, and its numbers may move.

Flint and its weights are RecursiveSI's work, used under the Apache-2.0 license.
