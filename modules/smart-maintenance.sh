#!/bin/bash
# =============================================================================
# MÓDULO: SISTEMA DE MANUTENÇÃO INTELIGENTE
# Sistema automático que preserva dados importantes (especialidade única)
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

readonly MAINTENANCE_LOG_DIR="/var/log/dev-maintenance"
readonly MAINTENANCE_SCRIPT="/usr/local/bin/dev-maintenance"
readonly CONFIG_FILE="/etc/dev-maintenance.conf"

# =============================================================================
# SCRIPT PRINCIPAL DE MANUTENÇÃO INTELIGENTE
# =============================================================================

create_maintenance_script() {
    section_header "Criando Script de Manutenção Principal" "$SYMBOL_CLEAN"
    
    sudo mkdir -p "$MAINTENANCE_LOG_DIR"
    
    sudo tee "$MAINTENANCE_SCRIPT" > /dev/null << 'EOF'
#!/bin/bash
# =============================================================================
# SCRIPT DE MANUTENÇÃO INTELIGENTE PARA LAPTOP DE DESENVOLVIMENTO
# Preserva dados importantes, remove apenas lixo
# =============================================================================

set -euo pipefail

readonly MAINTENANCE_LOG="/var/log/dev-maintenance/maintenance.log"
readonly STATS_LOG="/var/log/dev-maintenance/stats.log"
readonly CONFIG_FILE="/etc/dev-maintenance.conf"

# Carregar configuração
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Configurações padrão
ALERT_THRESHOLD_GB="${ALERT_THRESHOLD_GB:-3}"
DOCKER_CLEANUP_MODE="${DOCKER_CLEANUP_MODE:-conservative}"
ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-true}"

# =============================================================================
# LOGGING
# =============================================================================

log_maintenance() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" | sudo tee -a "$MAINTENANCE_LOG" >/dev/null
}

# =============================================================================
# DOCKER CLEANUP INTELIGENTE (PRESERVA DBS)
# =============================================================================

docker_smart_cleanup() {
    local mode="${1:-conservative}"
    
    if ! command -v docker >/dev/null 2>&1; then
        return 0
    fi
    
    log_maintenance "INFO" "Docker cleanup mode: $mode"
    
    # Detectar containers de BD automaticamente
    local db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | \
        grep -E "(postgres|mysql|mariadb|mongo|redis|elastic|cassandra|db|database)" || true)
    
    # Detectar volumes de BD
    local db_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | \
        grep -E "(data|postgres|mysql|mongo|redis|elastic|db)" || true)
    
    case "$mode" in
        "conservative")
            # Apenas containers parados (exceto DBs)
            docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | \
            while read container; do
                if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                    docker rm "$container" 2>/dev/null || true
                fi
            done
            
            # Imagens órfãs (não remove base images)
            docker image prune -f >/dev/null 2>&1 || true
            ;;
            
        "moderate")
            # Conservative + imagens não usadas (exceto DBs)
            docker_smart_cleanup conservative
            
            docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | \
            while read image; do
                if [[ ! "$image" =~ (postgres|mysql|mariadb|mongo|redis|elastic) ]]; then
                    if ! docker ps -a --format "{{.Image}}" | grep -q "^$image$"; then
                        docker rmi "$image" 2>/dev/null || true
                    fi
                fi
            done
            
            # Build cache antigo
            docker builder prune --filter "until=168h" -f >/dev/null 2>&1 || true
            ;;
            
        "aggressive")
            # CUIDADO: Apenas para desenvolvimento, preserva DBs
            docker_smart_cleanup moderate
            
            # Networks órfãs
            docker network prune -f >/dev/null 2>&1 || true
            
            # Volumes órfãos (EXCETO dados)
            docker volume ls --format "{{.Name}}" 2>/dev/null | \
            while read volume; do
                if [[ -n "$volume" ]] && ! echo "$db_volumes" | grep -q "^$volume$"; then
                    docker volume rm "$volume" 2>/dev/null || true
                fi
            done
            ;;
    esac
    
    log_maintenance "SUCCESS" "Docker cleanup ($mode) concluído - DBs preservados"
}

