#!/bin/bash
# =============================================================================
# BIBLIOTECA DE BACKUP E ROLLBACK
# Sistema automático de backup antes de alterações + rollback fácil
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# Configuração de backup
readonly BACKUP_BASE_DIR="$HOME/.laptop-optimizer-backups"
readonly CURRENT_BACKUP_DIR="$BACKUP_BASE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_MANIFEST="$CURRENT_BACKUP_DIR/manifest.txt"
readonly ROLLBACK_SCRIPT="$CURRENT_BACKUP_DIR/rollback.sh"

# =============================================================================
# CRIAÇÃO DE BACKUP AUTOMÁTICO
# =============================================================================

create_system_backup() {
    section_header "Criando Backup do Sistema" "$SYMBOL_SHIELD"
    
    log_info "Backup será criado em: $CURRENT_BACKUP_DIR"
    
    # Criar diretório de backup
    mkdir -p "$CURRENT_BACKUP_DIR"
    
    # Inicializar manifest
    cat > "$BACKUP_MANIFEST" << EOF
# LAPTOP OPTIMIZER - BACKUP MANIFEST
# Criado: $(date)
# Sistema: $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)
# Utilizador: $USER
# Versão script: ${VERSION:-"4.0-modular"}

BACKUP_FILES:
EOF
    
    # Backup de ficheiros críticos
    backup_critical_files
    
    # Backup de configurações de serviços
    backup_service_configs
    
    # Backup de cron jobs
    backup_cron_jobs
    
    # Backup de configurações de utilizador
    backup_user_configs
    
    # Criar script de rollback automático
    create_rollback_script
    
    # Criar comando de rollback global
    create_global_rollback_command
    
    log_success "Backup completo criado: $CURRENT_BACKUP_DIR"
    echo ""
    echo -e "${YELLOW}💡 Para reverter alterações:${NC}"
    echo -e "   dev-rollback $CURRENT_BACKUP_DIR"
    echo ""
}

# =============================================================================
# BACKUP DE FICHEIROS CRÍTICOS
# =============================================================================

backup_critical_files() {
    log_info "Backup de ficheiros críticos do sistema..."
    
    local critical_files=(
        "/etc/sysctl.conf"
        "/etc/fstab"
        "/etc/security/limits.conf"
        "/etc/ssh/sshd_config"
        "/etc/systemd/resolved.conf"
        "/etc/default/grub"
    )
    
    mkdir -p "$CURRENT_BACKUP_DIR/system"
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local backup_path="$CURRENT_BACKUP_DIR/system$(dirname "$file")"
            mkdir -p "$backup_path"
            cp "$file" "$backup_path/"
            echo "SYSTEM_FILE:$file" >> "$BACKUP_MANIFEST"
        fi
    done
    
    # Backup de diretórios de configuração
    local config_dirs=(
        "/etc/sysctl.d"
        "/etc/security/limits.d"
        "/etc/systemd/system.conf.d"
        "/etc/systemd/user.conf.d"
        "/etc/apt/apt.conf.d"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local backup_path="$CURRENT_BACKUP_DIR/system$dir"
            mkdir -p "$(dirname "$backup_path")"
            cp -r "$dir" "$backup_path"
            echo "SYSTEM_DIR:$dir" >> "$BACKUP_MANIFEST"
        fi
    done
    
    log_success "Ficheiros críticos salvos"
}

# =============================================================================
# BACKUP DE CONFIGURAÇÕES DE SERVIÇOS
# =============================================================================

backup_service_configs() {
    log_info "Backup de configurações de serviços..."
    
    local services=(
        "tlp"
        "fail2ban"
        "ufw"
        "docker"
    )
    
    mkdir -p "$CURRENT_BACKUP_DIR/services"
    
    for service in "${services[@]}"; do
        # Estado do serviço
        if systemctl list-unit-files --type=service | grep -q "^$service.service"; then
            local service_state=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
            local service_active=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            
            echo "SERVICE:$service:$service_state:$service_active" >> "$BACKUP_MANIFEST"
            
            # Ficheiros de configuração específicos
            case "$service" in
                "tlp")
                    [[ -d /etc/tlp.d ]] && cp -r /etc/tlp.d "$CURRENT_BACKUP_DIR/services/"
                    ;;
                "fail2ban")
                    [[ -d /etc/fail2ban ]] && cp -r /etc/fail2ban "$CURRENT_BACKUP_DIR/services/"
                    ;;
                "docker")
                    [[ -f /etc/docker/daemon.json ]] && mkdir -p "$CURRENT_BACKUP_DIR/services/docker" && cp /etc/docker/daemon.json "$CURRENT_BACKUP_DIR/services/docker/"
                    ;;
            esac
        fi
    done
    
    log_success "Configurações de serviços salvos"
}

