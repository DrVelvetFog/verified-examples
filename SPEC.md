# Verified Examples

**Status:** draft `v0` · working name `xv`
**Purpose:** let an agent *check* a library's usage instead of *recalling* it — by shipping examples that carry an execution attestation: which version they last ran against, exit code, output digest, when. Docs an agent can't hallucinate against, because the example is the test.

Fourth in a set. [Change-Evidence](../change-evidence/SPEC.md) · [Reversible Actions](../reversible/SPEC.md) · [Evidence Tiers](../evidence-tier/SPEC.md). This one is the Evidence-Tier `ran` tier applied to documentation, so it reuses that record and adds only a manifest and a runner.

---

## 1. The gap this closes

Agents invent API surfaces because docs are prose. Two families of fix exist and neither closes the gap:

- **Freshness** — `llms.txt`, Context7, doc-scrapers feed the agent *current* prose. That removes stale-training hallucination but not wrong-or-drifted-docs hallucination: nothing was executed.
- **Executable examples** — Go `Example` tests, Rust doctests, Python doctest, Elixir doctests, `test_docs_*_coherence` gates. These do execute in CI, but per-language, not discoverable uniformly, and the *result* of that execution is not published in a form an agent can consume.

The missing piece is small: an **attestation** — a signed-or-signable record that says "example E (these bytes) ran against version V, exit 0, produced output with digest D, at time T" — plus a place to find it. With that, an agent's question changes from "what does the doc say" to "what has been shown to work against the version I have."

## 2. Terminology

| Term | Meaning |
|---|---|
| **example** | A file the maintainer intends users (and agents) to imitate; runnable by one command. |
| **manifest** | `examples/manifest.json`: package, `version_cmd`, and the list of examples (id, path, command). |
| **attestation** | One in-toto Statement per example: subject = example bytes by digest; predicate = version, command, exit, stdout digest+tail, `ran_at`, runner. |
| **check** | The consumer-side verdict per example: `VERIFIED` · `MODIFIED` · `STALE` · `FAILED` · `MISSING`. |

## 3. Design rules

**R1 — The example is the test.** If it doesn't run, it isn't verified. Prose snippets and un-attested files are `told` (Evidence-Tier vocabulary); only attested, unchanged, same-version examples are `ran`.

**R2 — Bind to bytes and to version.** The attestation subject is the example's content digest; the predicate pins the version the run was against. Either drifting is a distinct, named verdict (`MODIFIED` / `STALE`), never a silent pass.

**R3 — Static check is cheap; re-run is truth.** `xv check` without `--rerun` verifies bytes + version + attested exit. It cannot see behavior drift under the same version (docs that lie). `--rerun` executes and compares exit + output digest. Consumers SHOULD re-run when the cost is low; the record says which was done.

**R4 — Failing examples are attested as failing.** `xv run` writes the record with its real exit code and returns non-zero. A red example is information, not something to omit.

**R5 — Reuse the envelope.** Attestations are in-toto Statements; sign with DSSE / Sigstore like any other. Verified-example claims resolve in Evidence-Tier verifiers via `xv:<attest.json>#<id>` action refs.

**R6 — Discoverable from where agents already look.** `llms.txt` (or README) carries a `## Verified examples` stanza linking manifest + attestations. No new discovery protocol.

## 4. Files

```
examples/manifest.json      # {"package","version_cmd","examples":[{"id","path","command"}]}
examples/attest.json        # {"schema":"verified-examples/v0","attestations":[<in-toto Statement>...]}
llms.txt                    # ## Verified examples → the two files above
.github/workflows/verified-examples.yml   # xv check --rerun --strict on push/PR
```

Predicate (`https://github.com/DrVelvetFog/verified-examples/v0`):

```jsonc
{ "id": "quickstart", "package": "rv", "version": "0.1.0",
  "command": "bash examples/quickstart.sh", "exit": 0,
  "stdout": { "sha256": "…", "bytes": 165, "tail": "…last 200 chars…" },
  "ran_at": "2026-08-17T14:28:58Z",
  "runner": { "os": "linux", "python": "3.12.3", "ci": true } }
```

## 5. Verdicts (consumer)

| verdict | meaning | agent should |
|---|---|---|
| `VERIFIED` | attested · bytes unchanged · installed version == attested · (with `--rerun`) exit+output reproduce | use verbatim as ground truth |
| `MODIFIED` | example bytes ≠ attested | treat as prose until re-attested |
| `STALE` | installed version ≠ attested | treat as prose for this version; may still be a good hint |
| `FAILED` | attested exit ≠ 0, or re-run diverges | do not imitate; the docs and the code disagree |
| `MISSING` | in manifest, no attestation | prose |

## 6. Measured (v0)

- Dogfooded on `rv`: `examples/quickstart.sh` (README usage, deterministic output) + the test suite as an example. `xv run` → 2 attestations; `xv check` and `--rerun` both `ALL VERIFIED`; an `ev` claim citing `xv:…#quickstart` resolves as `ran`, and a wrong digest downgrades to `told`.
- `test.sh` 14/14: unattested → prose; VERIFIED; MODIFIED; STALE on version bump; behavior drift invisible to static check and caught by `--rerun`; failing example attested as failing with non-zero `run`; MISSING; llms stanza.

## 7. Non-goals

- Not a doc generator, not a doc host. It attests examples that already exist.
- Not a replacement for language-native doctests — wrap them: an example's `command` can be `go test -run Example` or `cargo test --doc`.
- Not a guarantee of correctness. It guarantees the example *ran as attested*; whether it is the right way to use the library is still the maintainer's job.
