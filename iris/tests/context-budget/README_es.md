# Pruebas de presupuesto de contexto

[English](README.md) | **Español**

Ejecuta únicamente en una instancia desechable, sin volúmenes persistentes.
El proveedor HTTP local verifica la reserva de respuesta, los resúmenes sin
herramientas, la recuperación de historiales demasiado grandes, la continuidad
de la sesión, la conservación del transcript y las estadísticas, las
configuraciones inválidas y los fallos sin pérdida del estado persistido.

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-context-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Espera al mensaje de arranque completo de IRIS antes de continuar.
docker cp iris/tests/context-budget ai-orchestrator-context-test:/tmp/context-tests
docker exec -d ai-orchestrator-context-test python3 /tmp/context-tests/mock-llm.py
Get-Content -Raw iris/tests/context-budget/run.script | docker exec -i ai-orchestrator-context-test iris session IRIS
docker rm -f ai-orchestrator-context-test
```

Marcador esperado: `CONTEXT_BUDGET_FAILURES=0`.

Las pruebas distinguen un resumen nativo que cabe, el exceso de contexto del
proveedor recuperado por bloques, un mensaje retenido demasiado grande tras
resumir y los errores genéricos del proveedor sin reintentos por bloques.

La prueba opcional con el proveedor real requiere Llama con **16384 tokens**.
Crea el contenedor desechable añadiendo `--network ai-orchestrator_app-network`
(ajusta la red si usas otro nombre de proyecto Compose). Tras cargar las clases
de prueba, ejecuta:

```powershell
@'
zn "APP"
set failures=##class(App.Test.ContextLlamaProbe).Run()
halt
'@ | docker exec -i ai-orchestrator-context-test iris session IRIS
```

Marcador esperado: `LLAMA_CONTEXT_PROBE_FAILURES=0`. Prueba el resumen nativo con
1000 y 20000 repeticiones de ` hello`, registra el rechazo real del proveedor y
comprueba la recuperación por bloques conservando el identificador del pedido.
Realiza llamadas al LLM local sin guardar sesiones ni datos de negocio. En la
build 109 el resumen nativo del historial grande falla con
`exceed_context_size_error`; la alternativa es necesaria para ese caso.
