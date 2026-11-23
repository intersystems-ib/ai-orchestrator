# Local models

**English** | [Español](README_es.md)

GGUF files are not versioned. Place the model selected by `LLM_MODEL_FILE` in
`.env` in this directory before starting the `ai` profile.

Llama uses `LLM_CONTEXT_SIZE=16384` tokens by default. This window holds the
instructions, tool definitions, conversation history, tool results and generated
answer. Increase it in `.env` if agent requests exceed the available context;
larger values require more memory. Apply the change with
`docker compose --profile ai up -d --no-deps llama`. Existing conversations are
preserved; starting a new conversation reduces accumulated history.
