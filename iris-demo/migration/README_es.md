# Traslado de ejemplos existentes

[English](README.md) | **Español**

Las instalaciones nuevas no necesitan este procedimiento. Utiliza una ventana de
mantenimiento: detén frontend/API y la producción antes de transferir datos.
Los archivos JSONL son temporales de transferencia y verificación; elimínalos al
terminar. No se conserva ninguna copia de seguridad. No recrees el IRIS origen
hasta terminar la exportación y la retirada de sus clases.

1. Copia esta carpeta a `/tmp/demo-migration` del contenedor principal antiguo.
   Ejecuta `export.script` en `iris` y exige `DEMO_EXPORT_OK`.
2. Construye las imágenes e inicia únicamente el nuevo `iris-demo`. Espera a que
   esté saludable; la primera creación del almacenamiento puede tardar varios
   minutos. Copia la carpeta de migración a `/tmp/demo-migration` y transfiere
   `/tmp/demo-data.jsonl` desde el origen a esa misma ruta del destino. Si usas
   un archivo intermedio en el equipo, créalo en una carpeta temporal del sistema.
3. Ejecuta `import.script` en `iris-demo` y exige `DEMO_IMPORT_OK`. Sustituye las
   filas iniciales del nuevo destino, conserva IDs y referencias y reconstruye
   índices. Rechaza una segunda importación; no debe ejecutarse sobre un servidor
   de negocio ya utilizado. Compara el SHA-256 del JSONL original con
   `/tmp/demo-data-verified.jsonl` del destino: deben ser idénticos.
4. Vuelve a exportar el origen para detectar cambios concurrentes y compara su
   huella de nuevo. Solo después guarda la huella verificada en
   `^AppDemoSeparation("dataVerified")` de `APP`. Ejecuta `translate.script` en
   `iris-demo` (`DEMO_TRANSLATION_OK`): traduce únicamente los valores conocidos
   del catálogo de ejemplo, conservando IDs, SKU, stock y nombres personalizados.
5. Inicia `iris-demo-transport`. Copia
   `iris/src/App/AIHub/Upgrade/ExternalizeDemo.cls` a
   `/tmp/demo-migration/ExternalizeDemo.cls` del origen y ejecuta `catalog.script`
   (`DEMO_CATALOG_OK`). Cambia los registros existentes a ejecución MCP sin
   modificar nombres, IDs, estados de aprobación ni asignaciones de agentes.
6. Ejecuta `iris-demo/tests/smoke.ps1`. Copia el nuevo
   `iris/src/App/AIHub/Bootstrap.cls` a `/tmp/demo-migration/Bootstrap.cls` del
   principal. Ejecuta `cleanup.script` (`DEMO_CLEANUP_OK`): exige los marcadores,
   vacía las tres tablas originales, elimina `App.Demo` y sincroniza el catálogo.
   Se retiran también los marcadores temporales.
7. Recrea `iris` con la imagen nueva y reinicia producción, webgateway y frontend.
   Verifica cero clases `App.Demo` y ningún dato en `^App.Demo.InventoryD` del
   núcleo. El destino conserva los recuentos originales.
8. Recrea `iris-mcp`, copia esta carpeta a `/tmp/demo-migration` y ejecuta
   `prices.script` (`DEMO_PRICES_TRANSLATION_OK`). Traduce las cotizaciones conocidas,
   conserva fechas/importes y añade los días recientes que falten. Reinicia su
   transporte y redescubre el catálogo para actualizar descripciones.
9. Elimina los JSONL de transferencia, directorios `/tmp/demo-migration` y clases
   `Demo.Migration.LegacyData` temporales de los tres namespaces. Elimina también
   cualquier archivo intermedio del equipo. Los auxiliares no se incluyen en las
   imágenes ni se publican como herramientas MCP.

Ejemplo para ejecutar un script:

```powershell
Get-Content -Raw iris-demo/migration/import.script | docker compose exec -T iris-demo iris session IRIS
```

Los scripts establecen su namespace. Los nombres de contenedor siguen
`COMPOSE_PROJECT_NAME` (por defecto `ai-orchestrator`); adapta los comandos
`docker cp` cuando cambie ese prefijo. Si falla cualquier paso, detente y resuelve
el error antes de continuar con la retirada del origen.
