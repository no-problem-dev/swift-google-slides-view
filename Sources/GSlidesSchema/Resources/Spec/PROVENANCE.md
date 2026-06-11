# Vendored specification provenance

This directory holds the **authoritative, locally-frozen** Google Slides API specification that
the whole package is validated against. Nothing here is hand-authored vocabulary — every type,
enum, and constraint traces back to an official Google source quoted below.

## Files

| File | What it is | SSOT for |
|---|---|---|
| `slides-api-discovery-v1.json` | Google's machine-readable discovery document, fetched verbatim and pretty-printed | Types, enums, field-level prose constraints |
| `constraints-catalog.yaml` | Prose-derived constraints (objectId regex, atomicity, field masks, page-bounds…) quoted verbatim with source URLs | The `PreflightValidator` rules |
| `PROVENANCE.md` | This file | How to refresh and what's pinned |

## Sources

- **Discovery document:** `https://slides.googleapis.com/$discovery/rest?version=v1`
  Pinned revision: **`20260601`** (retrieved 2026-06-11). The single machine-readable source of
  truth; the Google client libraries themselves are generated from it.
- **REST reference (request shapes, objectId regex, field masks):**
  `https://developers.google.com/workspace/slides/api/reference/rest/v1/presentations/request`
- **batchUpdate model & atomicity:**
  `https://developers.google.com/workspace/slides/api/reference/rest/v1/presentations/batchUpdate`
- **Transform / coordinate semantics:**
  `https://developers.google.com/workspace/slides/api/guides/transform`
- **Error model (`google.rpc.Status`, `BadRequest.FieldViolation`):**
  `https://google.aip.dev/193` and googleapis `google/rpc/error_details.proto`

## Refreshing

```sh
scripts/fetch-discovery.sh   # re-fetches the discovery doc into this directory
swift test                   # SpecProvenanceTests fails if the pin or pinned prose drifted
```

`SpecProvenanceTests` pins the discovery `revision` and asserts the vendored doc still contains the
exact prose sentences the validator relies on (objectId regex, batch atomicity, write control). If
that test fails, Google changed the spec: review the diff, bump `GSlidesSpec.pinnedRevision`,
update the quoted sentences in `constraints-catalog.yaml`, and re-derive any affected validator
rule before re-pinning. This is deliberate — the spec must never drift silently.

## Why frozen, not fetched at runtime

A hermetic build can't depend on a network call, and an LLM-driving validator must be reproducible:
the same request must produce the same verdict regardless of when it runs. Freezing the spec and
detecting drift in CI gives both.
