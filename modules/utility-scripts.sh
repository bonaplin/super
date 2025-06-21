#!/bin/bash
# =============================================================================
# MÓDULO: SCRIPTS UTILITÁRIOS PRÁTICOS
# Cria scripts práticos para uso diário - especialidade única
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# DEV-STATUS - DASHBOARD DO SISTEMA
# =============================================================================

create_dev_status() {
    section_header "Criando dev-status (Dashboard)" "$SYMBOL_COMPUTER"
    
    sudo tee /usr/local/bin/dev-status > /dev/null << 'EOF'
#!/bin/bash
# Dashboard completo do laptop de desenvolvimento

clear
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🚀 LAPTOP DEVELOPER - STATUS                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# SISTEMA BASE
# =============================================================================

echo "🖥️ SISTEMA:"
echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p 2>/dev/null || uptime | awk -F, '{print $1}' | awk '{print $3,$4}')"

# CPU
local cpu_cores=$(nproc)
local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
local cpu_temp=""
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    cpu_temp=" ($(cat /sys/class/thermal/thermal_zone0/temp | head -c 2)°C)"
fi
echo "   CPU: $cpu_cores cores, load: $cpu_load$cpu_temp"

# RAM
local ram_info=$(free -h | awk '/^Mem:/ {printf "%s usado de %s", $3, $2}')
echo "   RAM: $ram_info"

# Bateria se disponível
if [[ -f /sys/class/power_supply/BAT*/capacity ]]; then
    local battery=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
    local ac_status="desconhecido"
    if [[ -f /sys/class/power_supply/A*/online ]]; then
        [[ $(cat /sys/class/power_supply/A*/online 2>/dev/null) == "1" ]] && ac_status="AC" || ac_status="bateria"
    fi
    echo "   Energia: ${battery}% ($ac_status)"
fi

echo ""

# =============================================================================
# ARMAZENAMENTO
# =============================================================================

echo "💾 ARMAZENAMENTO:"
df -h | grep -E "^/dev/" | while read line; do
    local device=$(echo $line | awk '{print $1}')
    local size=$(echo $line | awk '{print $2}')
    local used=$(echo $line | awk '{print $3}')
    local available=$(echo $line | awk '{print $4}')
    local percent=$(echo $line | awk '{print $5}')
    local mount=$(echo $line | awk '{print $6}')
    
    local status="🟢"
    local percent_num=$(echo $percent | tr -d '%')
    [[ $percent_num -gt 80 ]] && status="🟡"
    [[ $percent_num -gt 90 ]] && status="🔴"
    
    echo "   $status $mount: $used usado de $size ($available livre) - $percent"
done

echo ""

# =============================================================================
# FERRAMENTAS DE DESENVOLVIMENTO
# =============================================================================

echo "🛠️ DESENVOLVIMENTO:"

# Node.js
if command -v node >/dev/null 2>&1; then
    echo "   ✅ Node.js: $(node --version)"
    echo "   ✅ npm: $(npm --version)"
else
    echo "   ❌ Node.js: Não instalado"
fi

# Python
if command -v python3 >/dev/null 2>&1; then
    echo "   ✅ Python: $(python3 --version | awk '{print $2}')"
else
    echo "   ❌ Python: Não instalado"
fi

# Git
if command -v git >/dev/null 2>&1; then
    local git_user=$(git config --global user.name 2>/dev/null || echo "não configurado")
    echo "   ✅ Git: $(git --version | awk '{print $3}') ($git_user)"
else
    echo "   ❌ Git: Não instalado"
fi

# Docker
if command -v docker >/dev/null 2>&1; then
    local containers=$(docker ps -q 2>/dev/null | wc -l || echo "0")
    echo "   ✅ Docker: $containers containers ativos"
else
    echo "   ❌ Docker: Não instalado"
fi

# Shell moderno
if command -v zsh >/dev/null 2>&1; then
    local current_shell=$(basename "$SHELL")
    echo "   ✅ Zsh: disponível (atual: $current_shell)"
    [[ -d ~/.oh-my-zsh ]] && echo "   ✅ Oh-My-Zsh: instalado" || echo "   ❌ Oh-My-Zsh: não instalado"
else
    echo "   ❌ Zsh: Não instalado"
fi

echo ""

# =============================================================================
# OTIMIZAÇÕES ATIVAS
# =============================================================================

echo "⚙️ OTIMIZAÇÕES:"

