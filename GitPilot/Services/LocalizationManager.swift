//
//  LocalizationManager.swift
//  GitPilot
//

import Foundation
import SwiftUI

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Codable {
    case portuguese = "pt-BR"
    case english = "en"
    case spanish = "es"
    
    var displayName: String {
        switch self {
        case .portuguese: return "Português (Brasil)"
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
    
    var flag: String {
        switch self {
        case .portuguese: return "🇧🇷"
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        }
    }
}

// MARK: - Localization Manager

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "pt-BR"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .portuguese
    }
    
    func string(_ key: String) -> String {
        return Strings.localized(key, language: currentLanguage)
    }
}

// MARK: - Strings Dictionary

struct Strings {
    static func localized(_ key: String, language: AppLanguage) -> String {
        switch language {
        case .portuguese: return ptBR[key] ?? key
        case .english: return en[key] ?? key
        case .spanish: return es[key] ?? key
        }
    }
    
    // MARK: - Portuguese (Brazil)
    static let ptBR: [String: String] = [
        // App
        "app.name": "GitPilot",
        "app.open": "Abrir GitPilot",
        "app.quit": "Encerrar",
        "app.settings": "Configurações",
        
        // Settings
        "settings.title": "Configurações",
        "settings.general": "Geral",
        "settings.notifications": "Notificações",
        "settings.telegram": "Telegram",
        "settings.teams": "Teams",
        "settings.data": "Dados",
        "settings.language": "Idioma",
        "settings.launchAtLogin": "Iniciar no Login",
        "settings.showInDock": "Mostrar no Dock",
        "settings.nativeNotifications": "Notificações nativas",
        "settings.notifySuccess": "Notificar sucesso",
        "settings.notifyFailure": "Notificar falha",
        "settings.appBehavior": "Comportamento do App",
        "settings.showInDockHelp": "Mostrar no Dock permite ver o app no Dock e no Command-Tab",
        "settings.permissionRequired": "Permissão de notificação necessária",
        "settings.requestPermission": "Solicitar Permissão",
        "settings.checkUpdates": "Verificar atualizações",
        
        // Status
        "status.idle": "Aguardando",
        "status.checking": "Verificando",
        "status.building": "Compilando",
        "status.success": "Sucesso",
        "status.failed": "Falhou",
        "status.error": "Erro",
        "status.paused": "Pausado",
        "status.monitoring": "Monitorando",
        "status.stopped": "Parado",
        
        // Actions
        "action.add": "Adicionar",
        "action.edit": "Editar",
        "action.delete": "Excluir",
        "action.save": "Salvar",
        "action.cancel": "Cancelar",
        "action.create": "Criar",
        "action.pause": "Pausar",
        "action.resume": "Retomar",
        "action.checkNow": "Verificar Agora",
        "action.browse": "Procurar...",
        "action.export": "Exportar",
        "action.import": "Importar",
        "action.test": "Testar Conexão",
        "action.close": "Fechar",
        "action.forceBuild": "Forçar Build",
        
        // Sidebar
        "sidebar.repositories": "Repositórios",
        "sidebar.builds": "Builds",
        "sidebar.groups": "Grupos",
        "sidebar.timers": "Timers",
        "sidebar.checks": "Verificações",
        "sidebar.history": "Histórico",
        
        // Repositories
        "repo.title": "Repositórios Monitorados",
        "repo.add": "Adicionar Repositório",
        "repo.edit": "Editar Repositório",
        "repo.empty": "Nenhum Repositório",
        "repo.emptyDescription": "Adicione um repositório Git para começar a monitorar.",
        "repo.name": "Nome",
        "repo.path": "Caminho Local",
        "repo.remote": "Remoto",
        "repo.branch": "Branch",
        "repo.interval": "Intervalo",
        "repo.enabled": "Ativo",
        "repo.lastCheck": "Última verificação",
        "repo.triggers": "Triggers",
        "repo.validPath": "Repositório válido",
        "repo.invalidPath": "Não é um repositório Git",
        "repo.pathNotFound": "Caminho não encontrado",
        "repo.currentBranch": "Branch atual",
        "repo.validateAccess": "Validar Acesso (Git Fetch)",
        "repo.connectionOK": "Conexão OK",
        "repo.connectionError": "Erro de Conexão",
        "repo.accessConfirmed": "Acesso ao repositório remoto confirmado com sucesso!",
        "repo.accessFailed": "Falha ao acessar remoto",
        "repo.addTrigger": "Adicionar Trigger",
        "repo.watchTags": "Monitorar Tags",
        "repo.watchTagsInfo": "Ao invés de monitorar commits na branch, detecta novas tags. Use padrões como -prod, -dev, -hml no nome da tag para filtrar nos triggers.",
        
        // Groups
        "group.title": "Grupos de Notificação",
        "group.add": "Criar Grupo",
        "group.edit": "Editar Grupo",
        "group.new": "Novo Grupo",
        "group.empty": "Nenhum Grupo",
        "group.emptyDescription": "Crie um grupo para configurar Telegram/Teams por projeto.",
        "group.name": "Nome do grupo",
        "group.color": "Cor",
        "group.none": "Nenhum (sem notificações)",
        "group.repositories": "repositórios",
        "group.noIntegrations": "Sem integrações",
        "group.info": "Informações",
        "group.notificationGroup": "Grupo de Notificação",
        "group.createFirst": "Crie um grupo primeiro para configurar Telegram/Teams",
        
        // Triggers
        "trigger.title": "Triggers",
        "trigger.add": "Adicionar Trigger",
        "trigger.edit": "Editar Trigger",
        "trigger.empty": "Sem triggers",
        "trigger.name": "Nome",
        "trigger.flag": "Flag do Commit",
        "trigger.flagPlaceholder": "--prod, --deploy, etc (vazio = qualquer commit)",
        "trigger.command": "Comando",
        "trigger.commandPlaceholder": "sh deploy.sh",
        "trigger.workDir": "Diretório de Trabalho",
        "trigger.workDirPlaceholder": "Deixe vazio para usar a raiz do repo",
        "trigger.priority": "Prioridade",
        "trigger.priorityHelp": "Triggers com maior prioridade são verificados primeiro",
        
        // Builds
        "build.title": "Histórico de Builds",
        "build.empty": "Nenhum Build",
        "build.emptyDescription": "O histórico aparecerá aqui.",
        "build.status": "Status",
        "build.repository": "Repositório",
        "build.trigger": "Trigger",
        "build.commit": "Commit",
        "build.duration": "Duração",
        "build.date": "Data",
        
        // Check History
        "check.title": "Histórico de Verificações",
        "check.empty": "Nenhuma Verificação",
        "check.emptyDescription": "O histórico de verificações aparecerá aqui.",
        "check.details": "Detalhes da Verificação",
        "check.result": "Resultado",
        "check.noChanges": "Sem alterações",
        "check.newCommit": "Commit novo",
        "check.triggered": "Trigger executado",
        "check.message": "Mensagem",
        "check.gitOutput": "Git Output",
        "check.last": "Última",
        
        
        // Data
        "data.export": "Exportar Configurações",
        "data.import": "Importar Configurações",
        "data.exportSuccess": "Exportado com sucesso!",
        "data.importSuccess": "Importado com sucesso!",
        "data.exportDescription": "Exporta grupos, repositórios e triggers para JSON.",
        "data.importDescription": "Importa configurações de um arquivo JSON.",
        "data.dataCount": "Dados",
        "data.resetSystem": "Resetar Sistema",
        "data.resetDescription": "Esta ação irá remover TODOS os dados do GitPilot. Grupos, Repositórios, Logs e Histórico serão apagados permanentemente.",
        "data.clearAll": "Limpar Tudo",
        "data.resetAll": "Resetar Tudo",
        "data.resetConfirmation": "Tem certeza absoluta? Todos os dados serão perdidos permanentemente.",
        "data.resetSuccess": "Sistema resetado com sucesso.",
        
        // Telegram/Teams
        "telegram.info": "O Telegram agora é configurado por grupo de notificação.",
        "telegram.goToGroups": "Vá para a aba 'Grupos' na janela principal.",
        "telegram.botToken": "Bot Token",
        "telegram.chatId": "Chat ID",
        "teams.info": "O Microsoft Teams agora é configurado por grupo de notificação.",
        "teams.goToGroups": "Vá para a aba 'Grupos' na janela principal.",
        "teams.webhookUrl": "Webhook URL",
        
        // Common
        "common.enable": "Habilitar",
        "common.info": "Informações",
        "common.preferences": "Preferências",
        "common.confirmation": "Confirmação",
        "common.yes": "Sim",
        "common.no": "Não",
        "common.off": "OFF",
        "common.repository": "Repositório",
        "common.git": "Git",
        
        // Time intervals
        "time.1min": "1 min",
        "time.2min": "2 min",
        "time.5min": "5 min",
        "time.10min": "10 min",
        "time.30min": "30 min",
        "time.1hour": "1 hora",
        
        // Trigger Confirmation Notifications
        "notification.triggerDetected": "Trigger Detectado",
        "notification.confirmExecute": "Executar",
        "notification.reject": "Rejeitar",
        "notification.autoExecuteIn": "Execução automática em 30s",
        "notification.triggerRejected": "Trigger ignorado",
    ]
    