# =============================================================================
# BACKUP DE CRON JOBS
# =============================================================================

backup_cron_jobs() {
    log_info "Backup de cron jobs..."
    
    mkdir -p "$CURRENT_BACKUP_DIR/cron"
    
    # Cron do utilizador
    if crontab -l >/dev/null 2>&1; then
        crontab -l > "$CURRENT_BACKUP_DIR/cron/user-crontab"
        echo "USER_CRON:saved" >> "$BACKUP_MANIFEST"
    fi
    
    # Cron jobs do sistema
    if [[ -d /etc/cron.d ]]; then
        cp -r /etc/cron.d "$CURRENT_BACKUP_DIR/cron/"
        echo "SYSTEM_CRON:/etc/cron.d" >> "$BACKUP_MANIFEST"
    fi
    
    # Scripts de cron
    local cron_dirs=("/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly")
    for dir in "${cron_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            cp -r "$dir" "$CURRENT_BACKUP_DIR/cron/"
            echo "CRON_DIR:$dir" >> "$BACKUP_MANIFEST"
        fi
    done
    
    log_success "Cron jobs salvos"
}

# =============================================================================
# BACKUP DE CONFIGURAÇÕES DE UTILIZADOR
# =============================================================================

backup_user_configs() {
    log_info "Backup de configurações de utilizador..."
    
    mkdir -p "$CURRENT_BACKUP_DIR/user"
    
    local user_files=(
        ".bashrc"
        ".zshrc"
        ".vimrc"
        ".gitconfig"
        ".dev_aliases"
    )
    
    for file in "${user_files[@]}"; do
        if [[ -f "$HOME/$file" ]]; then
            cp "$HOME/$file" "$CURRENT_BACKUP_DIR/user/"
            echo "USER_FILE:$HOME/$file" >> "$BACKUP_MANIFEST"
        fi
    done
    
    # Diretórios especiais
    local user_dirs=(
        ".oh-my-zsh"
        ".ssh"
        ".vim"
    )
    
    for dir in "${user_dirs[@]}"; do
        if [[ -d "$HOME/$dir" ]]; then
            # Apenas ficheiros de configuração, não dados sensíveis
            case "$dir" in
                ".ssh")
                    mkdir -p "$CURRENT_BACKUP_DIR/user/.ssh"
                    [[ -f "$HOME/.ssh/config" ]] && cp "$HOME/.ssh/config" "$CURRENT_BACKUP_DIR/user/.ssh/"
                    echo "USER_DIR:$HOME/$dir (config only)" >> "$BACKUP_MANIFEST"
                    ;;
                ".oh-my-zsh")
                    # Apenas custom configs, não o oh-my-zsh completo
                    if [[ -d "$HOME/.oh-my-zsh/custom" ]]; then
                        mkdir -p "$CURRENT_BACKUP_DIR/user/.oh-my-zsh"
                        cp -r "$HOME/.oh-my-zsh/custom" "$CURRENT_BACKUP_DIR/user/.oh-my-zsh/"
                        echo "USER_DIR:$HOME/$dir (custom only)" >> "$BACKUP_MANIFEST"
                    fi
                    ;;
                *)
                    cp -r "$HOME/$dir" "$CURRENT_BACKUP_DIR/user/" 2>/dev/null || true
                    echo "USER_DIR:$HOME/$dir" >> "$BACKUP_MANIFEST"
                    ;;
            esac
        fi
    done
    
    log_success "Configurações de utilizador salvas"
}

# =============================================================================
# CRIAÇÃO DE SCRIPT DE ROLLBACK AUTOMÁTICO
# =============================================================================

create_rollback_script() {
    log_info "Criando script de rollback automático..."
    
    cat > "$ROLLBACK_SCRIPT" << 'EOF'
#!/bin/bash
# =============================================================================
# SCRIPT DE ROLLBACK AUTOMÁTICO
# Gerado automaticamente pelo Laptop Optimizer
# =============================================================================

set -euo pipefail

readonly BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MANIFEST="$BACKUP_DIR/manifest.txt"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_rollback() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")    echo -e "ℹ️ ${message}" ;;
        "SUCCESS") echo -e "${GREEN}✅${NC} ${message}" ;;
        "WARNING") echo -e "${YELLOW}⚠️${NC} ${message}" ;;
        "ERROR")   echo -e "${RED}❌${NC} ${message}" ;;
    esac
}

