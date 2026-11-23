# BPL agent operation tests

**English** | [Español](README_es.md)

Run only in a disposable container without persistent volumes. The suite creates
catalog records, grants test users and `_Ensemble` access, and replaces the active
production. Its local HTTP fixture simulates the LLM without external credentials
or provider calls.

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-bpl-test ai-orchestrator-iris --check-caps false --ISCAgent false
# Wait for IRIS startup before continuing.
docker cp iris-demo/src/App/Demo ai-orchestrator-bpl-test:/tmp/test-demo
docker cp iris/tests/bpl-agent ai-orchestrator-bpl-test:/tmp/bpl-agent-tests
docker exec -d ai-orchestrator-bpl-test python3 /tmp/bpl-agent-tests/mock-llm.py
Get-Content -Raw iris/tests/bpl-agent/run.script | docker exec -i ai-orchestrator-bpl-test iris session IRIS
docker rm -f ai-orchestrator-bpl-test
```

Expected markers: `DIRECT_AGENT_OK`, `QUEUED_BPL_OK`, `BPL_AGENT_FAILURES=0`.
Business classes are explicit fixtures loaded into this disposable instance;
the production Orchestrator image contains no inventory or shipment examples.

The suite checks negative cases and a real
`Business Service → BPL → AgentOperation → AI Hub → inventory tool` flow,
including its response, audit and interoperability trace. `Process.cls` is a
minimal BPL taking and returning string messages. `Production.cls` configures
its operation through the single agent-selection setting `AgentName`.
