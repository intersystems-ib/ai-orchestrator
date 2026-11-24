# Delegación entre agentes registrados

[English](README.md) | **Español**

Prueba de integración con el SDK real de AI Hub y un proveedor HTTP local
determinista. No utiliza credenciales ni modelos externos. Ejecutar únicamente
en un contenedor temporal sin volúmenes persistentes; crea agentes, modelos y
permisos de prueba.

```powershell
docker compose build iris
docker run -d --name ai-orchestrator-delegation-test -e ISC_CPF_MERGE_FILE= ai-orchestrator-iris --check-caps false --ISCAgent false
# Esperar a que la instancia termine de arrancar.
docker cp iris-demo/src/App/Demo ai-orchestrator-delegation-test:/tmp/test-demo
docker cp iris/tests/delegation ai-orchestrator-delegation-test:/tmp/delegation-tests
docker exec -d ai-orchestrator-delegation-test python3 /tmp/delegation-tests/mock-llm.py
Get-Content -Raw iris/tests/delegation/run.script | docker exec -i ai-orchestrator-delegation-test iris session IRIS
docker rm -f ai-orchestrator-delegation-test
```

Resultado esperado: `DELEGATION_FAILURES=0`. La prueba comprueba:

- Persistencia y actualización parcial de las asignaciones, referencias inválidas,
  duplicados, autorreferencias y ciclos.
- Catálogo de herramientas del coordinador con una herramienta por agente delegado.
- Autorización del usuario en ambos agentes y revocación durante la ejecución.
- Conversaciones e instrucciones independientes y uso del modelo del especialista.
- Llamada real coordinador → herramienta → especialista → inventario y continuación
  del coordinador con una herramienta propia.
- Auditoría atribuida a cada agente, correlacionada con el mismo RequestId.
- Restauración del contexto tras errores y límites de profundidad y llamadas.
- Estadísticas nativas incluidas en la respuesta, acumulación de tokens e
  interacciones al recargar una conversación y estadísticas independientes en
  una conversación nueva, sin sumar las sesiones de los agentes delegados.

El especialista se ejecuta en otro job IRIS para evitar reentrar en el runtime
nativo del proveedor durante un callback de herramienta. No necesita una producción
de interoperabilidad ni un BPL. Los resultados temporales se eliminan al volver o
al vencer el tiempo de espera de 120 segundos. Los límites actuales son tres
niveles de delegación y dieciséis llamadas delegadas por petición.

`nginx.conf` permite revisar el frontal en una red Docker temporal cuyo servidor
IRIS tenga el alias `delegation-iris`; no cambia la configuración del despliegue.
