#!/bin/bash
# =============================================================================
# TESTES DE VALIDAÇÃO DAS OTIMIZAÇÕES
# Verifica se todas as otimizações foram aplicadas corretamente
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

readonly TEST_LOG="/tmp/laptop-optimizer-tests.log"

# =============================================================================
# FRAMEWORK DE TESTES
# =============================================================================

test_count=0
test_passed=0
test_failed=0

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((test_count++))
    
    echo -e "${BLUE}Teste $test_count: $test_name${NC}"
    
    if $test_function; then
        echo -e "${GREEN}  ✅ PASSOU${NC}"
        ((test_passed++))
        echo "PASS: $test_name" >> "$TEST_LOG"
    else
        echo -e "${RED}  ❌ FALHOU${NC}"
        ((test_failed++))
        echo "FAIL: $test_name" >> "$TEST_LOG"
    fi
    echo ""
}

# =============================================================================
# TESTES DE OTIMIZAÇÕES KERNEL
# =============================================================================

test_swappiness() {
    local current=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    [[ $current -le 20 ]]
}

test_inotify_watches() {
    local current=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "8192")
    [[ $current -gt 50000 ]]
}

test_file_limits() {
    local current=$(ulimit -n 2>/dev/null || echo "1024")
    [[ $current -gt 8192 ]]
}

test_sysctl_config() {
    [[ -f /etc/sysctl.d/99-dev-*.conf || -f /etc/sysctl.d/99-essential-*.conf ]]
}

# =============================================================================
# TESTES DE FERRAMENTAS
# =============================================================================

test_tlp_installed() {
    command -v tlp >/dev/null 2>&1
}

test_tlp_active() {
    systemctl is-active --quiet tlp 2>/dev/null
}

test_git_configured() {
    git config --global user.name >/dev/null 2>&1 && \
    git config --global user.email >/dev/null 2>&1
}

test_auto_cpufreq() {
    command -v auto-cpufreq >/dev/null 2>&1 || \
    pgrep -f auto-cpufreq >/dev/null 2>&1
}

# =============================================================================
# TESTES DE SCRIPTS UTILITÁRIOS
# =============================================================================

test_dev_scripts() {
    [[ -x /usr/local/bin/dev-status ]] && \
    [[ -x /usr/local/bin/dev-clean ]] && \
    [[ -x /usr/local/bin/dev-health ]]
}

test_dev_status_works() {
    /usr/local/bin/dev-status >/dev/null 2>&1
}

test_maintenance_system() {
    [[ -x /usr/local/bin/dev-maintenance ]] || \
    [[ -f /etc/cron.d/dev-maintenance-* ]]
}

# =============================================================================
# TESTES DE DOCKER (SE DISPONÍVEL)
# =============================================================================

test_docker_cleanup() {
    if command -v docker >/dev/null 2>&1; then
        command -v docker-clean >/dev/null 2>&1
    else
        true  # Skip se Docker não estiver instalado
    fi
}

# =============================================================================
# TESTES DE SEGURANÇA
# =============================================================================

test_backup_system() {
    [[ -x /usr/local/bin/dev-rollback ]] && \
    [[ -d ~/.laptop-optimizer-backups ]]
}

test_firewall_configured() {
    if command -v ufw >/dev/null 2>&1; then
        ufw status | grep -q "active"
    else
        true  # Skip se UFW não estiver disponível
    fi
}

test_fail2ban() {
    if systemctl is-active --quiet ssh 2>/dev/null; then
        # Se SSH ativo, deveria ter fail2ban ou ser configuração empresarial
        command -v fail2ban-server >/dev/null 2>&1 || \
        grep -q "Enterprise\|Company" /etc/ssh/sshd_config 2>/dev/null
    else
        true  # Skip se SSH não ativo
    fi
}

# =============================================================================
# TESTES DE PERFORMANCE
# =============================================================================

test_trim_configured() {
    if [[ -d /sys/block/nvme* ]] || [[ -f /sys/block/sda/queue/rotational && $(cat /sys/block/sda/queue/rotational) -eq 0 ]]; then
        systemctl is-active --quiet fstrim.timer 2>/dev/null || \
        [[ -f /etc/cron.d/weekly-fstrim ]]
    else
        true  # Skip se não for SSD/NVMe
    fi
}