# Sysctl configs
local sysctl_configs=$(ls /etc/sysctl.d/99-dev-*.conf 2>/dev/null | wc -l)
if [[ $sysctl_configs -gt 0 ]]; then
    echo "   ✅ Kernel: $sysctl_configs configurações ativas"
    # Mostrar algumas configs importantes
    local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "padrão")
    local inotify=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "padrão")
    echo "      • swappiness: $swappiness (padrão Ubuntu: 60)"
    echo "      • inotify watches: $inotify (padrão Ubuntu: 8192)"
else
    echo "   ❌ Kernel: Configurações padrão Ubuntu"
fi

# TLP
if command -v tlp >/dev/null 2>&1; then
    if systemctl is-active --quiet tlp; then
        echo "   ✅ TLP: Ativo (gestão energia)"
    else
        echo "   ⚠️ TLP: Instalado mas inativo"
    fi
else
    echo "   ❌ TLP: Não instalado"
fi

# Auto-CPUfreq
if command -v auto-cpufreq >/dev/null 2>&1; then
    if pgrep -f auto-cpufreq >/dev/null; then
        echo "   ✅ Auto-CPUfreq: Ativo"
    else
        echo "   ⚠️ Auto-CPUfreq: Instalado mas inativo"
    fi
else
    echo "   ❌ Auto-CPUfreq: Não instalado"
fi

# Sistema de manutenção
if [[ -f /usr/local/bin/dev-maintenance ]]; then
    local last_cleanup=$(ls -la /var/log/dev-maintenance/maintenance.log 2>/dev/null | awk '{print $6,$7,$8}' || echo "nunca")
    echo "   ✅ Manutenção: Configurada (última: $last_cleanup)"
else
    echo "   ❌ Manutenção: Não configurada"
fi

echo ""

# =============================================================================
# REDE E CONECTIVIDADE
# =============================================================================

echo "📶 REDE:"

# Interfaces
local interfaces=$(ip addr show | grep -E "^[0-9]+:" | grep -v lo | awk -F: '{print $2}' | xargs | tr ' ' ',')
echo "   Interfaces: $interfaces"

# DNS
local dns=$(systemd-resolve --status 2>/dev/null | grep "DNS Servers" | head -1 | awk -F: '{print $2}' | xargs || echo "automático")
echo "   DNS: $dns"

# Conectividade
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    local ping_time=$(ping -c 1 8.8.8.8 2>/dev/null | grep "time=" | awk -F"time=" '{print $2}' | awk '{print $1}' | head -1)
    echo "   ✅ Internet: Online (ping: ${ping_time}ms)"
else
    echo "   ❌ Internet: Offline ou lento"
fi

echo ""

# =============================================================================
# COMANDOS ÚTEIS
# =============================================================================

echo "📋 COMANDOS RÁPIDOS:"
echo "   dev-tools            - Verificar ferramentas instaladas"
echo "   dev-clean status     - Ver espaço detalhado + Docker"
echo "   dev-health           - Health check completo"
echo "   dev-benchmark        - Testar performance"
echo "   logs                 - Ver logs sistema (journalctl -f)"
echo ""
echo "🎯 LIMPEZA:"
echo "   dev-clean now        - Limpeza rápida"
echo "   dev-clean deep       - Limpeza semanal"
echo "   dev-clean docker     - Ver uso Docker"
echo ""
EOF
    
    sudo chmod +x /usr/local/bin/dev-status
    log_success "dev-status criado: dashboard completo do sistema"
}

# =============================================================================
# DEV-TOOLS - VERIFICAR FERRAMENTAS
# =============================================================================