    // MARK: - English
    static let en: [String: String] = [
        // App
        "app.name": "GitPilot",
        "app.open": "Open GitPilot",
        "app.quit": "Quit",
        "app.settings": "Settings",
        
        // Status
        "status.idle": "Idle",
        "status.checking": "Checking",
        "status.building": "Building",
        "status.success": "Success",
        "status.failed": "Failed",
        "status.error": "Error",
        "status.paused": "Paused",
        "status.monitoring": "Monitoring",
        "status.stopped": "Stopped",
        
        // Actions
        "action.add": "Add",
        "action.edit": "Edit",
        "action.delete": "Delete",
        "action.save": "Save",
        "action.cancel": "Cancel",
        "action.create": "Create",
        "action.pause": "Pause",
        "action.resume": "Resume",
        "action.checkNow": "Check Now",
        "action.browse": "Browse...",
        "action.export": "Export",
        "action.import": "Import",
        "action.test": "Test Connection",
        "action.close": "Close",
        "action.forceBuild": "Force Build",
        
        // Sidebar
        "sidebar.repositories": "Repositories",
        "sidebar.builds": "Builds",
        "sidebar.groups": "Groups",
        "sidebar.timers": "Timers",
        "sidebar.checks": "Checks",
        "sidebar.history": "History",
        
        // Repositories
        "repo.title": "Monitored Repositories",
        "repo.add": "Add Repository",
        "repo.edit": "Edit Repository",
        "repo.empty": "No Repositories",
        "repo.emptyDescription": "Add a Git repository to start monitoring.",
        "repo.name": "Name",
        "repo.path": "Local Path",
        "repo.remote": "Remote",
        "repo.branch": "Branch",
        "repo.interval": "Interval",
        "repo.enabled": "Enabled",
        "repo.lastCheck": "Last check",
        "repo.triggers": "triggers",
        "repo.validPath": "Valid repository",
        "repo.invalidPath": "Not a Git repository",
        "repo.pathNotFound": "Path not found",
        "repo.currentBranch": "Current branch",
        "repo.validateAccess": "Verify Access (Git Fetch)",
        "repo.connectionOK": "Connection OK",
        "repo.connectionError": "Connection Error",
        "repo.accessConfirmed": "Remote repository access confirmed successfully!",
        "repo.accessFailed": "Failed to access remote",
        "repo.addTrigger": "Add Trigger",
        "repo.watchTags": "Watch Tags",
        "repo.watchTagsInfo": "Instead of monitoring commits on a branch, detects new tags. Use patterns like -prod, -dev, -hml in tag names to filter in triggers.",
        
        // Groups
        "group.title": "Notification Groups",
        "group.add": "Create Group",
        "group.edit": "Edit Group",
        "group.new": "New Group",
        "group.empty": "No Groups",
        "group.emptyDescription": "Create a group to configure Telegram/Teams per project.",
        "group.name": "Group name",
        "group.color": "Color",
        "group.none": "None (no notifications)",
        "group.repositories": "repositories",
        "group.noIntegrations": "No integrations",
        "group.info": "Information",
        "group.notificationGroup": "Notification Group",
        "group.createFirst": "Create a group first to configure Telegram/Teams",
        
        // Triggers
        "trigger.title": "Triggers",
        "trigger.add": "Add Trigger",
        "trigger.edit": "Edit Trigger",
        "trigger.empty": "No triggers",
        "trigger.name": "Name",
        "trigger.flag": "Commit Flag",
        "trigger.flagPlaceholder": "--prod, --deploy, etc (empty = any commit)",
        "trigger.command": "Command",
        "trigger.commandPlaceholder": "sh deploy.sh",
        "trigger.workDir": "Working Directory",
        "trigger.workDirPlaceholder": "Leave empty to use repository path",
        "trigger.priority": "Priority",
        "trigger.priorityHelp": "Higher priority triggers are checked first",
        
        // Builds
        "build.title": "Build History",
        "build.empty": "No Builds",
        "build.emptyDescription": "Build history will appear here.",
        "build.status": "Status",
        "build.repository": "Repository",
        "build.trigger": "Trigger",
        "build.commit": "Commit",
        "build.duration": "Duration",
        "build.date": "Date",
        
        // Check History
        "check.title": "Check History",
        "check.empty": "No Checks",
        "check.emptyDescription": "Check history will appear here.",
        "check.details": "Check Details",
        "check.result": "Result",
        "check.noChanges": "No changes",
        "check.newCommit": "New commit",
        "check.triggered": "Trigger executed",
        "check.message": "Message",
        "check.gitOutput": "Git Output",
        "check.last": "Last",
        
        // Settings
        "settings.title": "Settings",
        "settings.general": "General",
        "settings.notifications": "Notifications",
        "settings.telegram": "Telegram",
        "settings.teams": "Teams",
        "settings.data": "Data",
        "settings.language": "Language",
        "settings.launchAtLogin": "Launch at login",
        "settings.showInDock": "Show in Dock",
        "settings.nativeNotifications": "Native notifications",
        "settings.notifySuccess": "Notify on success",
        "settings.notifyFailure": "Notify on failure",
        "settings.appBehavior": "App Behavior",
        "settings.showInDockHelp": "Showing in Dock allows you to see the app in Dock and Command-Tab",
        "settings.permissionRequired": "Notification permission required",
        "settings.requestPermission": "Request Permission",
        "settings.checkUpdates": "Check for updates",
        
        // Data
        "data.export": "Export Settings",
        "data.import": "Import Settings",
        "data.exportSuccess": "Exported successfully!",
        "data.importSuccess": "Imported successfully!",
        "data.exportDescription": "Exports groups, repositories and triggers to JSON.",
        "data.importDescription": "Imports settings from a JSON file.",
        "data.dataCount": "Data",
        "data.resetSystem": "Reset System",
        "data.resetDescription": "This action will remove ALL data from GitPilot. Groups, Repositories, Logs and History will be permanently deleted.",
        "data.clearAll": "Clear All",
        "data.resetAll": "Reset All",
        "data.resetConfirmation": "Are you absolutely sure? All data will be permanently lost.",
        "data.resetSuccess": "System reset successfully.",
        
        // Telegram/Teams
        "telegram.info": "Telegram is now configured per notification group.",
        "telegram.goToGroups": "Go to the 'Groups' tab in the main window.",
        "telegram.botToken": "Bot Token",
        "telegram.chatId": "Chat ID",
        "teams.info": "Microsoft Teams is now configured per notification group.",
        "teams.goToGroups": "Go to the 'Groups' tab in the main window.",
        "teams.webhookUrl": "Webhook URL",
        
        // Common
        "common.enable": "Enable",
        "common.info": "Information",
        "common.preferences": "Preferences",
        "common.confirmation": "Confirmation",
        "common.yes": "Yes",
        "common.no": "No",
        "common.off": "OFF",
        "common.repository": "Repository",
        "common.git": "Git",
        
        // Time intervals
        "time.1min": "1 min",
        "time.2min": "2 min",
        "time.5min": "5 min",
        "time.10min": "10 min",
        "time.30min": "30 min",
        "time.1hour": "1 hour",
        
        // Trigger Confirmation Notifications
        "notification.triggerDetected": "Trigger Detected",
        "notification.confirmExecute": "Execute",
        "notification.reject": "Reject",
        "notification.autoExecuteIn": "Auto-executing in 30s",
        "notification.triggerRejected": "Trigger ignored",
    ]
    
