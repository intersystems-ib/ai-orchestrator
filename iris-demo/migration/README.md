# Moving existing examples

**English** | [Español](README_es.md)

Fresh installations do not need this procedure. Stop frontend/API traffic and the
interoperability production for maintenance. JSONL files are temporary transfer
and verification files: delete them when finished. No backup copies are retained.
Keep the original core container until export and class removal are complete.

1. Copy this folder to `/tmp/demo-migration` in the old core container. Run
   `export.script` in `iris` and require `DEMO_EXPORT_OK`.
2. Build the images and start only the new `iris-demo`. Wait until healthy; its
   first durable-storage clone may take several minutes. Copy the migration
   folder to `/tmp/demo-migration` and transfer `/tmp/demo-data.jsonl` from the
   source to the same destination path. Any host intermediary belongs in a
   temporary system directory.
3. Run `import.script` in `iris-demo` and require `DEMO_IMPORT_OK`. It replaces the
   new destination's seed rows, preserves IDs/references and rebuilds indexes.
   It refuses a second import; never run it on an established business server.
   Compare SHA-256 of the source JSONL and the destination's
   `/tmp/demo-data-verified.jsonl`: they must match exactly.
4. Export the source again to detect concurrent changes and compare its hash.
   Only then store the verified hash in `^AppDemoSeparation("dataVerified")` in
   `APP`. Run `translate.script` in `iris-demo` (`DEMO_TRANSLATION_OK`). It renames
   only known sample values, retaining IDs, SKU, stock and custom names.
5. Start `iris-demo-transport`. Copy
   `iris/src/App/AIHub/Upgrade/ExternalizeDemo.cls` to
   `/tmp/demo-migration/ExternalizeDemo.cls` in the core and run `catalog.script`
   (`DEMO_CATALOG_OK`). Existing tool records switch to MCP while names, IDs,
   approval states and agent assignments stay unchanged.
6. Run `iris-demo/tests/smoke.ps1`. Copy the new core
   `iris/src/App/AIHub/Bootstrap.cls` to `/tmp/demo-migration/Bootstrap.cls` there.
   Run `cleanup.script` (`DEMO_CLEANUP_OK`): it requires the verification markers,
   purges the three original extents, removes `App.Demo` and synchronizes local
   tools. Temporary migration markers are removed too.
7. Recreate `iris` with the new image and restart production, webgateway and
   frontend. Verify zero core `App.Demo` classes and no `^App.Demo.InventoryD`
   data. The destination retains the original row counts.
8. Recreate `iris-mcp`, copy this folder to `/tmp/demo-migration` and run
   `prices.script` (`DEMO_PRICES_TRANSLATION_OK`). It translates known quotation
   names, retains dates/amounts and seeds missing recent days. Restart its
   transport and rediscover the catalog to refresh descriptions.
9. Delete all transfer JSONL files, `/tmp/demo-migration` directories and temporary
   `Demo.Migration.LegacyData` classes from all three namespaces. Delete host
   intermediary files too. Migration helpers are neither image contents nor MCP tools.

Example script invocation:

```powershell
Get-Content -Raw iris-demo/migration/import.script | docker compose exec -T iris-demo iris session IRIS
```

Scripts select their own namespace. Container names follow `COMPOSE_PROJECT_NAME`
(default `ai-orchestrator`); adapt `docker cp` commands when changing that prefix.
If any step fails, stop and resolve it before continuing with source removal.
