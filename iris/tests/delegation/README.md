# Registered-agent delegation tests

**English** | [Español](README_es.md)

Run only in a disposable container without persistent volumes. Tests create
agents, models and user permissions using the real AI Hub SDK and a local HTTP
LLM fixture. No external provider or credentials are used.

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-delegation-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Wait for IRIS startup before continuing.
docker cp iris-demo/src/App/Demo ai-orchestrator-delegation-test:/tmp/test-demo
docker cp iris/tests/delegation ai-orchestrator-delegation-test:/tmp/delegation-tests
docker exec -d ai-orchestrator-delegation-test python3 /tmp/delegation-tests/mock-llm.py
Get-Content -Raw iris/tests/delegation/run.script | docker exec -i ai-orchestrator-delegation-test iris session IRIS
docker rm -f ai-orchestrator-delegation-test
```

Expected marker: `DELEGATION_FAILURES=0`. Business tools are loaded explicitly as
test fixtures; they are not included in the core image. Assertions cover assignment
persistence and partial updates; invalid references, duplicates and cycles;
discovery; user authorization and revocation; separate model/instruction/session
state; coordinator → specialist → inventory calls followed by a local call;
agent audit correlation; context restoration; depth and call budgets; native
statistics through the interoperability response, cumulative statistics across
session reload and independent statistics in a new conversation.

Specialists run in separate IRIS jobs to avoid native runtime re-entry from a
tool callback. No BPL or running production is required. Temporary results are
removed on completion or after a 120-second caller timeout; a timed-out worker
may finish later, but its late result is discarded. Limits are three delegation
levels and sixteen delegated calls per request.

`nginx.conf` supports UI checks on an isolated Docker network with the IRIS alias
`delegation-iris`, without changing the normal deployment.