main() {
    echo -e "${YELLOW}🔄 EXECUTANDO ROLLBACK...${NC}"
    echo ""
    echo "Backup: $BACKUP_DIR"
    echo "Manifest: $MANIFEST"
    echo ""
    
    if [[ ! -f "$MANIFEST" ]]; then
        log_rollback "ERROR" "Manifest não encontrado: $MANIFEST"
        exit 1
    fi
    
    log_rollback "WARNING" "Este rollback vai reverter TODAS as alterações feitas pelo optimizer"
    echo ""
    read -p "Continuar? (y/N): " response
    if [[ ! "$response" =~ ^[Yy] ]]; then
        log_rollback "INFO" "Rollback cancelado"
        exit 0
    fi
    
    echo ""
    log_rollback "INFO" "🔄 Iniciando rollback..."
    
    # Restaurar ficheiros do sistema
    log_rollback "INFO" "Restaurando ficheiros do sistema..."
    while IFS=':' read -r type path; do
        case "$type" in
            "SYSTEM_FILE")
                if [[ -f "$BACKUP_DIR/system$path" ]]; then
                    sudo cp "$BACKUP_DIR/system$path" "$path"
                    log_rollback "SUCCESS" "Restaurado: $path"
                fi
                ;;
            "SYSTEM_DIR")
                if [[ -d "$BACKUP_DIR/system$path" ]]; then
                    sudo rm -rf "$path"
                    sudo cp -r "$BACKUP_DIR/system$path" "$path"
                    log_rollback "SUCCESS" "Restaurado: $path"
                fi
                ;;
        esac
    done < "$MANIFEST"
    
    # Restaurar configurações de utilizador
    log_rollback "INFO" "Restaurando configurações de utilizador..."
    while IFS=':' read -r type path rest; do
        case "$type" in
            "USER_FILE")
                local filename=$(basename "$path")
                if [[ -f "$BACKUP_DIR/user/$filename" ]]; then
                    cp "$BACKUP_DIR/user/$filename" "$path"
                    log_rollback "SUCCESS" "Restaurado: $path"
                fi
                ;;
            "USER_DIR")
                local dirname=$(basename "$path")
                if [[ -d "$BACKUP_DIR/user/$dirname" ]]; then
                    rm -rf "$path"
                    cp -r "$BACKUP_DIR/user/$dirname" "$path"
                    log_rollback "SUCCESS" "Restaurado: $path"
                fi
                ;;
        esac
    done < "$MANIFEST"
    
    # Remover configurações adicionadas pelo optimizer
    log_rollback "INFO" "Removendo configurações do optimizer..."
    
    # Remover sysctl configs
    sudo rm -f /etc/sysctl.d/99-dev-*.conf
    
    # Remover limits configs  
    sudo rm -f /etc/security/limits.d/99-dev-*.conf
    
    # Remover systemd configs
    sudo rm -f /etc/systemd/system.conf.d/dev-*.conf
    sudo rm -f /etc/systemd/user.conf.d/dev-*.conf
    
    # Remover cron jobs do optimizer
    sudo rm -f /etc/cron.d/dev-*
    
    # Remover scripts utilitários
    sudo rm -f /usr/local/bin/dev-*
    
    # Remover logs e configs
    sudo rm -rf /var/log/dev-maintenance
    sudo rm -f /etc/dev-maintenance.conf
    
    # Recarregar configurações
    log_rollback "INFO" "Recarregando configurações do sistema..."
    sudo sysctl --system >/dev/null 2>&1 || true
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    
    log_rollback "SUCCESS" "🎉 Rollback concluído com sucesso!"
    echo ""
    log_rollback "WARNING" "🔄 REINICIE o sistema para aplicar completamente: sudo reboot"
    echo ""
    log_rollback "INFO" "📋 Ficheiros restaurados a partir de: $BACKUP_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF
    
    chmod +x "$ROLLBACK_SCRIPT"
    echo "ROLLBACK_SCRIPT:$ROLLBACK_SCRIPT" >> "$BACKUP_MANIFEST"
    
    log_success "Script de rollback criado: $ROLLBACK_SCRIPT"
}

# =============================================================================
# COMANDO GLOBAL DE ROLLBACK
# =============================================================================

