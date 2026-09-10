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

CI gate — one line ([Marketplace](https://github.com/marketplace/actions/verified-examples); copy to `.github/workflows/verified-examples.yml`):
```yaml
name: verified-examples
on: [push, pull_request]
permissions:
  contents: read
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: DrVelvetFog/verified-examples@v1
```

Action inputs (all optional): `command` check|run · `manifest` · `attestations` · `rerun` (default true) · `strict` (default true; false = report but never fail the step) · `checkout` · `working-directory`. Output: `verified` true/false. Producers can attest in CI with `command: run`. Without Actions, the tool is the single stdlib-only `xv` file:
```yaml
      - run: curl -fsSL https://raw.githubusercontent.com/DrVelvetFog/verified-examples/main/xv -o xv && chmod +x xv
      - run: ./xv check --rerun --strict
```

Attested-example claims resolve in [ev](https://github.com/DrVelvetFog/evidence-tier) as `ran` via `xv:<attest.json>#<id>`. First consumer: [rv](https://github.com/DrVelvetFog/reversible). This repo dogfoods itself: `test.sh` is its own attested example, checked by the action on every push.