# =============================================================================
# LIMPEZA SISTEMA
# =============================================================================

cleanup_system() {
    local mode="$1"
    local space_before=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    
    log_maintenance "INFO" "Iniciando limpeza sistema ($mode)"
    
    case "$mode" in
        "daily")
            # Temp files seguros
            find /tmp -name "*.log" -type f -mtime +1 -delete 2>/dev/null || true
            find /tmp -name "npm-*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
            
            # Cache npm se muito grande
            if [[ -d ~/.npm/_cacache ]]; then
                local npm_size=$(du -sm ~/.npm/_cacache 2>/dev/null | cut -f1 || echo 0)
                [[ $npm_size -gt 500 ]] && npm cache clean --force >/dev/null 2>&1 || true
            fi
            
            # Docker conservador
            docker_smart_cleanup conservative
            ;;
            
        "weekly")
            cleanup_system daily
            
            # APT cleanup
            apt autoremove -y --purge >/dev/null 2>&1 || true
            apt clean >/dev/null 2>&1 || true
            
            # Journal logs
            journalctl --vacuum-time=30d >/dev/null 2>&1 || true
            
            # Temp files mais antigos
            find /tmp -type f -atime +7 -delete 2>/dev/null || true
            find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
            
            # Docker moderado
            docker_smart_cleanup moderate
            ;;
            
        "monthly")
            cleanup_system weekly
            
            # Journal mais agressivo
            journalctl --vacuum-time=60d >/dev/null 2>&1 || true
            
            # Snap cleanup se disponível
            if command -v snap >/dev/null 2>&1; then
                snap list --all | awk '/disabled/{print $1, $3}' | \
                while read snapname revision; do
                    snap remove "$snapname" --revision="$revision" 2>/dev/null || true
                done
            fi
            
            # Cache Python
            find ~/.cache/pip -type f -mtime +30 -delete 2>/dev/null || true
            
            # Docker agressivo (MAS preserva DBs)
            docker_smart_cleanup aggressive
            ;;
    esac
    
    local space_after=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    local freed=$(echo "$space_after - $space_before" | bc -l 2>/dev/null | cut -c1-5)
    
    log_maintenance "SUCCESS" "Limpeza $mode: ${freed}GB libertados (${space_after}GB livres)"
}

# =============================================================================
# MONITORIZAÇÃO DE ESPAÇO
# =============================================================================

monitor_disk_space() {
    local free_space=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log estatísticas
    echo "${timestamp},${free_space}" >> "$STATS_LOG"
    
    # Verificar threshold
    if (( $(echo "$free_space < $ALERT_THRESHOLD_GB" | bc -l) )); then
        log_maintenance "ALERT" "⚠️ ESPAÇO BAIXO: ${free_space}GB restantes!"
        
        # Notificação desktop se disponível
        if [[ "$ENABLE_NOTIFICATIONS" == "true" ]] && command -v notify-send >/dev/null 2>&1; then
            if [[ -n "${DISPLAY:-}" ]]; then
                notify-send "⚠️ Espaço em Disco Baixo" \
                    "Restam apenas ${free_space}GB!\nExecute: dev-clean now" \
                    --urgency=critical 2>/dev/null || true
            fi
        fi
        
        # Auto-cleanup se muito baixo
        if (( $(echo "$free_space < 1.0" | bc -l) )); then
            log_maintenance "WARNING" "Espaço crítico! Executando limpeza automática..."
            cleanup_system weekly
        fi
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    case "${1:-daily}" in
        "daily")
            cleanup_system daily
            monitor_disk_space
            ;;
        "weekly")
            cleanup_system weekly
            monitor_disk_space
            ;;
        "monthly")
            cleanup_system monthly
            monitor_disk_space
            ;;
        "monitor")
            monitor_disk_space
            ;;
        "docker-conservative")
            docker_smart_cleanup conservative
            ;;
        "docker-moderate")
            docker_smart_cleanup moderate
            ;;
        "docker-aggressive")
            docker_smart_cleanup aggressive
            ;;
        *)
            echo "Uso: $0 {daily|weekly|monthly|monitor|docker-*}"
            exit 1
            ;;
    esac
}

