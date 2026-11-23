# Prueba de la operación de agentes desde BPL

[English](README.md) | **Español**

Ejecutar sólo en un contenedor temporal sin volúmenes persistentes. La prueba
crea registros del catálogo, autoriza al usuario de pruebas y a `_Ensemble`,
y sustituye la producción activa. El servidor HTTP simula el LLM dentro del
contenedor, sin credenciales ni llamadas a proveedores externos.

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-bpl-test ai-orchestrator-iris --check-caps false --ISCAgent false
docker cp iris-demo/src/App/Demo ai-orchestrator-bpl-test:/tmp/test-demo
docker cp iris/tests/bpl-agent ai-orchestrator-bpl-test:/tmp/bpl-agent-tests
docker exec -d ai-orchestrator-bpl-test python3 /tmp/bpl-agent-tests/mock-llm.py
Get-Content -Raw iris/tests/bpl-agent/run.script | docker exec -i ai-orchestrator-bpl-test iris session IRIS
docker rm -f ai-orchestrator-bpl-test
```

El contenedor debe haber terminado de arrancar antes de ejecutar las pruebas.
El resultado esperado es `BPL_AGENT_FAILURES=0`, precedido de `DIRECT_AGENT_OK`
y `QUEUED_BPL_OK`. Además de los casos negativos, se ejecuta una llamada real
`Business Service → BPL → AgentOperation → AI Hub → herramienta de inventario`,
comprobando respuesta, auditoría y traza de interoperabilidad.

`Process.cls` proporciona un ejemplo mínimo compilable de BPL que recibe y
devuelve mensajes de texto. `Production.cls` configura su operación con el
único ajuste específico `AgentName`.
