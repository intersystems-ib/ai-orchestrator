import { createContext, ReactNode, useContext, useEffect, useMemo, useState } from "react";

export type Language = "es" | "en";
type Variables = Record<string, string | number>;
type I18nContextValue = {
  language: Language;
  setLanguage: (language: Language) => void;
  t: (key: string, variables?: Variables) => string;
};

const storageKey = "ai-governance-language";

const es: Record<string, string> = {
  "language.label": "Idioma",
  "language.es": "Español",
  "language.en": "English",
  "nav.overview": "Gobernanza de IA",
  "nav.chat": "Chat de agentes",
  "nav.models": "Catálogo de modelos",
  "nav.tools": "Tools de AI Hub",
  "nav.policies": "Policies",
  "nav.agents": "Agentes",
  "nav.users": "Usuarios IA",
  "nav.audit": "Auditoría",
  "common.controlPlane": "PLANO DE CONTROL",
  "common.irisUser": "Usuario IRIS",
  "common.authorizedUser": "Usuario autorizado",
  "common.noAgentAccess": "Sin acceso a agentes",
  "common.connecting": "Conectando...",
  "common.logout": "Salir",
  "common.retry": "Reintentar",
  "common.cancel": "Cancelar",
  "common.apply": "Aplicar",
  "common.applying": "Guardando...",
  "common.edit": "Editar",
  "common.register": "Registrar",
  "common.saveChanges": "Guardar cambios",
  "common.none": "Ninguna",
  "common.select": "Selecciona...",
  "common.enabled": "Habilitado",
  "common.created": "Creado",
  "common.experimental": "experimental",
  "common.noResources": "No hay recursos disponibles.",
  "common.noApprovedResources": "No hay recursos aprobados.",
  "error.token": "No se pudo obtener el token de IRIS",
  "error.expired": "La sesión JWT ha caducado",
  "error.noSession": "No hay una sesión JWT activa",
  "error.load": "No se pudo cargar la plataforma",
  "error.login": "No se pudo iniciar sesión",
  "error.chat": "No se pudo completar el chat",
  "error.user": "No se pudo actualizar el usuario",
  "error.userAgents": "No se pudieron asignar los agentes",
  "error.save": "No se pudo guardar el recurso",
  "login.eyebrow": "INTERSYSTEMS IRIS JWT",
  "login.description": "IRIS emitirá un JWT firmado. Las policies decidirán qué agentes puede utilizar el sujeto autenticado.",
  "login.username": "Usuario IRIS",
  "login.password": "Contraseña",
  "login.loading": "Solicitando JWT...",
  "login.submit": "Entrar",
  "overview.eyebrow": "PLATAFORMA DE AGENTES",
  "overview.title": "Controla qué modelos razonan y qué herramientas pueden ejecutar.",
  "overview.description": "Los métodos ObjectScript publicados por clases %AI.Tool se descubren directamente desde AI Hub. Cada agente recibe solo los métodos asignados y sus policies.",
  "overview.hubActive": "AI Hub activo",
  "overview.nativeGovernance": "Gobierno nativo dentro de IRIS",
  "overview.activeModels": "Modelos activos",
  "overview.publishableTools": "Tools publicables",
  "overview.activePolicies": "Policies activas",
  "overview.activeAgents": "Agentes activos",
  "overview.approvedEnabled": "aprobados y habilitados",
  "overview.flow": "FLUJO GOBERNADO",
  "overview.fromMethod": "Del método al agente",
  "overview.define": "Definir",
  "overview.discover": "Descubrir",
  "overview.assign": "Asignar",
  "overview.execute": "Ejecutar",
  "overview.namespaceCatalog": "Catálogo del namespace",
  "overview.toolsPolicies": "Tool y policies",
  "audit.date": "Fecha",
  "audit.request": "Petición",
  "audit.agent": "Agente",
  "audit.tool": "Tool",
  "audit.policy": "Policy",
  "audit.duration": "Duración",
  "audit.result": "Resultado",
  "audit.success": "Correcto",
  "audit.error": "Error",
  "audit.empty": "Todavía no hay ejecuciones auditadas.",
  "chat.context": "CONTEXTO DE EJECUCIÓN",
  "chat.agent": "Agente",
  "chat.authorized": "Autorizado para usar IA",
  "chat.denied": "No autorizado",
  "chat.conversation": "Conversación",
  "chat.newConversation": "Nueva conversación",
  "chat.testTitle": "Prueba un agente gobernado",
  "chat.testDescription": "Selecciona un agente y envía un mensaje. IRIS conservará la sesión y aplicará las tools y policies configuradas.",
  "chat.processing": "Procesando...",
  "chat.placeholder": "Escribe un mensaje...",
  "chat.sending": "Enviando...",
  "chat.send": "Enviar",
  "users.description": "Usuarios IRIS y agentes que pueden ejecutar mediante JWT.",
  "users.add": "Dar de alta",
  "users.allowedAgents": "Agentes permitidos",
  "users.registered": "Alta",
  "users.access": "Acceso",
  "users.management": "Gestión",
  "users.createdBy": "Alta por {user}",
  "users.authorized": "Autorizado",
  "users.blocked": "Bloqueado",
  "users.agents": "Agentes",
  "users.block": "Bloquear",
  "users.authorize": "Autorizar",
  "users.empty": "No hay usuarios autorizados.",
  "users.jwtAuthorization": "AUTORIZACIÓN JWT",
  "users.assignmentDescription": "Las policies aplicarán estas asignaciones al sujeto {user}.",
  "resource.models.description": "Cada modelo contiene su configuración de proveedor; los secretos se referencian desde Secure Wallet.",
  "resource.models.action": "Registrar modelo",
  "resource.models.headers": "Modelo|Proveedor|Identificador|Configuración|Estado|Gestión",
  "resource.tools.description": "Métodos publicados por las clases %AI.Tool compiladas en el namespace.",
  "resource.tools.action": "Sincronizar catálogo",
  "resource.tools.headers": "Tool|Implementación|Autorización|Auditoría|Estado|Gestión",
  "resource.policies.description": "Las clases se validan contra el contrato AI Hub del tipo elegido.",
  "resource.policies.action": "Registrar policy",
  "resource.policies.headers": "Policy|Tipo|Clase ObjectScript|Estado",
  "resource.agents.description": "Las tools se asignan en IRIS y se resuelven al materializar cada agente.",
  "resource.agents.action": "Crear agente",
  "resource.agents.headers": "Agente|Modelo|Tools|Policies|Estado|Gestión",
  "resource.syncing": "Sincronizando...",
  "resource.empty": "Todavía no hay recursos registrados.",
  "resource.required": "Requerida",
  "resource.notRequired": "No requerida",
  "resource.iterations": "iter.",
  "dialog.new": "NUEVO RECURSO",
  "dialog.detail": "DETALLE Y EDICIÓN",
  "dialog.model.create": "Registrar modelo",
  "dialog.model.edit": "Editar modelo",
  "dialog.model.subtitle": "La configuración completa del proveedor se conserva de forma segura en IRIS Config Store.",
  "dialog.tool.create": "Tool",
  "dialog.tool.edit": "Editar tool",
  "dialog.tool.subtitle": "La implementación descubierta es inmutable; su gobierno y metadatos sí pueden editarse.",
  "dialog.policy.create": "Registrar policy",
  "dialog.policy.edit": "Editar policy",
  "dialog.policy.subtitle": "Se valida la herencia según su tipo.",
  "dialog.agent.create": "Crear agente",
  "dialog.agent.edit": "Editar agente",
  "dialog.agent.subtitle": "Configura el modelo, parámetros, tools y policies en una única operación.",
  "field.logicalName": "Nombre lógico",
  "field.displayName": "Nombre visible",
  "field.objectScriptClass": "Clase ObjectScript",
  "field.method": "Método",
  "field.description": "Descripción",
  "field.requiresApproval": "Requiere autorización explícita",
  "field.discoveredDescriptor": "Descriptor descubierto (JSON)",
  "field.auditPolicies": "Policies de auditoría",
  "field.type": "Tipo",
  "field.model": "Modelo",
  "field.temperature": "Temperatura",
  "field.maxIterations": "Máx. iteraciones",
  "field.systemPrompt": "System prompt",
  "field.allowedTools": "Tools permitidas",
  "field.globalPolicies": "Policies globales",
  "field.provider": "Proveedor",
  "field.modelId": "Model ID",
  "field.status": "Estado",
  "field.apiVersion": "Versión de API",
  "field.region": "Región",
  "field.serviceAccountPath": "Ruta de service account",
  "field.siteUrl": "URL del sitio",
  "field.siteName": "Nombre del sitio",
  "status.draft": "Borrador",
  "status.approved": "Aprobado",
  "status.suspended": "Suspendido",
  "status.retired": "Retirado",
  "status.disabled": "Deshabilitado",
  "type.authorization": "Autorización",
  "type.audit": "Auditoría",
  "type.discovery": "Descubrimiento"
};

