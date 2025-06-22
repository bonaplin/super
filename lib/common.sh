#!/bin/bash
# =============================================================================
# BIBLIOTECA COMUM - FUNÇÕES REUTILIZÁVEIS
# =============================================================================

# Carregar cores se disponível (com verificação de existência)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ -f "$SCRIPT_DIR/lib/colors.sh" ]] && [[ -z "${RED:-}" ]]; then
    source "$SCRIPT_DIR/lib/colors.sh"
fi

# Variáveis globais
if [[ -z "${LOG_FILE:-}" ]]; then
    readonly LOG_FILE="/tmp/laptop-optimizer.log"
fi
readonly BACKUP_DIR="$HOME/.laptop-optimizer-backup-$(date +%Y%m%d-%H%M%S)"

# =============================================================================
# LOGGING ESTRUTURADO
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log para ficheiro
    echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE"

    # Output colorido para terminal (com fallback se cores não disponíveis)
    case "$level" in
        "INFO")    echo -e "${BLUE:-}ℹ${NC:-} ${message}" ;;
        "SUCCESS") echo -e "${GREEN:-}✅${NC:-} ${message}" ;;
        "WARNING") echo -e "${YELLOW:-}⚠${NC:-} ${message}" ;;
        "ERROR")   echo -e "${RED:-}❌${NC:-} ${message}" ;;
        "HEADER")  echo -e "${CYAN:-}${message}${NC:-}" ;;
    esac
}

log_info() {
    log "INFO" "$*"
}

log_success() {
    log "SUCCESS" "$*"
}

log_warning() {
    log "WARNING" "$*"
}

log_error() {
    log "ERROR" "$*"
}

log_header() {
    echo ""
    echo -e "${CYAN:-}╔$(printf '═%.0s' {1..78})╗${NC:-}"
    echo -e "${CYAN:-}║$(printf ' %.0s' {1..78})║${NC:-}"
    echo -e "${CYAN:-}║  $1$(printf ' %.0s' $(seq 1 $((76 - ${#1}))))║${NC:-}"
    echo -e "${CYAN:-}║$(printf ' %.0s' {1..78})║${NC:-}"
    echo -e "${CYAN:-}╚$(printf '═%.0s' {1..78})╝${NC:-}"
    echo ""
}

# =============================================================================
# INTERAÇÃO COM UTILIZADOR
# =============================================================================

confirm() {
    local question="$1"
    local default="${2:-n}"
    local response

    read -p "$(echo -e "${YELLOW:-}?${NC:-} ${question} [${default}]: ")" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
}

pause_and_return() {
    echo ""
    read -p "$(echo -e "${CYAN:-}Prima Enter para continuar...${NC:-}")"
    clear
}

choose_option() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "${YELLOW:-}$prompt${NC:-}"
    echo ""

    for i in "${!options[@]}"; do
        echo -e "  ${YELLOW:-}$((i+1)).${NC:-} ${options[i]}"
    done
    echo ""

    local choice
    while true; do
        read -p "$(echo -e "${CYAN:-}Escolha (1-${#options[@]}):${NC:-} ")" choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
            return $((choice - 1))
        else
            echo -e "${RED:-}❌ Opção inválida. Escolha entre 1 e ${#options[@]}.${NC:-}"
        fi
    done
}

# =============================================================================
# UTILITÁRIOS SISTEMA
# =============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_ubuntu() {
    [[ -f /etc/lsb-release ]] && grep -q "Ubuntu" /etc/lsb-release 2>/dev/null
}

is_debian() {
    [[ -f /etc/debian_version ]]
}

get_ram_gb() {
    free -g | awk '/^Mem:/{print $2}' 2>/dev/null || echo "4"
}

get_cpu_cores() {
    nproc 2>/dev/null || echo "2"
}

get_free_space_gb() {
    df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}' 2>/dev/null || echo "10.0"
}

detect_storage_type() {
    # Detectar NVMe primeiro
    if [[ -d /sys/block/nvme0n1 ]]; then
        echo "nvme"
    # Verificar se é SSD (rotational = 0)
    elif [[ -f /sys/block/sda/queue/rotational ]] && [[ $(cat /sys/block/sda/queue/rotational 2>/dev/null || echo "1") -eq 0 ]]; then
        echo "ssd"
    else
        echo "hdd"
    fi
}

is_laptop() {
    # Várias formas de detectar laptop
    [[ -d /sys/class/power_supply/BAT* ]] || \
    ([[ -f /sys/devices/virtual/dmi/id/chassis_type ]] && \
     grep -qE "^(9|10|14)$" /sys/devices/virtual/dmi/id/chassis_type 2>/dev/null)
}

has_network_connection() {
    ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1
}

# =============================================================================
# DETECÇÃO DE AMBIENTE EMPRESARIAL
# =============================================================================

detect_vpn_active() {
    # Detectar várias formas de VPN
    ip route 2>/dev/null | grep -qE "tun|tap|ppp" || \
    pgrep -f "openvpn|openconnect|strongswan|wireguard" >/dev/null 2>&1 || \
    [[ -d /proc/sys/net/ipv4/conf/tun* ]] || \
    [[ -d /proc/sys/net/ipv4/conf/tap* ]]
}