create_dev_tools() {
    section_header "Criando dev-tools (Verificador)" "$SYMBOL_WRENCH"
    
    sudo tee /usr/local/bin/dev-tools > /dev/null << 'EOF'
#!/bin/bash
# Verificar estado das ferramentas de desenvolvimento

echo "🛠️ FERRAMENTAS DE DESENVOLVIMENTO"
echo "=================================="
echo ""

# =============================================================================
# FERRAMENTAS ESSENCIAIS
# =============================================================================

echo "📦 ESSENCIAIS:"

# Node.js ecosystem
if command -v node >/dev/null 2>&1; then
    echo "✅ Node.js: $(node --version)"
    echo "✅ npm: $(npm --version)"
    
    # Verificar ferramentas globais comuns
    local global_tools=("nodemon" "live-server" "http-server" "typescript" "create-react-app")
    for tool in "${global_tools[@]}"; do
        if npm list -g "$tool" >/dev/null 2>&1; then
            echo "   ✅ $tool: instalado globalmente"
        fi
    done
else
    echo "❌ Node.js: Não instalado"
    echo "   💡 Instalar: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt install nodejs"
fi

if command -v yarn >/dev/null 2>&1; then
    echo "✅ Yarn: $(yarn --version)"
else
    echo "❌ Yarn: Não instalado"
fi

echo ""

# Python ecosystem  
if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python3: $(python3 --version | awk '{print $2}')"
    echo "✅ pip3: $(pip3 --version | awk '{print $2}')"
    
    # Virtual env
    if python3 -m venv --help >/dev/null 2>&1; then
        echo "✅ venv: Disponível"
    else
        echo "❌ venv: Não disponível"
    fi
else
    echo "❌ Python3: Não instalado"
fi

echo ""

# =============================================================================
# BUILD TOOLS
# =============================================================================

echo "🔨 BUILD TOOLS:"

if command -v gcc >/dev/null 2>&1; then
    echo "✅ GCC: $(gcc --version | head -1 | awk '{print $4}')"
else
    echo "❌ GCC: Não instalado"
fi

if command -v make >/dev/null 2>&1; then
    echo "✅ Make: Disponível"
else
    echo "❌ Make: Não instalado"
fi

if command -v cmake >/dev/null 2>&1; then
    echo "✅ CMake: $(cmake --version | head -1 | awk '{print $3}')"
else
    echo "❌ CMake: Não instalado"
fi

if command -v pkg-config >/dev/null 2>&1; then
    echo "✅ pkg-config: Disponível"
else
    echo "❌ pkg-config: Não instalado"
fi

echo ""

# =============================================================================
# FERRAMENTAS MODERNAS
# =============================================================================

echo "🚀 FERRAMENTAS MODERNAS:"

# Shell
if command -v zsh >/dev/null 2>&1; then
    echo "✅ Zsh: $(zsh --version | awk '{print $2}')"
    if [[ -d ~/.oh-my-zsh ]]; then
        echo "   ✅ Oh-My-Zsh: Instalado"
    else
        echo "   ❌ Oh-My-Zsh: Não instalado"
    fi
    
    local current_shell=$(basename "$SHELL")
    if [[ "$current_shell" == "zsh" ]]; then
        echo "   ✅ Zsh é o shell padrão"
    else
        echo "   ⚠️ Shell atual: $current_shell (não é zsh)"
    fi
else
    echo "❌ Zsh: Não instalado"
fi

# Ferramentas CLI modernas
local modern_tools=(
    "fzf:Fuzzy finder"
    "fd:Find melhorado" 
    "bat:Cat com syntax highlighting"
    "exa:ls melhorado"
    "eza:ls melhorado (fork moderno)"
    "rg:grep melhorado (ripgrep)"
    "zoxide:cd inteligente"
    "direnv:ambientes por diretório"
)

for tool_desc in "${modern_tools[@]}"; do
    local tool="${tool_desc%%:*}"
    local desc="${tool_desc##*:}"
    
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool: $desc"
    else
        echo "❌ $tool: $desc (não instalado)"
    fi
done

echo ""

# =============================================================================
# GIT E DESENVOLVIMENTO
# =============================================================================

echo "📚 GIT & DESENVOLVIMENTO:"

if command -v git >/dev/null 2>&1; then
    echo "✅ Git: $(git --version | awk '{print $3}')"
    
    if git config --global user.name >/dev/null 2>&1; then
        local git_user=$(git config --global user.name)
        local git_email=$(git config --global user.email)
        echo "   ✅ Configurado: $git_user ($git_email)"
    else
        echo "   ⚠️ Não configurado (git config --global user.name/email)"
    fi
    
    # Git tools
    if command -v gh >/dev/null 2>&1; then
        echo "   ✅ GitHub CLI: $(gh --version | head -1 | awk '{print $3}')"
    else
        echo "   ❌ GitHub CLI: Não instalado"
    fi
    
    if command -v lazygit >/dev/null 2>&1; then
        echo "   ✅ Lazygit: Git TUI instalado"
    else
        echo "   ❌ Lazygit: Git TUI não instalado"
    fi
else
    echo "❌ Git: Não instalado"
fi

echo ""

# =============================================================================
# DOCKER
# =============================================================================

echo "🐳 CONTAINERIZAÇÃO:"

if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
    
    # Verificar se user está no grupo docker
    if groups "$USER" | grep -q docker; then
        echo "   ✅ Utilizador no grupo docker"
    else
        echo "   ⚠️ Utilizador não está no grupo docker"
        echo "      💡 Adicionar: sudo usermod -aG docker $USER"
    fi
    
    # Docker compose
    if command -v docker-compose >/dev/null 2>&1; then
        echo "   ✅ Docker Compose: $(docker-compose --version | awk '{print $3}' | tr -d ',')"
    else
        echo "   ❌ Docker Compose: Não instalado"
    fi
    
    # Estado do Docker
    if systemctl is-active --quiet docker; then
        local containers=$(docker ps -q 2>/dev/null | wc -l)
        local images=$(docker images -q 2>/dev/null | wc -l)
        echo "   📊 Estado: $containers containers, $images imagens"
    else
        echo "   ⚠️ Docker daemon não está ativo"
    fi
else
    echo "❌ Docker: Não instalado"
fi

echo ""

# =============================================================================
# RESUMO E RECOMENDAÇÕES
# =============================================================================

echo "💡 RECOMENDAÇÕES:"

# Contar ferramentas em falta
local missing_tools=0

[[ ! $(command -v node) ]] && ((missing_tools++))
[[ ! $(command -v git) ]] && ((missing_tools++))
[[ ! $(command -v docker) ]] && ((missing_tools++))
[[ ! $(command -v zsh) ]] && ((missing_tools++))

if [[ $missing_tools -eq 0 ]]; then
    echo "✅ Ambiente de desenvolvimento completo!"
elif [[ $missing_tools -le 2 ]]; then
    echo "⚠️ Ambiente quase completo - apenas $missing_tools ferramentas em falta"
else
    echo "❌ Várias ferramentas essenciais em falta ($missing_tools)"
    echo ""
    echo "🔧 Para instalar ferramentas em falta:"
    echo "   Execute novamente: ./optimize-laptop.sh"
    echo "   Ou use opção: 1 (Ferramentas da comunidade)"
fi

echo ""
echo "📋 VERIFICAÇÕES ADICIONAIS:"
echo "   dev-status      - Dashboard completo"
echo "   dev-health      - Health check sistema"
echo "   dev-benchmark   - Testar performance"
echo ""
EOF
    
    sudo chmod +x /usr/local/bin/dev-tools
    log_success "dev-tools criado: verificador de ferramentas"
}

