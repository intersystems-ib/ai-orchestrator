import { useI18n } from "./i18n";

export type SessionStats = Partial<Record<
  "total_interactions" | "total_prompt_tokens" | "total_completion_tokens" |
  "total_tool_calls" | "total_llm_duration_ms" | "total_tool_duration_ms" |
  "current_context_tokens" | "model_context_size" | "total_reasoning_tokens" |
  "total_cache_creation_tokens" | "total_cache_read_tokens", number>>;

export type ContextLimits = {inputBudget:number; responseReserve:number; modelCapacity:number; summarized:boolean|number; summaryMethod:"none"|"sdk"|"blocks"; lastSummarizedAt:string; lastSummaryMethod:"sdk"|"blocks"|""; summaryCount:number};

export function SessionStatistics({stats, pending, limits}: {stats: SessionStats | null; pending: boolean; limits?:ContextLimits|null}) {
  const {t, language} = useI18n();
  const format = new Intl.NumberFormat(language, {maximumFractionDigits: 1});
  const value = (key: keyof SessionStats) => {
    const number = stats?.[key];
    return typeof number === "number" && Number.isFinite(number) && number >= 0 ? number : null;
  };
  const number = (key: keyof SessionStats) => {
    const n = value(key);
    return n === null ? "—" : format.format(n);
  };
  const prompt = value("total_prompt_tokens"), completion = value("total_completion_tokens");
  const duration = value("total_llm_duration_ms"), context = value("current_context_tokens"), capacity = limits?.modelCapacity??value("model_context_size");
  const tokens = prompt !== null && completion !== null ? prompt + completion : null;
  const time = (ms: number) => ms < 1000 ? `${format.format(ms)} ms` : `${format.format(ms / 1000)} s`;
  const rate = tokens !== null && duration !== null && duration > 0 ? format.format(tokens / (duration / 1000)) : "—";
  const rows: [string, string][] = [
    ["interactions", number("total_interactions")],
    ["promptTokens", number("total_prompt_tokens")],
    ["completionTokens", number("total_completion_tokens")],
    ["toolCalls", number("total_tool_calls")],
    ["llmTime", duration === null ? "—" : time(duration)],
    ["throughput", rate === "—" ? rate : `${rate} tokens/s`],
    ["contextTokens", number("current_context_tokens")],
    ["contextUsage", context !== null && capacity !== null && capacity > 0 ? `${format.format(context / capacity * 100)} %` : "—"],
  ];
  if(limits) rows.push(["declaredCapacity",format.format(limits.modelCapacity)],["inputBudget",format.format(limits.inputBudget)],["responseReserve",format.format(limits.responseReserve)],["summarized",t(limits.summarized?"common.yes":"common.no")]);
  if(limits) {
    const method=limits.lastSummaryMethod;
    rows.push(["lastSummaryAt",limits.lastSummarizedAt||"—"],["summaryMethod",method==="sdk"?t("chat.stats.methodSDK"):method==="blocks"?t("chat.stats.methodBlocks"):"—"],["summaryCount",format.format(limits.summaryCount)]);
  }
  const extras: [string, keyof SessionStats][] = [["reasoningTokens", "total_reasoning_tokens"], ["cacheRead", "total_cache_read_tokens"], ["cacheCreation", "total_cache_creation_tokens"], ["toolTime", "total_tool_duration_ms"]];
  for (const [label, key] of extras) {
    const n = value(key);
    if (n !== null && n > 0) rows.push([label, key === "total_tool_duration_ms" ? time(n) : format.format(n)]);
  }
  return <section className="chat-statistics" aria-label={t("chat.stats.title")} aria-busy={pending}>
    <h3>{t("chat.stats.title")}</h3>
    {stats||limits ? <><dl>{rows.map(([label, content]) => <div key={label}><dt>{t(`chat.stats.${label}`)}</dt><dd>{content}</dd></div>)}</dl><p>{t("chat.stats.scope")}</p></> : <p>{t("chat.stats.unavailable")}</p>}
  </section>;
}