const en: Record<string, string> = {
  ...es,
  "language.label": "Language", "language.es": "Español", "language.en": "English",
  "nav.overview": "AI Governance", "nav.chat": "Agent chat", "nav.models": "Model catalog", "nav.tools": "AI Hub tools", "nav.policies": "Policies", "nav.agents": "Agents", "nav.users": "AI users", "nav.audit": "Audit",
  "common.controlPlane": "CONTROL PLANE", "common.irisUser": "IRIS user", "common.authorizedUser": "Authorized user", "common.noAgentAccess": "No agent access", "common.connecting": "Connecting...", "common.logout": "Sign out", "common.retry": "Retry", "common.cancel": "Cancel", "common.apply": "Apply", "common.applying": "Saving...", "common.edit": "Edit", "common.register": "Register", "common.saveChanges": "Save changes", "common.none": "None", "common.select": "Select...", "common.enabled": "Enabled", "common.created": "Created", "common.experimental": "experimental", "common.noResources": "No resources are available.", "common.noApprovedResources": "No approved resources are available.",
  "error.token": "Could not obtain an IRIS token", "error.expired": "The JWT session has expired", "error.noSession": "There is no active JWT session", "error.load": "Could not load the platform", "error.login": "Could not sign in", "error.chat": "Could not complete the chat request", "error.user": "Could not update the user", "error.userAgents": "Could not assign the agents", "error.save": "Could not save the resource",
  "login.description": "IRIS will issue a signed JWT. Policies determine which agents the authenticated subject may use.", "login.username": "IRIS user", "login.password": "Password", "login.loading": "Requesting JWT...", "login.submit": "Sign in",
  "overview.eyebrow": "AGENT PLATFORM", "overview.title": "Control which models reason and which tools they can execute.", "overview.description": "ObjectScript methods published by %AI.Tool classes are discovered directly from AI Hub. Each agent receives only its assigned methods and policies.", "overview.hubActive": "AI Hub active", "overview.nativeGovernance": "Native governance inside IRIS", "overview.activeModels": "Active models", "overview.publishableTools": "Publishable tools", "overview.activePolicies": "Active policies", "overview.activeAgents": "Active agents", "overview.approvedEnabled": "approved and enabled", "overview.flow": "GOVERNED FLOW", "overview.fromMethod": "From method to agent", "overview.define": "Define", "overview.discover": "Discover", "overview.assign": "Assign", "overview.execute": "Execute", "overview.namespaceCatalog": "Namespace catalog", "overview.toolsPolicies": "Tool and policies",
  "audit.date": "Date", "audit.request": "Request", "audit.agent": "Agent", "audit.tool": "Tool", "audit.policy": "Policy", "audit.duration": "Duration", "audit.result": "Result", "audit.success": "Success", "audit.empty": "There are no audited executions yet.",
  "chat.context": "EXECUTION CONTEXT", "chat.agent": "Agent", "chat.authorized": "Authorized to use AI", "chat.denied": "Not authorized", "chat.conversation": "Conversation", "chat.newConversation": "New conversation", "chat.testTitle": "Test a governed agent", "chat.testDescription": "Select an agent and send a message. IRIS will retain the session and apply the configured tools and policies.", "chat.processing": "Processing...", "chat.placeholder": "Write a message...", "chat.sending": "Sending...", "chat.send": "Send",
  "users.description": "IRIS users and the agents they may execute through JWT.", "users.add": "Add user", "users.allowedAgents": "Allowed agents", "users.registered": "Registered", "users.access": "Access", "users.management": "Management", "users.createdBy": "Added by {user}", "users.authorized": "Authorized", "users.blocked": "Blocked", "users.agents": "Agents", "users.block": "Block", "users.authorize": "Authorize", "users.empty": "There are no authorized users.", "users.jwtAuthorization": "JWT AUTHORIZATION", "users.assignmentDescription": "Policies will apply these assignments to subject {user}.",
  "resource.models.description": "Each model contains its provider configuration; secrets are referenced from Secure Wallet.", "resource.models.action": "Register model", "resource.models.headers": "Model|Provider|Identifier|Configuration|Status|Management", "resource.tools.description": "Methods published by %AI.Tool classes compiled in the namespace.", "resource.tools.action": "Synchronize catalog", "resource.tools.headers": "Tool|Implementation|Authorization|Audit|Status|Management", "resource.policies.description": "Classes are validated against the selected AI Hub contract.", "resource.policies.action": "Register policy", "resource.policies.headers": "Policy|Type|ObjectScript class|Status", "resource.agents.description": "Tools are assigned in IRIS and resolved when each agent is materialized.", "resource.agents.action": "Create agent", "resource.agents.headers": "Agent|Model|Tools|Policies|Status|Management", "resource.syncing": "Synchronizing...", "resource.empty": "There are no registered resources yet.", "resource.required": "Required", "resource.notRequired": "Not required", "resource.iterations": "iter.",
  "dialog.new": "NEW RESOURCE", "dialog.detail": "DETAILS AND EDITING", "dialog.model.create": "Register model", "dialog.model.edit": "Edit model", "dialog.model.subtitle": "The complete provider configuration is stored securely in IRIS Config Store.", "dialog.tool.edit": "Edit tool", "dialog.tool.subtitle": "The discovered implementation is immutable; its governance and metadata can be edited.", "dialog.policy.create": "Register policy", "dialog.policy.edit": "Edit policy", "dialog.policy.subtitle": "Inheritance is validated according to its type.", "dialog.agent.create": "Create agent", "dialog.agent.edit": "Edit agent", "dialog.agent.subtitle": "Configure the model, parameters, tools, and policies in a single operation.",
  "field.logicalName": "Logical name", "field.displayName": "Display name", "field.objectScriptClass": "ObjectScript class", "field.method": "Method", "field.description": "Description", "field.requiresApproval": "Requires explicit approval", "field.discoveredDescriptor": "Discovered descriptor (JSON)", "field.auditPolicies": "Audit policies", "field.type": "Type", "field.model": "Model", "field.temperature": "Temperature", "field.maxIterations": "Max. iterations", "field.systemPrompt": "System prompt", "field.allowedTools": "Allowed tools", "field.globalPolicies": "Global policies", "field.provider": "Provider", "field.status": "Status", "field.apiVersion": "API version", "field.region": "Region", "field.serviceAccountPath": "Service account path", "field.siteUrl": "Site URL", "field.siteName": "Site name",
  "status.draft": "Draft", "status.approved": "Approved", "status.suspended": "Suspended", "status.retired": "Retired", "status.disabled": "Disabled", "type.authorization": "Authorization", "type.audit": "Audit", "type.discovery": "Discovery"
};