# =============================================================================
# DEV-HEALTH - HEALTH CHECK COMPLETO
# =============================================================================

create_dev_health() {
    section_header "Criando dev-health (Health Check)" "$SYMBOL_SHIELD"
    
    sudo tee /usr/local/bin/dev-health > /dev/null << 'EOF'
#!/bin/bash
# Health check completo do sistema

echo "🏥 HEALTH CHECK COMPLETO"
echo "========================"
echo ""

# =============================================================================
# SISTEMA BASE
# =============================================================================

echo "🖥️ SISTEMA BASE:"
echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p 2>/dev/null || uptime)"

# Load average
local load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
local cpu_cores=$(nproc)
local load_per_core=$(echo "scale=2; $load_1min / $cpu_cores" | bc -l 2>/dev/null || echo "N/A")

if (( $(echo "$load_per_core > 2" | bc -l 2>/dev/null || echo 0) )); then
    echo "   ⚠️ Load alto: $load_1min ($load_per_core por core)"
else
    echo "   ✅ Load normal: $load_1min ($load_per_core por core)"
fi

echo ""

# =============================================================================
# MEMÓRIA E ARMAZENAMENTO
# =============================================================================

echo "💾 RECURSOS:"

# Memória
local ram_total=$(free -g | awk '/^Mem:/ {print $2}')
local ram_used=$(free -g | awk '/^Mem:/ {print $3}')
local ram_percent=$(echo "scale=1; $ram_used * 100 / $ram_total" | bc -l 2>/dev/null || echo "N/A")

if (( $(echo "$ram_percent > 90" | bc -l 2>/dev/null || echo 0) )); then
    echo "   ⚠️ RAM: ${ram_used}GB/${ram_total}GB (${ram_percent}% - ALTO)"
else
    echo "   ✅ RAM: ${ram_used}GB/${ram_total}GB (${ram_percent}%)"
fi

