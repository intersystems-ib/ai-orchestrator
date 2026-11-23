# Context budget tests

**English** | [Español](README_es.md)

Run only in a disposable IRIS instance, without persistent volumes. The local
HTTP fixture verifies response limits, summary calls without tools, recovery of
oversized history, continued sessions, transcript/statistics preservation,
invalid configuration, and failure without loss of persisted state.

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-context-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Wait for the IRIS startup-complete message before continuing.
docker cp iris/tests/context-budget ai-orchestrator-context-test:/tmp/context-tests
docker exec -d ai-orchestrator-context-test python3 /tmp/context-tests/mock-llm.py
Get-Content -Raw iris/tests/context-budget/run.script | docker exec -i ai-orchestrator-context-test iris session IRIS
docker rm -f ai-orchestrator-context-test
```

Expected marker: `CONTEXT_BUDGET_FAILURES=0`.

Assertions distinguish successful SDK summarization, explicit provider context
overflow with block recovery, an oversized retained message after a successful
SDK summary, and generic provider errors without block retries.

The optional real-provider probe requires Llama with **16384 tokens**. Create the
disposable container with `--network ai-orchestrator_app-network` (adjust for a
different Compose project). After loading the test classes, run:

```powershell
@'
zn "APP"
set failures=##class(App.Test.ContextLlamaProbe).Run()
halt
'@ | docker exec -i ai-orchestrator-context-test iris session IRIS
```

Expected marker: `LLAMA_CONTEXT_PROBE_FAILURES=0`. It tests native summaries with
1000 and 20000 repetitions of ` hello`, records the provider's real context
rejection and verifies block recovery with the order identifier preserved. It
makes local LLM calls without saving sessions or business data. In build 109,
native summarization of the large transcript fails with
`exceed_context_size_error`; the fallback is required for this case.
