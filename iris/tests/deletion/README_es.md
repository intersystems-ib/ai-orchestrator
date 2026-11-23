# Pruebas de eliminación de registros

[English](README.md) | **Español**

Ejecuta solo en una instancia desechable sin volúmenes persistentes:

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-deletion-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Espera al arranque completo de IRIS.
docker cp iris/tests/deletion ai-orchestrator-deletion-test:/tmp/deletion-tests
Get-Content -Raw iris/tests/deletion/run.script | docker exec -i ai-orchestrator-deletion-test iris session IRIS
docker rm -f ai-orchestrator-deletion-test
```

Marcador: `DELETION_FAILURES=0`. Comprueba las dependencias modelo/agente,
herramienta MCP/agente, delegados y producciones; la retirada de asignaciones y
configuración del modelo; la conservación de conversaciones y el error 404 al
repetir una eliminación.