    // MARK: - Spanish
    static let es: [String: String] = [
        // App
        "app.name": "GitPilot",
        "app.open": "Abrir GitPilot",
        "app.quit": "Salir",
        "app.settings": "Configuración",
        
        // Status
        "status.idle": "En espera",
        "status.checking": "Verificando",
        "status.building": "Compilando",
        "status.success": "Éxito",
        "status.failed": "Falló",
        "status.error": "Error",
        "status.paused": "Pausado",
        "status.monitoring": "Monitoreando",
        "status.stopped": "Detenido",
        
        // Actions
        "action.add": "Agregar",
        "action.edit": "Editar",
        "action.delete": "Eliminar",
        "action.save": "Guardar",
        "action.cancel": "Cancelar",
        "action.create": "Crear",
        "action.pause": "Pausar",
        "action.resume": "Reanudar",
        "action.checkNow": "Verificar Ahora",
        "action.browse": "Buscar...",
        "action.export": "Exportar",
        "action.import": "Importar",
        "action.test": "Probar Conexión",
        "action.close": "Cerrar",
        "action.forceBuild": "Forzar Build",
        
        // Sidebar
        "sidebar.repositories": "Repositorios",
        "sidebar.builds": "Builds",
        "sidebar.groups": "Grupos",
        "sidebar.timers": "Timers",
        "sidebar.checks": "Checks",
        "sidebar.history": "Historial",
        
        // Repositories
        "repo.title": "Repositorios Monitoreados",
        "repo.add": "Agregar Repositorio",
        "repo.edit": "Editar Repositorio",
        "repo.empty": "Sin Repositorios",
        "repo.emptyDescription": "Agrega un repositorio Git para comenzar a monitorear.",
        "repo.name": "Nombre",
        "repo.path": "Ruta Local",
        "repo.remote": "Remote",
        "repo.branch": "Rama",
        "repo.interval": "Intervalo",
        "repo.enabled": "Activo",
        "repo.lastCheck": "Última verificación",
        "repo.triggers": "Triggers",
        "repo.validPath": "Repositorio válido",
        "repo.invalidPath": "No es un repositorio Git",
        "repo.pathNotFound": "Ruta no encontrada",
        "repo.currentBranch": "Rama actual",
        "repo.validateAccess": "Validar Acceso (Git Fetch)",
        "repo.connectionOK": "Conexión OK",
        "repo.connectionError": "Error de Conexión",
        "repo.accessConfirmed": "¡Acceso al repositorio remoto confirmado con éxito!",
        "repo.accessFailed": "Error al acceder al remoto",
        "repo.addTrigger": "Agregar Trigger",
        "repo.watchTags": "Monitorear Tags",
        "repo.watchTagsInfo": "En lugar de monitorear commits en la rama, detecta nuevas tags. Use patrones como -prod, -dev, -hml en los nombres de tags para filtrar en triggers.",
        
        // Groups
        "group.title": "Grupos de Notificación",
        "group.add": "Crear Grupo",
        "group.edit": "Editar Grupo",
        "group.new": "Nuevo Grupo",
        "group.empty": "Sin Grupos",
        "group.emptyDescription": "Crea un grupo para configurar Telegram/Teams por proyecto.",
        "group.name": "Nombre del grupo",
        "group.color": "Color",
        "group.none": "Ninguno (sin notificaciones)",
        "group.repositories": "repositorios",
        "group.noIntegrations": "Sin integraciones",
        "group.info": "Información",
        "group.notificationGroup": "Grupo de Notificación",
        "group.createFirst": "Crea un grupo primero para configurar Telegram/Teams",
        
        // Triggers
        "trigger.title": "Triggers",
        "trigger.add": "Agregar Trigger",
        "trigger.edit": "Editar Trigger",
        "trigger.empty": "Sin triggers",
        "trigger.name": "Nombre",
        "trigger.flag": "Flag del Commit",
        "trigger.flagPlaceholder": "--prod, --deploy, etc (vacío = cualquier commit)",
        "trigger.command": "Comando",
        "trigger.commandPlaceholder": "sh deploy.sh",
        "trigger.workDir": "Directorio de Trabajo",
        "trigger.workDirPlaceholder": "Deja vacío para usar la ruta del repositorio",
        "trigger.priority": "Prioridad",
        "trigger.priorityHelp": "Los triggers con mayor prioridad se verifican primero",
        
        // Builds
        "build.title": "Historial de Builds",
        "build.empty": "Sin Builds",
        "build.emptyDescription": "El historial aparecerá aquí.",
        "build.status": "Estado",
        "build.repository": "Repositorio",
        "build.trigger": "Trigger",
        "build.commit": "Commit",
        "build.duration": "Duración",
        "build.date": "Fecha",
        
        // Check History
        "check.title": "Historial de Verificaciones",
        "check.empty": "Sin Verificaciones",
        "check.emptyDescription": "El historial de verificaciones aparecerá aquí.",
        "check.details": "Detalles de la Verificación",
        "check.result": "Resultado",
        "check.noChanges": "Sin cambios",
        "check.newCommit": "Commit nuevo",
        "check.triggered": "Trigger ejecutado",
        "check.message": "Mensaje",
        "check.gitOutput": "Git Output",
        "check.last": "Última",
        
        // Settings
        "settings.title": "Configuración",
        "settings.general": "General",
        "settings.notifications": "Notificaciones",
        "settings.telegram": "Telegram",
        "settings.teams": "Teams",
        "settings.data": "Datos",
        "settings.language": "Idioma",
        "settings.launchAtLogin": "Iniciar al arrancar",
        "settings.showInDock": "Mostrar en Dock",
        "settings.nativeNotifications": "Notificaciones nativas",
        "settings.notifySuccess": "Notificar éxito",
        "settings.notifyFailure": "Notificar fallo",
        "settings.appBehavior": "Comportamiento de la App",
        "settings.showInDockHelp": "Mostrar en el Dock permite ver la app en el Dock y en Command-Tab",
        "settings.permissionRequired": "Permiso de notificación requerido",
        "settings.requestPermission": "Solicitar Permiso",
        "settings.checkUpdates": "Buscar actualizaciones",
        
        // Data
        "data.export": "Exportar Configuración",
        "data.import": "Importar Configuración",
        "data.exportSuccess": "¡Exportado con éxito!",
        "data.importSuccess": "¡Importado con éxito!",
        "data.exportDescription": "Exporta grupos, repositorios y triggers a JSON.",
        "data.importDescription": "Importa configuración desde un archivo JSON.",
        "data.dataCount": "Datos",
        "data.resetSystem": "Restablecer Sistema",
        "data.resetDescription": "Esta acción eliminará TODOS los datos de GitPilot. Grupos, Repositorios, Logs e Historial serán borrados permanentemente.",
        "data.clearAll": "Limpiar Todo",
        "data.resetAll": "Restablecer Todo",
        "data.resetConfirmation": "¿Estás absolutamente seguro? Todos los datos se perderán permanentemente.",
        "data.resetSuccess": "Sistema restablecido con éxito.",
        
        // Telegram/Teams
        "telegram.info": "Telegram ahora se configura por grupo de notificación.",
        "telegram.goToGroups": "Ve a la pestaña 'Grupos' en la ventana principal.",
        "telegram.botToken": "Bot Token",
        "telegram.chatId": "Chat ID",
        "teams.info": "Microsoft Teams ahora se configura por grupo de notificación.",
        "teams.goToGroups": "Ve a la pestaña 'Grupos' en la ventana principal.",
        "teams.webhookUrl": "Webhook URL",
        
        // Common
        "common.enable": "Habilitar",
        "common.info": "Información",
        "common.preferences": "Preferencias",
        "common.confirmation": "Confirmación",
        "common.yes": "Sí",
        "common.no": "No",
        "common.off": "OFF",
        "common.repository": "Repositorio",
        "common.git": "Git",
        
        // Time intervals
        "time.1min": "1 min",
        "time.2min": "2 min",
        "time.5min": "5 min",
        "time.10min": "10 min",
        "time.30min": "30 min",
        "time.1hour": "1 hora",
        
        // Trigger Confirmation Notifications
        "notification.triggerDetected": "Trigger Detectado",
        "notification.confirmExecute": "Ejecutar",
        "notification.reject": "Rechazar",
        "notification.autoExecuteIn": "Ejecución automática en 30s",
        "notification.triggerRejected": "Trigger ignorado",
    ]
}

// MARK: - View Extension for Localization

extension View {
    func localized(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }
}