test_io_scheduler() {
    local optimized=false
    
    for device in /sys/block/sd* /sys/block/nvme*; do
        [[ ! -d "$device" ]] && continue
        
        if [[ -f "$device/queue/scheduler" ]]; then
            local scheduler=$(cat "$device/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]')
            if [[ "$scheduler" =~ (none|mq-deadline) ]]; then
                optimized=true
                break
            fi
        fi
    done
    
    $optimized
}

# =============================================================================
# TESTES DE COMPATIBILIDADE EMPRESARIAL
# =============================================================================

test_enterprise_compatibility() {
    local enterprise_safe=true
    
    # Verificar se DNS não foi alterado se VPN ativo
    if ip route | grep -qE "tun|tap|ppp"; then
        local dns=$(systemd-resolve --status 2>/dev/null | grep "DNS Servers" | head -1 | awk -F: '{print $2}' | xargs || echo "")
        if [[ "$dns" =~ (1.1.1.1|8.8.8.8) ]]; then
            enterprise_safe=false
        fi
    fi
    
    $enterprise_safe
}

test_vpn_compatibility() {
    if ip route | grep -qE "tun|tap|ppp"; then
        # Se VPN ativo, verificar se configurações são conservadoras
        local rmem_max=$(cat /proc/sys/net/core/rmem_max 2>/dev/null || echo "212992")
        [[ $rmem_max -lt 1000000 ]]  # Não deve ser muito aumentado com VPN
    else
        true  # OK se não há VPN
    fi
}

# =============================================================================
# MAIN - EXECUTAR TODOS OS TESTES
# =============================================================================

main() {
    clear
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🧪 TESTES DE VALIDAÇÃO DAS OTIMIZAÇÕES                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    echo -e "${BLUE}Executando testes de validação...${NC}"
    echo ""
    
    # Inicializar log
    echo "=== LAPTOP OPTIMIZER - TESTES DE VALIDAÇÃO ===" > "$TEST_LOG"
    echo "Data: $(date)" >> "$TEST_LOG"
    echo "Sistema: $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    # === TESTES DE KERNEL ===
    echo -e "${YELLOW}📋 TESTES DE OTIMIZAÇÕES KERNEL:${NC}"
    run_test "Swappiness otimizado (≤20)" test_swappiness
    run_test "inotify watches aumentado (>50K)" test_inotify_watches
    run_test "File limits otimizados (>8K)" test_file_limits
    run_test "Configuração sysctl presente" test_sysctl_config
    
    # === TESTES DE FERRAMENTAS ===
    echo -e "${YELLOW}🛠️ TESTES DE FERRAMENTAS:${NC}"
    run_test "TLP instalado" test_tlp_installed
    run_test "TLP ativo" test_tlp_active
    run_test "Git configurado" test_git_configured
    run_test "Auto-CPUfreq disponível" test_auto_cpufreq
    
    # === TESTES DE SCRIPTS ===
    echo -e "${YELLOW}⚡ TESTES DE SCRIPTS UTILITÁRIOS:${NC}"
    run_test "Scripts dev-* instalados" test_dev_scripts
    run_test "dev-status funcional" test_dev_status_works
    run_test "Sistema de manutenção" test_maintenance_system
    
    # === TESTES DE DOCKER ===
    echo -e "${YELLOW}🐳 TESTES DE DOCKER:${NC}"
    run_test "Docker cleanup inteligente" test_docker_cleanup
    
    # === TESTES DE SEGURANÇA ===
    echo -e "${YELLOW}🔒 TESTES DE SEGURANÇA:${NC}"
    run_test "Sistema de backup" test_backup_system
    run_test "Firewall configurado" test_firewall_configured
    run_test "fail2ban (se SSH ativo)" test_fail2ban
    
    # === TESTES DE PERFORMANCE ===
    echo -e "${YELLOW}⚡ TESTES DE PERFORMANCE:${NC}"
    run_test "TRIM configurado (SSD/NVMe)" test_trim_configured
    run_test "I/O scheduler otimizado" test_io_scheduler
    
    # === TESTES EMPRESARIAIS ===
    echo -e "${YELLOW}🏢 TESTES EMPRESARIAIS:${NC}"
    run_test "Compatibilidade empresarial" test_enterprise_compatibility
    run_test "Compatibilidade VPN" test_vpn_compatibility
    
    # === RELATÓRIO FINAL ===
    echo -e "${BLUE}📊 RELATÓRIO FINAL:${NC}"
    echo ""
    echo -e "${GREEN}✅ Testes passou: $test_passed${NC}"
    echo -e "${RED}❌ Testes falharam: $test_failed${NC}"
    echo -e "${BLUE}📋 Total de testes: $test_count${NC}"
    echo ""
    
    local success_rate=$((test_passed * 100 / test_count))
    
    if [[ $test_failed -eq 0 ]]; then
        echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM! Sistema otimizado corretamente.${NC}"
    elif [[ $success_rate -ge 80 ]]; then
        echo -e "${YELLOW}⚠️ Maioria dos testes passou ($success_rate%). Verificar falhas:${NC}"
        grep "FAIL:" "$TEST_LOG" | sed 's/FAIL: /   ❌ /'
    else
        echo -e "${RED}❌ Muitos testes falharam ($success_rate%). Sistema pode não estar otimizado.${NC}"
        echo -e "${BLUE}Ver log completo: $TEST_LOG${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}💡 RECOMENDAÇÕES:${NC}"
    
    if [[ $test_failed -gt 0 ]]; then
        echo "   • Executar novamente: ./optimize-laptop.sh"
        echo "   • Verificar logs: $TEST_LOG"
        echo "   • Fazer rollback se necessário: dev-rollback <backup-dir>"
    else
        echo "   • Sistema está otimizado corretamente!"
        echo "   • Executar benchmark: dev-benchmark"
        echo "   • Verificar status: dev-status"
    fi
    
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi