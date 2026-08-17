#!/usr/bin/env bash
# xv tests: VERIFIED / MODIFIED / STALE / FAILED / MISSING / no-attestation paths.
set -uo pipefail
XV="$(cd "$(dirname "$0")" && pwd)/xv"
T=$(mktemp -d); cd "$T"; mkdir examples
pass=0; fail=0
ok(){ echo "  ok   $1"; pass=$((pass+1)); }
no(){ echo "  FAIL $1"; fail=$((fail+1)); }

echo 1.0.0 > VERSION
printf '#!/bin/sh\necho "hello from v$(cat VERSION)"\n' > tool.sh; chmod +x tool.sh
printf 'sh tool.sh\n' > examples/greet.sh
printf 'echo two\n' > examples/two.sh
cat > examples/manifest.json <<'EOF'
{"package":"toy","version_cmd":"cat VERSION","examples":[
 {"id":"greet","path":"examples/greet.sh","command":"sh examples/greet.sh"},
 {"id":"two","path":"examples/two.sh","command":"sh examples/two.sh"}]}
EOF

echo "0. no attestations yet -> prose"
"$XV" check | grep -q "examples are prose" && ok "unattested = told" || no "prose"

echo "1. run -> attest -> check VERIFIED, rerun VERIFIED"
"$XV" run >/dev/null && ok "run exit 0" || no "run"
"$XV" check | grep -q "^VERIFIED  greet" && "$XV" check | grep -q "ALL VERIFIED" && ok "check verified" || no "check"
"$XV" check --rerun | grep -q "re-ran: exit+output match" && ok "rerun matches" || no "rerun"
python3 -c "import json;a=json.load(open('examples/attest.json'))['attestations'][0];assert a['_type'].endswith('Statement/v1') and a['predicate']['version']=='1.0.0'" && ok "in-toto Statement, version bound" || no "shape"

echo "2. example bytes change -> MODIFIED"
printf 'sh tool.sh # edited\n' > examples/greet.sh
"$XV" check | grep -q "^MODIFIED  greet" && ok "modified detected" || no "modified"
"$XV" check --strict >/dev/null; [ $? -eq 1 ] && ok "--strict exits 1" || no "strict"
"$XV" run >/dev/null  # re-attest

echo "3. version drift -> STALE"
echo 1.1.0 > VERSION
"$XV" check | grep -q "^STALE     greet.*attested v=1.0.0 installed v=1.1.0" && ok "stale on version bump" || no "stale"
"$XV" run >/dev/null

echo "4. behavior drift with same version -> rerun FAILED (docs lie)"
printf '#!/bin/sh\necho "changed output"\n' > tool.sh
"$XV" check | grep -q "^VERIFIED  greet" && ok "static check can't see it (by design)" || no "static"
"$XV" check --rerun | grep -q "^FAILED    greet.*output differs" && ok "rerun catches it" || no "rerun fail"

echo "5. failing example is attested as failing, never VERIFIED"
printf 'exit 3\n' > examples/two.sh
"$XV" run >/dev/null; [ $? -eq 1 ] && ok "run exits 1 when an example fails" || no "run rc"
"$XV" check | grep -q "^FAILED    two.*attested exit=3" && ok "failed attestation surfaces" || no "attested fail"

echo "6. example without attestation -> MISSING"
printf 'echo three\n' > examples/three.sh
python3 - <<'EOF'
import json;m=json.load(open('examples/manifest.json'));m['examples'].append({"id":"three","path":"examples/three.sh","command":"sh examples/three.sh"});json.dump(m,open('examples/manifest.json','w'))
EOF
"$XV" check | grep -q "^MISSING   three" && ok "missing" || no "missing"

echo "7. llms stanza"
"$XV" llms | grep -q "## Verified examples" && "$XV" llms | grep -q "attest.json" && ok "llms.txt stanza" || no "llms"

echo; echo "pass=$pass fail=$fail"
[ $fail -eq 0 ]
