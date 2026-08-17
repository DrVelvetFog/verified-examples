# xv — verified examples

Docs an agent can **check instead of recall**. Ship examples with an execution attestation (which version they ran against, exit code, output digest, when) as in-toto Statements; agents verify before imitating. See [SPEC.md](SPEC.md).

```bash
xv run                        # producer / CI: run every example in examples/manifest.json → examples/attest.json
xv check [--rerun] [--strict] # consumer / agent: VERIFIED · MODIFIED · STALE · FAILED · MISSING per example
xv llms                       # the "## Verified examples" stanza for llms.txt
./test.sh                     # 14 checks
```

Manifest:
```json
{ "package": "rv", "version_cmd": "cat VERSION",
  "examples": [ { "id": "quickstart", "path": "examples/quickstart.sh", "command": "bash examples/quickstart.sh" } ] }
```

CI gate (copy to `.github/workflows/verified-examples.yml`):
```yaml
name: verified-examples
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL https://raw.githubusercontent.com/DrVelvetFog/verified-examples/main/xv -o xv && chmod +x xv
      - run: ./xv check --rerun --strict
```

Attested-example claims resolve in [ev](https://github.com/DrVelvetFog/evidence-tier) as `ran` via `xv:<attest.json>#<id>`. First consumer: [rv](https://github.com/DrVelvetFog/reversible).