const catalogs: Record<Language, Record<string, string>> = { es, en };

function initialLanguage(): Language {
  const saved = localStorage.getItem(storageKey);
  if (saved === "es" || saved === "en") return saved;
  return navigator.language.toLowerCase().startsWith("es") ? "es" : "en";
}

function translate(language: Language, key: string, variables?: Variables): string {
  const template = catalogs[language][key] ?? catalogs.es[key] ?? key;
  return template.replace(/\{(\w+)\}/g, (_, name: string) => String(variables?.[name] ?? `{${name}}`));
}

export function translateCurrent(key: string, variables?: Variables): string {
  return translate(initialLanguage(), key, variables);
}

const I18nContext = createContext<I18nContextValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [language, setLanguage] = useState<Language>(initialLanguage);
  useEffect(() => {
    localStorage.setItem(storageKey, language);
    document.documentElement.lang = language;
  }, [language]);
  const value = useMemo<I18nContextValue>(() => ({ language, setLanguage, t: (key, variables) => translate(language, key, variables) }), [language]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const value = useContext(I18nContext);
  if (!value) throw new Error("useI18n must be used inside I18nProvider");
  return value;
}

export function LanguageSwitcher({ compact = false }: { compact?: boolean }) {
  const { language, setLanguage, t } = useI18n();
  return <div className={`language-switcher${compact ? " compact" : ""}`} role="group" aria-label={t("language.label")}>
    {(["es", "en"] as Language[]).map(option => <button key={option} type="button" className={language === option ? "active" : ""} onClick={() => setLanguage(option)} aria-pressed={language === option}>{compact ? option.toUpperCase() : t(`language.${option}`)}</button>)}
  </div>;
}