detect_enterprise_docker() {
    [[ -f /etc/docker/daemon.json ]] && \
    grep -qE "registry|proxy|insecure-registries" /etc/docker/daemon.json 2>/dev/null
}

detect_enterprise_ssh() {
    [[ -f /etc/ssh/sshd_config ]] && \
    grep -qE "# Company|# Enterprise|# Corporate|AuthorizedKeysCommand" /etc/ssh/sshd_config 2>/dev/null
}

detect_enterprise_dns() {
    local dns_servers=""
    if [[ -f /etc/systemd/resolved.conf ]]; then
        dns_servers=$(grep "^DNS=" /etc/systemd/resolved.conf 2>/dev/null | cut -d= -f2)
        [[ -n "$dns_servers" && "$dns_servers" != "1.1.1.1" && "$dns_servers" != "8.8.8.8" ]]
    else
        return 1
    fi
}

# =============================================================================
# GESTÃO DE PROCESSOS E SERVIÇOS
# =============================================================================

service_exists() {
    systemctl list-unit-files --type=service 2>/dev/null | grep -q "^$1.service" || return 1
}

service_is_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

service_is_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

safe_service_action() {
    local action="$1"
    local service="$2"

    if service_exists "$service"; then
        log_info "$action $service..."
        if sudo systemctl "$action" "$service" 2>/dev/null; then
            log_success "$service $action com sucesso"
            return 0
        else
            log_warning "Falha ao $action $service"
            return 1
        fi
    else
        log_warning "Serviço $service não existe"
        return 1
    fi
}

# =============================================================================
# GESTÃO DE PACOTES
# =============================================================================

package_is_installed() {
    if command_exists dpkg; then
        dpkg -l "$1" 2>/dev/null | grep -q "^ii"
    elif command_exists rpm; then
        rpm -q "$1" >/dev/null 2>&1
    else
        # Fallback: verificar se comando existe
        command_exists "$1"
    fi
}

safe_apt_install() {
    local packages=("$@")
    local failed_packages=()

    # Verificar se apt existe
    if ! command_exists apt; then
        log_error "APT não disponível neste sistema"
        return 1
    fi

    log_info "Instalando pacotes: ${packages[*]}"

    # Atualizar cache se necessário
    if [[ ! -f /var/cache/apt/pkgcache.bin ]] || \
       [[ $(find /var/cache/apt/pkgcache.bin -mtime +1 2>/dev/null) ]]; then
        log_info "Atualizando cache apt..."
        sudo apt update -qq 2>/dev/null || log_warning "Falha ao atualizar cache"
    fi

    # Instalar cada pacote individualmente para melhor controlo
    for package in "${packages[@]}"; do
        if package_is_installed "$package"; then
            log_info "$package já instalado"
            continue
        fi

        if sudo apt install -y "$package" >/dev/null 2>&1; then
            log_success "$package instalado"
        else
            log_warning "Falha ao instalar $package"
            failed_packages+=("$package")
        fi
    done

    # Reportar falhas se existirem
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Pacotes que falharam: ${failed_packages[*]}"
        return 1
    fi

    return 0
}

# =============================================================================
# GESTÃO DE FICHEIROS E CONFIGURAÇÕES
# =============================================================================

backup_file() {
    local file="$1"
    local backup_file="${file}.backup.$(date +%Y%m%d-%H%M%S)"

    if [[ -f "$file" ]]; then
        sudo cp "$file" "$backup_file" 2>/dev/null || cp "$file" "$backup_file" 2>/dev/null
        log_info "Backup criado: $backup_file"
        return 0
    else
        log_warning "Ficheiro não existe: $file"
        return 1
    fi
}

safe_write_config() {
    local file="$1"
    local content="$2"
    local backup_original="${3:-true}"

    # Backup do original se pedido
    if [[ "$backup_original" == "true" && -f "$file" ]]; then
        backup_file "$file"
    fi

    # Escrever novo ficheiro
    if echo "$content" | sudo tee "$file" >/dev/null 2>&1; then
        log_success "Configuração escrita: $file"
        return 0
    else
        log_error "Falha ao escrever: $file"
        return 1
    fi
}

append_to_file() {
    local file="$1"
    local content="$2"
    local marker="$3"

    # Verificar se conteúdo já existe
    if [[ -n "$marker" ]] && grep -q "$marker" "$file" 2>/dev/null; then
        log_info "Configuração já existe em $file"
        return 0
    fi

    # Adicionar conteúdo
    if echo "$content" | sudo tee -a "$file" >/dev/null 2>&1; then
        log_success "Conteúdo adicionado a $file"
        return 0
    else
        log_error "Falha ao adicionar a $file"
        return 1
    fi
}

# =============================================================================
# UTILITÁRIOS DE VALIDAÇÃO
# =============================================================================

validate_positive_integer() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]
}