# Swap
local swap_used=$(free -h | awk '/^Swap:/ {print $3}')
if [[ "$swap_used" != "0B" && -n "$swap_used" ]]; then
    echo "   ⚠️ Swap em uso: $swap_used"
else
    echo "   ✅ Swap: não utilizado"
fi

# Espaço em disco
local free_space=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
local used_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

if [[ $used_percent -gt 90 ]]; then
    echo "   ⚠️ Disco: ${free_space}GB livres (${used_percent}% usado - CRÍTICO)"
elif [[ $used_percent -gt 80 ]]; then
    echo "   ⚠️ Disco: ${free_space}GB livres (${used_percent}% usado - ALTO)"
else
    echo "   ✅ Disco: ${free_space}GB livres (${used_percent}% usado)"
fi

echo ""

# =============================================================================
# SERVIÇOS CRÍTICOS
# =============================================================================

echo "🔧 SERVIÇOS:"

local services=(
    "ssh:SSH Server"
    "docker:Docker"
    "tlp:TLP Energy"
    "systemd-resolved:DNS Resolution"
    "fail2ban:SSH Protection"
)

for service_desc in "${services[@]}"; do
    local service="${service_desc%%:*}"
    local desc="${service_desc##*:}"
    
    if systemctl list-unit-files --type=service | grep -q "^$service.service"; then
        if systemctl is-active --quiet "$service"; then
            echo "   ✅ $desc: Ativo"
        else
            echo "   ⚠️ $desc: Inativo"
        fi
    else
        echo "   ❌ $desc: Não instalado"
    fi
done

echo ""

# =============================================================================
# REDE E CONECTIVIDADE
# =============================================================================

echo "📶 REDE:"

# Conectividade básica
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "   ✅ Internet: Conectado"
    
    # DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        echo "   ✅ DNS: Funcionando"
    else
        echo "   ⚠️ DNS: Problemas de resolução"
    fi
else
    echo "   ❌ Internet: Sem conectividade"
fi

# Verificar VPN
if ip route | grep -qE "tun|tap|ppp"; then
    echo "   ℹ️ VPN: Ativo"
else
    echo "   ✅ VPN: Não ativo"
fi

echo ""

# =============================================================================
# CONFIGURAÇÕES OTIMIZADAS
# =============================================================================

echo "⚙️ OTIMIZAÇÕES:"

# Sysctl
if [[ -f /etc/sysctl.d/99-dev-inotify.conf ]]; then
    local inotify_watches=$(cat /proc/sys/fs/inotify/max_user_watches)
    echo "   ✅ inotify: $inotify_watches watches (otimizado)"
else
    echo "   ⚠️ inotify: Configuração padrão (pode ser limitado para IDEs)"
fi

# Swappiness
local swappiness=$(cat /proc/sys/vm/swappiness)
if [[ $swappiness -le 15 ]]; then
    echo "   ✅ Swappiness: $swappiness (otimizado)"
else
    echo "   ⚠️ Swappiness: $swappiness (padrão Ubuntu: 60)"
fi

# TLP
if command -v tlp >/dev/null 2>&1 && systemctl is-active --quiet tlp; then
    echo "   ✅ Gestão energia: TLP ativo"
else
    echo "   ⚠️ Gestão energia: Não otimizada"
fi

echo ""

# =============================================================================
# ALERTAS E PROBLEMAS
# =============================================================================

echo "⚠️ ALERTAS:"

local alerts=()

# Verificar problemas críticos
[[ $used_percent -gt 90 ]] && alerts+=("Espaço em disco crítico: ${used_percent}%")
[[ $(echo "$ram_percent > 90" | bc -l 2>/dev/null || echo 0) == 1 ]] && alerts+=("Uso de RAM alto: ${ram_percent}%")
[[ $(echo "$load_per_core > 2" | bc -l 2>/dev/null || echo 0) == 1 ]] && alerts+=("Load do sistema alto: $load_1min")

# Verificar atualizações pendentes
local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable 2>/dev/null || echo 0)
[[ $updates -gt 50 ]] && alerts+=("Muitas atualizações pendentes: $updates")

# Verificar logs de erro recentes
local errors=$(journalctl --since "1 hour ago" --priority=err -q --no-pager 2>/dev/null | wc -l)
[[ $errors -gt 10 ]] && alerts+=("Muitos erros nos logs: $errors na última hora")