create_global_rollback_command() {
    log_info "Criando comando global de rollback..."
    
    sudo tee /usr/local/bin/dev-rollback > /dev/null << 'EOF'
#!/bin/bash
# Comando global para rollback de configurações

if [[ -z "$1" ]]; then
    echo "🔄 ROLLBACK DE CONFIGURAÇÕES"
    echo "============================"
    echo ""
    echo "Uso: dev-rollback <backup_directory>"
    echo ""
    echo "📁 Backups disponíveis:"
    if [[ -d "$HOME/.laptop-optimizer-backups" ]]; then
        ls -la "$HOME/.laptop-optimizer-backups/" | grep "^d" | tail -10 | while read line; do
            local backup_dir=$(echo "$line" | awk '{print $9}')
            local backup_date=$(echo "$backup_dir" | grep -o '[0-9]\{8\}-[0-9]\{6\}')
            if [[ -n "$backup_date" ]]; then
                local formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%d/%m/%Y %H:%M" 2>/dev/null || echo "$backup_date")
                echo "   $HOME/.laptop-optimizer-backups/$backup_dir ($formatted_date)"
            fi
        done
    else
        echo "   Nenhum backup encontrado"
    fi
    echo ""
    exit 1
fi

backup_dir="$1"

if [[ ! -d "$backup_dir" ]]; then
    echo "❌ Diretório de backup não encontrado: $backup_dir"
    exit 1
fi

if [[ ! -f "$backup_dir/rollback.sh" ]]; then
    echo "❌ Script de rollback não encontrado em: $backup_dir"
    exit 1
fi

echo "🔄 Executando rollback de: $backup_dir"
echo ""
exec "$backup_dir/rollback.sh"
EOF
    
    sudo chmod +x /usr/local/bin/dev-rollback
    
    log_success "Comando 'dev-rollback' disponível globalmente"
}

# =============================================================================
# GESTÃO DE BACKUPS ANTIGOS
# =============================================================================

cleanup_old_backups() {
    local max_backups="${1:-10}"
    
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        return 0
    fi
    
    log_info "Limpando backups antigos (mantendo últimos $max_backups)..."
    
    # Listar backups ordenados por data
    local backup_count=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        local to_remove=$((backup_count - max_backups))
        find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" -printf '%T@ %p\n' | \
        sort -n | head -n "$to_remove" | cut -d' ' -f2- | \
        while read backup_dir; do
            rm -rf "$backup_dir"
            log_info "Backup antigo removido: $(basename "$backup_dir")"
        done
        
        log_success "$to_remove backups antigos removidos"
    else
        log_info "Apenas $backup_count backups - nenhuma limpeza necessária"
    fi
}

# =============================================================================
# VERIFICAÇÃO DE BACKUP
# =============================================================================

verify_backup() {
    local backup_dir="${1:-$CURRENT_BACKUP_DIR}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup não encontrado: $backup_dir"
        return 1
    fi
    
    if [[ ! -f "$backup_dir/manifest.txt" ]]; then
        log_error "Manifest não encontrado: $backup_dir/manifest.txt"
        return 1
    fi
    
    if [[ ! -f "$backup_dir/rollback.sh" ]] || [[ ! -x "$backup_dir/rollback.sh" ]]; then
        log_error "Script de rollback não encontrado ou não executável"
        return 1
    fi
    
    log_success "Backup verificado: $backup_dir"
    return 0
}

# =============================================================================
# LISTAR BACKUPS DISPONÍVEIS
# =============================================================================

list_available_backups() {
    echo -e "${BLUE}📁 BACKUPS DISPONÍVEIS:${NC}"
    echo ""
    
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        echo "   Nenhum backup encontrado"
        return 0
    fi
    
    find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" -printf '%T@ %p\n' | \
    sort -nr | while read timestamp backup_path; do
        local backup_name=$(basename "$backup_path")
        local backup_date=$(echo "$backup_name" | grep -o '[0-9]\{8\}-[0-9]\{6\}')
        
        if [[ -n "$backup_date" ]]; then
            local formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%d/%m/%Y %H:%M" 2>/dev/null || echo "$backup_date")
            local backup_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
            
            if verify_backup "$backup_path" >/dev/null 2>&1; then
                echo -e "   ✅ $backup_path"
                echo -e "      📅 $formatted_date | 💾 $backup_size"
            else
                echo -e "   ❌ $backup_path (corrompido)"
            fi
        fi
    done
    
    echo ""
}