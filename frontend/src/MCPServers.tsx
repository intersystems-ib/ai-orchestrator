import { FormEvent, ReactNode, useCallback, useEffect, useRef, useState } from "react";
import { useI18n } from "./i18n";

type Server = {
  id: number; name: string; displayName: string; description: string;
  endpointUrl: string; transport: string; authMode: string; bearerSecret: string;
  status: string; enabled: boolean; createdAt: string;
  lastDiscoveryAt?: string;
};
type RemoteTool = {name: string; remoteName: string; description: string; schema: string; status: string; enabled: boolean; available: boolean};
type Request = <T>(path: string, options?: RequestInit) => Promise<T>;

export function MCPServersView({request, refresh}: {request: Request; refresh: () => Promise<void>}) {
  const {t} = useI18n();
  const [servers, setServers] = useState<Server[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<Server | null | undefined>(undefined);
  const [selected, setSelected] = useState<Server | null>(null);
  const [tools, setTools] = useState<RemoteTool[]>([]);
  const [search, setSearch] = useState("");
  const [working, setWorking] = useState(false);
  const [notice, setNotice] = useState("");
  const reload = useCallback(async () => {
    setLoading(true);
    try { setServers(await request<Server[]>("/mcp-servers")); setError(""); }
    catch (reason) { setError(reason instanceof Error ? reason.message : t("error.load")); }
    finally { setLoading(false); }
  }, [request, t]);
  useEffect(() => { void reload(); }, [reload]);
  async function loadTools(server: Server, discover: boolean) {
    setWorking(true); setError(""); setNotice(""); setSelected(server); setSearch(""); setTools([]);
    try {
      const path = `/mcp-servers/${encodeURIComponent(server.name)}/tools`;
      if (discover) {
        const result = await request<{tools: RemoteTool[]; created: number; updated: number; unavailable: number}>(`${path}/sync`, {method: "POST", body: "{}"});
        setTools(result.tools);
        setNotice(t("mcp.discovered", {created: result.created, updated: result.updated, unavailable: result.unavailable}));
        await Promise.all([reload(), refresh()]);
      } else {
        setTools(await request<RemoteTool[]>(path));
      }
    } catch (reason) { setError(reason instanceof Error ? reason.message : t("error.load")); }
    finally { setWorking(false); }
  }
  const filtered = tools.filter(tool => `${tool.remoteName} ${tool.name} ${tool.description}`.toLocaleLowerCase().includes(search.toLocaleLowerCase()));
  async function savedServer() {
    await Promise.all([reload(), refresh()]);
    if (selected) {
      try { setTools(await request<RemoteTool[]>(`/mcp-servers/${encodeURIComponent(selected.name)}/tools`)); }
      catch (reason) { setError(reason instanceof Error ? reason.message : t("error.load")); }
    }
  }
  return <>
    <div className="actions"><p>{t("mcp.description")}</p><button className="primary" onClick={() => setEditing(null)}>+ {t("mcp.register")}</button></div>
    {error && !selected && <div className="alert">{error}<button onClick={() => void reload()}>{t("common.retry")}</button></div>}
    {notice && !selected && <p role="status">{notice}</p>}
    <section className="panel table-panel"><table><thead><tr>{["server", "endpoint", "auth", "state", "actions"].map(key => <th key={key}>{t(`mcp.${key}`)}</th>)}</tr></thead>
      <tbody>{servers.map(server => <tr key={server.id}>
        <td><strong>{server.displayName}</strong><small>{server.name}</small><small>{server.description}</small></td>
        <td><code>{server.endpointUrl}</code><small>{server.transport}</small>{server.lastDiscoveryAt && <small>{t("mcp.lastDiscovery")}: {server.lastDiscoveryAt}</small>}</td>
        <td>{t(`mcp.auth.${server.authMode}`)}</td>
        <td><span className={`status status-${server.enabled ? server.status : "suspended"}`}><i/>{t(server.enabled ? `status.${server.status}` : "status.disabled")}</span></td>
        <td><button className="secondary" disabled={working} onClick={() => setEditing(server)}>{t("common.edit")}</button><button className="secondary" disabled={working} onClick={() => void loadTools(server, false)}>{t("mcp.viewTools")}</button><button className="primary" disabled={working || server.status !== "approved" || !server.enabled} onClick={() => void loadTools(server, true)}>{t(working && selected?.name === server.name ? "resource.syncing" : "mcp.discover")}</button></td>
      </tr>)}{!servers.length && <tr><td colSpan={5} className="empty">{t(loading ? "common.connecting" : "mcp.empty")}</td></tr>}</tbody>
    </table></section>
    {selected && <ToolsDialog title={t("mcp.toolsTitle", {server: selected.displayName})} close={() => setSelected(null)}>
      {error && <div className="alert">{error}<button disabled={working} onClick={() => void loadTools(selected, false)}>{t("common.retry")}</button></div>}
      {notice && <p role="status">{notice}</p>}
      <p id="mcp-tools-help">{t("mcp.assignmentHelp")}</p>
      <label className="field"><span>{t("mcp.searchTools")}</span><input type="search" value={search} onChange={event => setSearch(event.target.value)}/></label>
      <section className="panel table-panel mcp-tools-table" aria-busy={working}>
      <table><thead><tr><th>{t("mcp.tool")}</th><th>{t("mcp.schema")}</th><th>{t("mcp.state")}</th></tr></thead><tbody>
        {filtered.map(tool => <tr key={tool.name}><td><strong>{tool.remoteName}</strong><small>{tool.description}</small><code>{tool.name}</code></td><td><details><summary>{t("mcp.viewSchema")}</summary><pre style={{whiteSpace: "pre-wrap", overflowWrap: "anywhere"}}>{JSON.stringify(JSON.parse(tool.schema), null, 2)}</pre></details></td><td><span className={`status status-${tool.enabled ? tool.status : "suspended"}`}><i/>{t(tool.enabled ? `status.${tool.status}` : "status.disabled")}</span>{!tool.available && <small>{t("mcp.unavailable")}</small>}</td></tr>)}
        {!filtered.length && <tr><td colSpan={3} className="empty">{t(working ? "common.connecting" : tools.length ? "mcp.noMatches" : "mcp.noTools")}</td></tr>}
      </tbody></table>
      </section>
    </ToolsDialog>}
    {editing !== undefined && <ServerDialog server={editing} request={request} close={() => setEditing(undefined)} saved={savedServer}/>}
  </>;
}

function ToolsDialog({title, close, children}: {title: string; close: () => void; children: ReactNode}) {
  const {t} = useI18n();
  const dialogRef = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = dialogRef.current!;
    const previousOverflow = document.body.style.overflow;
    dialog.showModal();
    document.body.style.overflow = "hidden";
    return () => {
      dialog.close();
      document.body.style.overflow = previousOverflow;
    };
  }, []);
  return <dialog ref={dialogRef} className="dialog mcp-tools-dialog" aria-labelledby="mcp-tools-title" aria-describedby="mcp-tools-help" onClose={event => {
    if (!event.currentTarget.open) close();
  }} onClick={event => {
    if (event.target !== event.currentTarget) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) close();
  }}>
    <button className="dialog-x" onClick={close} aria-label={t("mcp.closeTools")}>×</button>
    <h2 id="mcp-tools-title">{title}</h2>
    {children}
    <div className="dialog-actions"><button className="secondary" onClick={close}>{t("mcp.closeTools")}</button></div>
  </dialog>;
}