if [[ ${#alerts[@]} -eq 0 ]]; then
    echo "   ✅ Sem alertas críticos"
else
    for alert in "${alerts[@]}"; do
        echo "   🔴 $alert"
    done
fi

echo ""

# =============================================================================
# RECOMENDAÇÕES
# =============================================================================

echo "💡 RECOMENDAÇÕES:"

if [[ $used_percent -gt 80 ]]; then
    echo "   🧹 Executar limpeza: dev-clean deep"
fi

if [[ ! -f /etc/sysctl.d/99-dev-inotify.conf ]]; then
    echo "   🔧 Configurar otimizações: ./optimize-laptop.sh"
fi

if [[ $updates -gt 20 ]]; then
    echo "   📦 Atualizar sistema: sudo apt update && sudo apt upgrade"
fi

if [[ ${#alerts[@]} -eq 0 && $used_percent -lt 80 ]]; then
    echo "   ✅ Sistema está saudável!"
fi

echo ""
echo "📊 COMANDOS ÚTEIS:"
echo "   dev-status      - Dashboard resumido"
echo "   dev-benchmark   - Testar performance" 
echo "   dev-clean now   - Limpeza rápida"
echo "   logs            - Ver logs sistema"
echo ""
EOF
    
    sudo chmod +x /usr/local/bin/dev-health
    log_success "dev-health criado: health check completo"
}

# =============================================================================
# FUNÇÃO PRINCIPAL DO MÓDULO
# =============================================================================

create_utility_scripts() {
    log_header "⚡ CRIANDO SCRIPTS UTILITÁRIOS PRÁTICOS"
    
    echo ""
    echo -e "${BLUE}Scripts a criar:${NC}"
    bullet_list \
        "dev-status - Dashboard completo do sistema" \
        "dev-tools - Verificar ferramentas de desenvolvimento" \
        "dev-health - Health check completo" \
        "dev-benchmark - Testar performance (simples)"
    
    echo ""
    
    if ! confirm "Criar scripts utilitários?" "y"; then
        log_info "Scripts utilitários cancelados"
        return 0
    fi
    
    # Criar scripts
    create_dev_status
    create_dev_tools  
    create_dev_health
    
    # Script de benchmark simples
    create_simple_benchmark
    
    log_success "🎉 Scripts utilitários criados!"
    echo ""
    echo -e "${YELLOW}💡 TESTAR AGORA:${NC}"
    bullet_list \
        "dev-status - Ver dashboard" \
        "dev-tools - Verificar ferramentas" \
        "dev-health - Health check" \
        "dev-benchmark - Testar performance"
    
    echo ""
}

create_simple_benchmark() {
    sudo tee /usr/local/bin/dev-benchmark > /dev/null << 'EOF'
#!/bin/bash
# Benchmark simples e rápido

echo "🚀 BENCHMARK RÁPIDO"
echo "=================="
echo ""

echo "⏱️ CPU (5 segundos)..."
time_start=$(date +%s.%N)
timeout 5s yes >/dev/null 2>&1
time_end=$(date +%s.%N)
duration=$(echo "$time_end - $time_start" | bc -l | cut -c1-4)
echo "   ✅ CPU stress test: ${duration}s"

echo ""
echo "💿 DISCO (50MB write)..."
time_start=$(date +%s.%N)
dd if=/dev/zero of=/tmp/benchmark_test bs=1M count=50 >/dev/null 2>&1
sync
time_end=$(date +%s.%N)
rm -f /tmp/benchmark_test
duration=$(echo "$time_end - $time_start" | bc -l | cut -c1-4)
speed=$(echo "scale=1; 50 / $duration" | bc -l | cut -c1-5)
echo "   ✅ Write speed: ${speed}MB/s"

echo ""
echo "📶 REDE..."
if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    ping_avg=$(ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F/ '{print $5}' | cut -c1-5)
    echo "   ✅ Ping médio: ${ping_avg}ms"
else
    echo "   ❌ Sem ligação de rede"
fi

echo ""
echo "📊 RESUMO:"
echo "   CPU: Normal"
echo "   Disco: $([ "${speed%.*}" -gt 50 ] 2>/dev/null && echo "Rápido (SSD/NVMe)" || echo "Normal (HDD/SSD lento)")"
echo "   Rede: $([ "${ping_avg%.*}" -lt 50 ] 2>/dev/null && echo "Boa" || echo "Normal")"
echo ""
EOF
    
    sudo chmod +x /usr/local/bin/dev-benchmark
    log_success "dev-benchmark criado: teste de performance rápido"
}
