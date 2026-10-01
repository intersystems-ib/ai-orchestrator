Class App.Governance.Catalog
{

/// Provider IDs supported by the AI Hub ObjectScript SDK. Experimental
/// providers are marked so the UI can make lifecycle risk visible.
ClassMethod Providers() As %DynamicArray
{
    set providers = []
    do providers.%Push({"id":"openai","name":"OpenAI","experimental":false,"fields":["api_key","base_url","org_id"]})
    do providers.%Push({"id":"anthropic","name":"Anthropic","experimental":false,"fields":["api_key","base_url","version"]})
    do providers.%Push({"id":"gemini","name":"Google Gemini","experimental":false,"fields":["api_key"]})
    do providers.%Push({"id":"bedrock","name":"AWS Bedrock","experimental":false,"fields":["region","bearer_token"]})
    do providers.%Push({"id":"vertex","name":"Google Vertex","experimental":true,"fields":["project_id","region","service_account_path"]})
    do providers.%Push({"id":"meta","name":"Meta Llama","experimental":true,"fields":["api_key"]})
    do providers.%Push({"id":"nim","name":"NVIDIA NIM","experimental":true,"fields":["base_url","api_key"]})
    do providers.%Push({"id":"xai","name":"xAI","experimental":true,"fields":["api_key"]})
    do providers.%Push({"id":"deepseek","name":"DeepSeek","experimental":true,"fields":["api_key","base_url"]})
    do providers.%Push({"id":"kimi","name":"Kimi / Moonshot AI","experimental":true,"fields":["api_key","base_url"]})
    do providers.%Push({"id":"openrouter","name":"OpenRouter","experimental":true,"fields":["api_key","site_url","site_name","base_url"]})
    do providers.%Push({"id":"ollama","name":"Ollama","experimental":true,"fields":["base_url"]})
    quit providers
}

ClassMethod IsProviderSupported(provider As %String) As %Boolean
{
    set supported = ",openai,anthropic,gemini,bedrock,vertex,meta,nim,xai,deepseek,kimi,openrouter,ollama,"
    quit ($FIND(supported, "," _ provider _ ",") > 0)
}

}