validate_file_path() {
    local path="$1"
    [[ -f "$path" || -d "$(dirname "$path")" ]]
}

validate_command_safe() {
    local cmd="$1"
    [[ "$cmd" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# =============================================================================
# INFORMAÇÃO DO SISTEMA
# =============================================================================

show_system_info() {
    echo -e "${BLUE:-}📊 INFORMAÇÃO DO SISTEMA:${NC:-}"
    echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Desconhecido")"
    echo "   Kernel: $(uname -r)"
    echo "   CPU: $(get_cpu_cores) cores"
    echo "   RAM: $(get_ram_gb)GB"
    echo "   Storage: $(detect_storage_type | tr '[:lower:]' '[:upper:]')"
    echo "   Free space: $(get_free_space_gb)GB"
    echo "   Laptop: $(is_laptop && echo "Sim" || echo "Não")"
    echo "   Network: $(has_network_connection && echo "Online" || echo "Offline")"
    echo ""
}

get_system_load() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',' 2>/dev/null || echo "0.0"
}

get_memory_usage_percent() {
    free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}' 2>/dev/null || echo "0.0"
}

get_disk_usage_percent() {
    df / | awk 'NR==2 {print $5}' | tr -d '%' 2>/dev/null || echo "0"
}

# =============================================================================
# FUNÇÕES DE BENCHMARK BÁSICAS
# =============================================================================

benchmark_cpu() {
    log_info "🔬 Teste CPU (5 segundos)..."
    local start_time=$(date +%s.%N 2>/dev/null || date +%s)
    timeout 5s yes >/dev/null 2>&1 || true
    local end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local duration="5.0"
    if command_exists bc; then
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null | cut -c1-4 || echo "5.0")
    fi
    echo "   ⏱️ CPU stress test: ${duration}s"
}

benchmark_disk_write() {
    log_info "💿 Teste escrita disco (50MB)..."
    local start_time=$(date +%s.%N 2>/dev/null || date +%s)
    dd if=/dev/zero of=/tmp/benchmark_test bs=1M count=50 2>/dev/null || true
    sync 2>/dev/null || true
    local end_time=$(date +%s.%N 2>/dev/null || date +%s)
    rm -f /tmp/benchmark_test 2>/dev/null || true
    local duration="2.0"
    local speed="25.0"
    if command_exists bc; then
        duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null | cut -c1-4 || echo "2.0")
        speed=$(echo "50 / $duration" | bc -l 2>/dev/null | cut -c1-5 || echo "25.0")
    fi
    echo "   💿 Velocidade escrita: ${speed}MB/s"
}

benchmark_network() {
    if has_network_connection; then
        log_info "📶 Teste rede..."
        local ping_time=$(ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F/ '{print $5}' | cut -c1-5 2>/dev/null || echo "50.0")
        echo "   📶 Ping médio: ${ping_time}ms"
    else
        echo "   📶 Sem ligação de rede"
    fi
}

# =============================================================================
# CLEANUP E FINALIZAÇÃO
# =============================================================================

cleanup_temp_files() {
    log_info "🧹 Limpeza de ficheiros temporários..."
    rm -f /tmp/benchmark_test* /tmp/laptop-optimizer-* 2>/dev/null || true
}

show_operation_summary() {
    local operation="$1"
    local status="$2"

    echo ""
    echo -e "${CYAN:-}📋 RESUMO DA OPERAÇÃO: $operation${NC:-}"
    echo "=================================="
    echo -e "Status: $status"
    echo -e "Tempo: $(date)"
    echo -e "Log: $LOG_FILE"
    echo ""
}

# =============================================================================
# VERIFICAÇÃO DE DEPENDÊNCIAS
# =============================================================================

check_required_commands() {
    local required_commands=("sudo" "systemctl" "free" "df" "nproc")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Comandos em falta: ${missing_commands[*]}"
        return 1
    fi

    return 0
}

# =============================================================================
# FUNCÕES DE TEMPLATE PARA COMPATIBILIDADE
# =============================================================================

# Funções de status message (compatibilidade com outros módulos)
status_message() {
    local type="$1"
    local message="$2"

    case "$type" in
        "success")  echo -e "${GREEN:-}✅${NC:-} $message" ;;
        "error")    echo -e "${RED:-}❌${NC:-} $message" ;;
        "warning")  echo -e "${YELLOW:-}⚠️${NC:-} $message" ;;
        "info")     echo -e "${BLUE:-}ℹ️${NC:-} $message" ;;
        *)          echo -e "• $message" ;;
    esac
}

# Section header (compatibilidade)
section_header() {
    local title="$1"
    local icon="${2:-⚙️}"

    echo ""
    echo -e "${CYAN:-}${icon} ${title}${NC:-}"
    echo -e "${CYAN:-}$(printf '─%.0s' $(seq 1 $((${#title} + 3))))${NC:-}"
}

# Bullet list (compatibilidade)
bullet_list() {
    while [[ $# -gt 0 ]]; do
        echo -e "   ${BLUE:-}•${NC:-} $1"
        shift
    done
}