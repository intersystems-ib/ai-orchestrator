# Registry deletion tests

**English** | [Español](README_es.md)

Run only in a disposable instance without persistent volumes:

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-deletion-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Wait for IRIS startup to complete.
docker cp iris/tests/deletion ai-orchestrator-deletion-test:/tmp/deletion-tests
Get-Content -Raw iris/tests/deletion/run.script | docker exec -i ai-orchestrator-deletion-test iris session IRIS
docker rm -f ai-orchestrator-deletion-test
```

Expected: `DELETION_FAILURES=0`. Checks model/agent, MCP tool/agent, delegate and
production dependencies, cleanup of assignments and model configuration,
preservation of conversations, and repeated deletion returning 404.
