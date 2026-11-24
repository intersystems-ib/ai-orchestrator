# Modelos locales

[English](README.md) | **Español**

Los archivos GGUF no se versionan. Coloca los dos archivos indicados en el `.env`
raíz en esta carpeta antes de iniciar el perfil opcional `ai`. Compose monta la
carpeta en modo de solo lectura dentro de ambos contenedores llama.cpp.

| Servicio | Variable de archivo (predeterminado) | Alias | Variable de contexto (predeterminado) | API del host |
|---|---|---|---|---|
| `llama` | `LLM_MODEL_FILE` (`Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf`) | `LLM_MODEL_ALIAS=llama-3.1-8b-instruct` | `LLM_CONTEXT_SIZE=16384` | `http://localhost:8000/v1` |
| `qwen` | `QWEN_MODEL_FILE` (`Qwen3.5-9B-Q5_K_M.gguf`) | `QWEN_MODEL_ALIAS=qwen3.5-9b` | `QWEN_CONTEXT_SIZE=4096` | `http://localhost:8001/v1` |

La plantilla de Llama se selecciona con `LLM_CHAT_TEMPLATE`; el archivo
predeterminado `meta-llama-Llama-3.1-8B-Instruct.jinja` también debe estar aquí.
Los puertos del host se cambian con `LLM_PORT` y `QWEN_PORT`; ambos servicios usan
el puerto 8000 dentro de Docker.

```powershell
docker compose --profile ai up -d llama qwen
# Recrea solo el servidor cuya configuración haya cambiado:
docker compose --profile ai up -d --no-deps llama
```

La temperatura se configura por agente en AI Orchestrator y se envía en cada
petición al modelo. El proyecto no la fija en `.env` ni en los comandos de los
servidores LLM.

El contexto incluye instrucciones, herramientas, historial, resultados y respuesta.
Una ventana mayor necesita más memoria. Cambiarla requiere recrear ese contenedor,
pero conserva las conversaciones de IRIS. Declara la misma capacidad en
`maxContextTokens` del modelo en Orchestrator. El `contextBudget` y la
`responseReserve` del agente deben caber en ella. Un presupuesto 0 hereda la
capacidad menos la reserva; no redimensiona el servidor LLM.

El bootstrap del núcleo no registra estos modelos ni agentes. Registra modelos
aprobados y habilitados con proveedor `nim`, `apiKey: not-needed` y URLs Docker
`http://llama:8000/v1` / `http://qwen:8000/v1`; después asígnalos a agentes y autoriza
usuarios. Consulta la [guía raíz](../README_es.md#modelos-locales-incluidos).