main "$@"
EOF
    
    sudo chmod +x "$MAINTENANCE_SCRIPT"
    log_success "Script de manutenção criado: $MAINTENANCE_SCRIPT"
}

# =============================================================================
# CONFIGURAÇÃO E CRON JOBS
# =============================================================================

create_maintenance_config() {
    section_header "Configuração do Sistema" "$SYMBOL_GEAR"
    
    sudo tee "$CONFIG_FILE" > /dev/null << 'EOF'
# Configuração do sistema de manutenção inteligente

# Threshold para alertas (GB)
ALERT_THRESHOLD_GB=3

# Modo de limpeza Docker (conservative|moderate|aggressive)
DOCKER_CLEANUP_MODE=conservative

# Notificações desktop
ENABLE_NOTIFICATIONS=true

# Retenção de logs (dias)
MAINTENANCE_LOG_RETENTION=90

# Auto-cleanup quando espaço crítico
AUTO_CLEANUP_CRITICAL=true
EOF
    
    log_success "Configuração criada: $CONFIG_FILE"
}

setup_cron_jobs() {
    section_header "Configurando Tarefas Automáticas" "$SYMBOL_GEAR"
    
    echo -e "${BLUE}📅 Agendamento proposto:${NC}"
    bullet_list \
        "Diário: 06:30 - limpeza básica + monitorização" \
        "Semanal: Domingo 07:30 - limpeza completa" \
        "Mensal: 1º Domingo 08:30 - limpeza profunda" \
        "Monitorização: A cada 6 horas"
    
    echo ""
    
    if ! confirm "Configurar tarefas automáticas?" "y"; then
        return 0
    fi
    
    # Cron jobs
    echo "30 6 * * * root $MAINTENANCE_SCRIPT daily" | sudo tee /etc/cron.d/dev-maintenance-daily >/dev/null
    echo "30 7 * * 0 root $MAINTENANCE_SCRIPT weekly" | sudo tee /etc/cron.d/dev-maintenance-weekly >/dev/null
    echo "30 8 1-7 * 0 root $MAINTENANCE_SCRIPT monthly" | sudo tee /etc/cron.d/dev-maintenance-monthly >/dev/null
    echo "0 */6 * * * root $MAINTENANCE_SCRIPT monitor" | sudo tee /etc/cron.d/dev-maintenance-monitor >/dev/null
    
    log_success "Cron jobs configurados"
    
    echo ""
    echo -e "${YELLOW}💡 COMANDOS MANUAIS:${NC}"
    bullet_list \
        "dev-clean now - limpeza imediata" \
        "dev-clean deep - limpeza semanal" \
        "dev-clean nuclear - limpeza mensal" \
        "sudo $MAINTENANCE_SCRIPT monitor - verificar espaço"
    
    echo ""
}

# =============================================================================
# COMANDO DEV-CLEAN
# =============================================================================

