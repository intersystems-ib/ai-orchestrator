# Local models

**English** | [Español](README_es.md)

GGUF files are not versioned. Place both files selected by the root `.env` in
this directory before starting the optional `ai` profile. Compose mounts this
folder read-only into the two llama.cpp containers.

| Service | File variable (default) | Alias | Context variable (default) | Host API |
|---|---|---|---|---|
| `llama` | `LLM_MODEL_FILE` (`Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf`) | `LLM_MODEL_ALIAS=llama-3.1-8b-instruct` | `LLM_CONTEXT_SIZE=16384` | `http://localhost:8000/v1` |
| `qwen` | `QWEN_MODEL_FILE` (`Qwen3.5-9B-Q5_K_M.gguf`) | `QWEN_MODEL_ALIAS=qwen3.5-9b` | `QWEN_CONTEXT_SIZE=4096` | `http://localhost:8001/v1` |

The Llama chat template is selected by `LLM_CHAT_TEMPLATE`; the default file
`meta-llama-Llama-3.1-8B-Instruct.jinja` must also be present here. Host ports are
configurable with `LLM_PORT` and `QWEN_PORT`; both servers use port 8000 internally.

```powershell
docker compose --profile ai up -d llama qwen
# Recreate only the server whose configuration changed:
docker compose --profile ai up -d --no-deps llama
```

Temperature is configured per agent in AI Orchestrator and sent with each
model request. The project does not set it in `.env` or the LLM server commands.

Context includes instructions, tool definitions, history, tool results and the
generated answer. Larger windows require more memory. A server context change
requires recreating that container; it does not delete conversations in IRIS.
Declare the same serving capacity in the Orchestrator model's `maxContextTokens`.
The agent's `contextBudget` and `responseReserve` must fit that capacity. A budget
of 0 inherits capacity minus the reserve; it does not resize the LLM server.

The core bootstrap does not register these models or agents. Register approved,
enabled models with provider `nim`, `apiKey: not-needed` and Docker base URLs
`http://llama:8000/v1` / `http://qwen:8000/v1`, then assign models to agents and
authorize users. See the [root configuration guide](../README.md#included-local-models).