function ServerDialog({server, request, close, saved}: {server: Server | null; request: Request; close: () => void; saved: () => Promise<void>}) {
  const {t} = useI18n();
  const [authMode, setAuthMode] = useState(server?.authMode ?? "none");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setSaving(true); setError("");
    const form = new FormData(event.currentTarget);
    const payload = {...Object.fromEntries(form), transport: "streamable-http", enabled: form.has("enabled"), bearerSecret: authMode === "bearer" ? String(form.get("bearerSecret") ?? "") : ""};
    try {
      await request(server ? `/mcp-servers/${encodeURIComponent(server.name)}` : "/mcp-servers", {method: server ? "PUT" : "POST", body: JSON.stringify(payload)});
      await saved(); close();
    } catch (reason) { setError(reason instanceof Error ? reason.message : t("error.save")); setSaving(false); }
  }
  return <div className="dialog-backdrop"><section className="dialog resource-dialog" role="dialog" aria-modal="true" aria-labelledby="mcp-dialog-title">
    <button className="dialog-x" onClick={close} disabled={saving} aria-label={t("common.cancel")}>×</button>
    <h2 id="mcp-dialog-title">{t(server ? "mcp.edit" : "mcp.register")}</h2><p>{t("mcp.scope")}</p>
    <form onSubmit={submit}><div className="form-grid">
      <label className="field"><span>{t("field.logicalName")}</span><input name="name" maxLength={120} required readOnly={Boolean(server)} defaultValue={server?.name}/></label>
      <label className="field"><span>{t("field.displayName")}</span><input name="displayName" maxLength={200} required defaultValue={server?.displayName}/></label>
      <label className="field wide"><span>{t("mcp.endpoint")}</span><input name="endpointUrl" required maxLength={2000} placeholder="http://iris-mcp-transport:8080/mcp" defaultValue={server?.endpointUrl}/><small>{t("mcp.endpointHelp")}</small></label>
      <label className="field wide"><span>{t("field.description")}</span><textarea name="description" maxLength={1000} rows={3} defaultValue={server?.description}/></label>
      <label className="field"><span>{t("mcp.auth")}</span><select name="authMode" value={authMode} onChange={event => setAuthMode(event.target.value)}><option value="none">{t("mcp.auth.none")}</option><option value="bearer">{t("mcp.auth.bearer")}</option></select></label>
      {authMode === "bearer" && <label className="field"><span>{t("mcp.secret")}</span><input name="bearerSecret" required pattern="secret://.+" placeholder="secret://mcp-token" maxLength={500} defaultValue={server?.bearerSecret} autoComplete="off"/></label>}
      <label className="field"><span>{t("mcp.state")}</span><select name="status" defaultValue={server?.status ?? "draft"}>{["draft", "approved", "suspended", "retired"].map(status => <option key={status} value={status}>{t(`status.${status}`)}</option>)}</select></label>
      <label className="checkbox"><input type="checkbox" name="enabled" defaultChecked={server?.enabled ?? true}/>{t("common.enabled")}</label>
    </div>{error && <p className="form-error">{error}</p>}<div className="dialog-actions"><button type="button" className="secondary" disabled={saving} onClick={close}>{t("common.cancel")}</button><button className="primary" disabled={saving}>{t(saving ? "common.applying" : server ? "common.saveChanges" : "common.register")}</button></div></form>
  </section></div>;
}
