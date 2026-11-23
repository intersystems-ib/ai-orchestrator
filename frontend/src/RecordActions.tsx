import { useEffect, useId, useRef, type ButtonHTMLAttributes } from "react";
import { useI18n } from "./i18n";

export function ActionIcon({action, label, ...props}: ButtonHTMLAttributes<HTMLButtonElement> & {action:"edit"|"delete"|"tools"|"discover";label:string}) {
  return <button {...props} type="button" className={`secondary icon-action${action==="delete"?" danger":""}`} aria-label={label} title={label}>
    <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      {action==="edit"?<><path d="m16 3 5 5M4 20l4.5-1 12-12a2.1 2.1 0 0 0-5-3l-12 12L3 21Z"/><path d="M12 21h9"/></>:action==="delete"?<><path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/></>:action==="tools"?<><path d="M9 6h12M9 12h12M9 18h12"/><rect x="3" y="4" width="2" height="4" rx=".5"/><rect x="3" y="10" width="2" height="4" rx=".5"/><rect x="3" y="16" width="2" height="4" rx=".5"/></>:<><path d="M20 4v5h-5M4 20v-5h5"/><path d="M5.5 8a7 7 0 0 1 11.6-3L20 9M4 15l2.9 4A7 7 0 0 0 18.5 16"/></>}
    </svg>
  </button>;
}

export function DeleteRecordDialog({name, displayName, kind, description, busy, error, close, confirm}: {
  name:string;displayName:string;kind:string;description:string;busy:boolean;error:string;close:()=>void;confirm:()=>void;
}) {
  const {t}=useI18n(), id=useId();
  const dialog=useRef<HTMLDialogElement>(null), cancel=useRef<HTMLButtonElement>(null);
  useEffect(()=>{
    const element=dialog.current!, previous=document.activeElement as HTMLElement|null, overflow=document.body.style.overflow;
    element.showModal(); document.body.style.overflow="hidden"; cancel.current?.focus();
    return ()=>{element.close();document.body.style.overflow=overflow;previous?.focus();};
  },[]);
  return <dialog ref={dialog} className="dialog delete-record-dialog" aria-labelledby={`${id}-title`} aria-describedby={`${id}-description`} aria-busy={busy} onCancel={event=>{event.preventDefault();if(!busy)close();}}>
    <p className="eyebrow">{kind}</p>
    <h2 id={`${id}-title`}>{t("delete.title")}</h2>
    <div className="delete-record-identity"><strong>{displayName}</strong><code>{name}</code></div>
    <p id={`${id}-description`}>{description}</p>
    {error&&<p className="form-error" role="alert">{error}</p>}
    <div className="dialog-actions">
      <button ref={cancel} type="button" className="secondary" disabled={busy} onClick={close}>{t("common.cancel")}</button>
      <button type="button" className="secondary danger" disabled={busy} onClick={confirm}>{t(busy?"delete.pending":"delete.confirmAction")}</button>
    </div>
  </dialog>;
}
