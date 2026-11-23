# Modelos locales

[English](README.md) | **Español**

Los archivos `*.gguf` no se versionan. Coloca aquí el modelo indicado por
`LLM_MODEL_FILE` en `.env` antes de iniciar el perfil `ai`.

Llama utiliza por defecto `LLM_CONTEXT_SIZE=16384` tokens. Esta ventana incluye
las instrucciones, las definiciones de herramientas, el historial, los resultados
de las herramientas y la respuesta generada. Aumenta el valor en `.env` si las
peticiones superan el contexto disponible; un valor mayor requiere más memoria.
Aplica el cambio con `docker compose --profile ai up -d --no-deps llama`.
Se conservan las conversaciones existentes; iniciar una nueva reduce el historial
acumulado.