create_dev_clean_command() {
    section_header "Comando dev-clean" "$SYMBOL_CLEAN"
    
    sudo tee /usr/local/bin/dev-clean > /dev/null << EOF
#!/bin/bash
# Comando prático para limpeza

case "\${1:-status}" in
    "now")
        sudo $MAINTENANCE_SCRIPT daily
        ;;
    "deep")
        sudo $MAINTENANCE_SCRIPT weekly
        ;;
    "nuclear")
        sudo $MAINTENANCE_SCRIPT monthly
        ;;
    "docker")
        echo "🐳 DOCKER USAGE:"
        docker system df 2>/dev/null || echo "Docker não disponível"
        echo ""
        echo "Opções:"
        echo "  dev-clean docker-safe     - Remove apenas containers parados"
        echo "  dev-clean docker-normal   - Remove imagens não usadas"
        echo "  dev-clean docker-deep     - Limpeza agressiva (preserva DBs)"
        ;;
    "docker-safe")
        sudo $MAINTENANCE_SCRIPT docker-conservative
        ;;
    "docker-normal")  
        sudo $MAINTENANCE_SCRIPT docker-moderate
        ;;
    "docker-deep")
        echo "⚠️ Limpeza agressiva (preserva DBs). Continuar? (y/N)"
        read -r response
        if [[ "\$response" =~ ^[Yy] ]]; then
            sudo $MAINTENANCE_SCRIPT docker-aggressive
        fi
        ;;
    "status")
        echo "💾 ESPAÇO ATUAL:"
        df -h / | awk 'NR==2 {printf "   %s usado de %s (%s livre)\\n", \$3, \$2, \$4}'
        echo ""
        if command -v docker >/dev/null 2>&1; then
            echo "🐳 DOCKER:"
            docker system df 2>/dev/null | tail -n +2 | sed 's/^/   /'
            echo ""
        fi
        echo "📊 ÚLTIMA LIMPEZA:"
        if [[ -f $MAINTENANCE_LOG_DIR/maintenance.log ]]; then
            tail -3 $MAINTENANCE_LOG_DIR/maintenance.log | sed 's/^/   /'
        else
            echo "   Nenhuma limpeza executada ainda"
        fi
        ;;
    *)
        echo "🧹 LIMPEZA INTELIGENTE"
        echo "Uso: dev-clean {status|now|deep|nuclear|docker*}"
        echo ""
        echo "  status      - Ver espaço e última limpeza"
        echo "  now         - Limpeza diária (rápida)"
        echo "  deep        - Limpeza semanal (completa)"
        echo "  nuclear     - Limpeza mensal (profunda)"
        echo "  docker*     - Limpeza Docker específica"
        ;;
esac
EOF
    
    sudo chmod +x /usr/local/bin/dev-clean
    log_success "Comando 'dev-clean' disponível"
}

# =============================================================================
# FUNÇÃO PRINCIPAL DO MÓDULO
# =============================================================================

setup_smart_maintenance() {
    log_header "🧹 CONFIGURANDO SISTEMA DE MANUTENÇÃO INTELIGENTE"
    
    echo ""
    echo -e "${BLUE}Sistema de manutenção inclui:${NC}"
    bullet_list \
        "Limpeza automática diária/semanal/mensal" \
        "Docker cleanup que PRESERVA bases de dados" \
        "Monitorização de espaço com alertas" \
        "Logs estruturados e estatísticas" \
        "Comando 'dev-clean' prático" \
        "Configuração personalizável"
    
    echo ""
    
    if ! confirm "Instalar sistema de manutenção?" "y"; then
        log_info "Sistema de manutenção cancelado"
        return 0
    fi
    
    # Criar componentes
    create_maintenance_script
    create_maintenance_config
    setup_cron_jobs
    create_dev_clean_command
    
    # Teste inicial
    echo ""
    section_header "Teste Inicial" "$SYMBOL_TESTING"
    
    if confirm "Executar teste de monitorização?" "y"; then
        sudo "$MAINTENANCE_SCRIPT" monitor
        echo ""
        log_success "Teste concluído - ver logs em $MAINTENANCE_LOG_DIR/"
    fi
    
    log_success "🎉 Sistema de manutenção inteligente instalado!"
    echo ""
    echo -e "${YELLOW}💡 PRÓXIMOS PASSOS:${NC}"
    bullet_list \
        "Testar: dev-clean status" \
        "Limpeza manual: dev-clean now" \
        "Ver logs: tail -f $MAINTENANCE_LOG_DIR/maintenance.log" \
        "Configurar: $CONFIG_FILE"
    
    echo ""
}