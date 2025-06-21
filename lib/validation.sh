#!/bin/bash
# =============================================================================
# BIBLIOTECA DE VALIDAÇÃO DO SISTEMA
# Verificações de segurança antes de aplicar otimizações
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# VALIDAÇÕES DE SISTEMA BASE
# =============================================================================

validate_system_requirements() {
    section_header "Validação de Requisitos do Sistema" "$SYMBOL_SHIELD"
    
    local validation_passed=true
    
    # 1. Verificar se não é root
    if [[ $EUID -eq 0 ]]; then
        status_message "error" "Script NÃO deve ser executado como root!"
        echo -e "${RED}   Execute como utilizador normal: ./optimize-laptop.sh${NC}"
        return 1
    fi
    
    # 2. Verificar sudo
    if ! sudo -n true 2>/dev/null; then
        log_info "Verificando permissões sudo..."
        if ! sudo -v; then
            status_message "error" "Sudo necessário para otimizações"
            return 1
        fi
    fi
    status_message "success" "Permissões sudo: OK"
    
    # 3. Verificar comandos críticos
    local critical_commands=("apt" "systemctl" "df" "free" "nproc" "bc" "grep" "awk" "sed")
    local missing_commands=()
    
    for cmd in "${critical_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
            validation_passed=false
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        status_message "error" "Comandos críticos em falta: ${missing_commands[*]}"
        return 1
    fi
    status_message "success" "Comandos essenciais: OK"
    
    # 4. Verificar distribuição
    if ! (is_ubuntu || is_debian); then
        status_message "warning" "Sistema não-Ubuntu/Debian detectado"
        if ! confirm "Continuar mesmo assim? (algumas funcionalidades podem falhar)" "n"; then
            return 1
        fi
    else
        local distro=$(lsb_release -si 2>/dev/null || echo "Debian")
        local version=$(lsb_release -sr 2>/dev/null || echo "desconhecida")
        status_message "success" "Sistema: $distro $version"
    fi
    
    # 5. Verificar espaço em disco
    local free_space_gb=$(get_free_space_gb)
    if (( $(echo "$free_space_gb < 2.0" | bc -l) )); then
        status_message "error" "Espaço insuficiente: ${free_space_gb}GB (mínimo: 2GB)"
        return 1
    fi
    status_message "success" "Espaço livre: ${free_space_gb}GB"
    
    # 6. Verificar conectividade (não crítico)
    if ! has_network_connection; then
        status_message "warning" "Sem conectividade - algumas ferramentas podem falhar"
        if ! confirm "Continuar sem internet?" "n"; then
            return 1
        fi
    else
        status_message "success" "Conectividade: OK"
    fi
    
    if [[ "$validation_passed" == true ]]; then
        log_success "✅ Todos os requisitos validados com sucesso"
        return 0
    else
        log_error "❌ Validação falhou - sistema não está pronto"
        return 1
    fi
}

# =============================================================================
# VALIDAÇÃO DE INTEGRIDADE DO SISTEMA
# =============================================================================

check_system_integrity() {
    section_header "Verificação de Integridade" "$SYMBOL_SHIELD"
    
    local integrity_issues=()
    
    # 1. Verificar se é sistema containerizado
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        integrity_issues+=("Sistema containerizado (Docker) - otimizações limitadas")
    fi
    
    # 2. Verificar se é VM
    if systemd-detect-virt -q 2>/dev/null; then
        local virt_type=$(systemd-detect-virt 2>/dev/null || echo "desconhecido")
        integrity_issues+=("Virtualização detectada ($virt_type) - algumas otimizações podem não aplicar")
    fi
    
    # 3. Verificar se systemd está funcional
    if ! systemctl is-system-running --quiet; then
        local system_state=$(systemctl is-system-running 2>/dev/null || echo "desconhecido")
        if [[ "$system_state" != "running" && "$system_state" != "degraded" ]]; then
            integrity_issues+=("systemd não está funcional ($system_state)")
        fi
    fi
    
    # 4. Verificar se APT está funcional
    if ! apt list >/dev/null 2>&1; then
        integrity_issues+=("APT não está funcional")
    fi
    
    # 5. Verificar espaço em /tmp
    local tmp_space=$(df /tmp 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1024}' || echo "0")
    if (( $(echo "$tmp_space < 100" | bc -l) )); then
        integrity_issues+=("Pouco espaço em /tmp: ${tmp_space}MB")
    fi
    
    # 6. Verificar se há atualizações críticas pendentes
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    if [[ $security_updates -gt 10 ]]; then
        integrity_issues+=("Muitas atualizações de segurança pendentes: $security_updates")
    fi
    
    # Reportar problemas
    if [[ ${#integrity_issues[@]} -eq 0 ]]; then
        status_message "success" "Integridade do sistema: OK"
        return 0
    else
        status_message "warning" "Problemas de integridade detectados:"
        for issue in "${integrity_issues[@]}"; do
            echo -e "   ${YELLOW}⚠️${NC} $issue"
        done
        
        echo ""
        if ! confirm "Continuar mesmo com estes problemas?" "n"; then
            return 1
        fi
        
        return 0
    fi
}

# =============================================================================
# VALIDAÇÃO DE RECURSOS DO SISTEMA
# =============================================================================

validate_system_resources() {
    section_header "Validação de Recursos" "$SYMBOL_COMPUTER"
    
    local ram_gb=$(get_ram_gb)
    local cpu_cores=$(get_cpu_cores)
    local storage_type=$(detect_storage_type)
    
    echo -e "${BLUE}📊 Recursos detectados:${NC}"
    bullet_list \
        "RAM: ${ram_gb}GB" \
        "CPU: ${cpu_cores} cores" \
        "Storage: ${storage_type^^}" \
        "Tipo: $(is_laptop && echo "Laptop" || echo "Desktop")"
    
    echo ""
    
    # Verificar recursos mínimos
    local warnings=()
    
    if [[ $ram_gb -lt 4 ]]; then
        warnings+=("RAM baixa (${ram_gb}GB) - algumas otimizações serão conservadoras")
    fi
    
    if [[ $cpu_cores -lt 2 ]]; then
        warnings+=("CPU de core único - otimizações limitadas")
    fi
    
    # Verificar load atual
    local current_load=$(get_system_load)
    if (( $(echo "$current_load > $(($cpu_cores * 2))" | bc -l) )); then
        warnings+=("Sistema com load alto ($current_load) - aguardar antes de otimizar")
    fi
    
    # Verificar uso de memória atual
    local memory_usage=$(get_memory_usage_percent)
    if [[ ${memory_usage%.*} -gt 90 ]]; then
        warnings+=("Uso de RAM alto (${memory_usage}%) - considerar fechar aplicações")
    fi
    
    # Reportar warnings
    if [[ ${#warnings[@]} -eq 0 ]]; then
        status_message "success" "Recursos do sistema adequados"
    else
        status_message "warning" "Avisos sobre recursos:"
        for warning in "${warnings[@]}"; do
            echo -e "   ${YELLOW}⚠️${NC} $warning"
        done
        
        echo ""
        if ! confirm "Continuar com estes avisos?" "y"; then
            return 1
        fi
    fi
    
    return 0
}

# =============================================================================
# VALIDAÇÃO DE CONFIGURAÇÕES EXISTENTES
# =============================================================================

check_existing_configurations() {
    section_header "Verificação de Configurações Existentes" "$SYMBOL_GEAR"
    
    local existing_configs=()
    local conflicts=()
    
    # 1. Verificar configurações sysctl existentes
    if [[ -d /etc/sysctl.d ]]; then
        local sysctl_files=$(find /etc/sysctl.d -name "*.conf" | wc -l)
        if [[ $sysctl_files -gt 3 ]]; then  # Normalmente há 2-3 ficheiros padrão
            existing_configs+=("Configurações sysctl customizadas ($sysctl_files ficheiros)")
        fi
    fi
    
    # 2. Verificar limites customizados
    if [[ -d /etc/security/limits.d ]] && [[ $(ls /etc/security/limits.d/*.conf 2>/dev/null | wc -l) -gt 0 ]]; then
        existing_configs+=("Limites de sistema customizados")
    fi
    
    # 3. Verificar cron jobs existentes
    local user_crons=$(crontab -l 2>/dev/null | grep -v "^#" | wc -l)
    local system_crons=$(find /etc/cron.d /etc/cron.daily /etc/cron.weekly /etc/cron.monthly -type f 2>/dev/null | wc -l)
    if [[ $((user_crons + system_crons)) -gt 10 ]]; then
        existing_configs+=("Muitos cron jobs ($user_crons utilizador + $system_crons sistema)")
    fi
    
    # 4. Verificar configurações de desenvolvimento prévias
    if [[ -f ~/.dev_aliases ]] || [[ -f ~/.vimrc ]] || [[ -d ~/.oh-my-zsh ]]; then
        existing_configs+=("Configurações de desenvolvimento existentes")
    fi
    
    # 5. Verificar otimizações prévias do script
    if [[ -f /etc/sysctl.d/99-dev-performance-conservative.conf ]]; then
        existing_configs+=("Otimizações prévias deste script detectadas")
        
        # Verificar versão
        if grep -q "# Sistema:" /etc/sysctl.d/99-dev-performance-conservative.conf; then
            local prev_version=$(grep "# Sistema:" /etc/sysctl.d/99-dev-performance-conservative.conf | head -1)
            status_message "info" "Versão prévia: $prev_version"
        fi
    fi
    
    # Reportar configurações existentes
    if [[ ${#existing_configs[@]} -eq 0 ]]; then
        status_message "success" "Sistema limpo - sem configurações conflituosas"
    else
        status_message "info" "Configurações existentes detectadas:"
        for config in "${existing_configs[@]}"; do
            echo -e "   ${BLUE}ℹ️${NC} $config"
        done
        
        echo ""
        echo -e "${YELLOW}💡 Nota:${NC} Configurações existentes serão preservadas quando possível"
        
        # Perguntar sobre limpeza se há configurações prévias do script
        if [[ " ${existing_configs[*]} " =~ "Otimizações prévias" ]]; then
            echo ""
            if confirm "Remover configurações prévias e reconfigurar?" "y"; then
                cleanup_previous_configurations
            fi
        fi
    fi
    
    return 0
}

cleanup_previous_configurations() {
    log_info "Removendo configurações prévias..."
    
    # Backup antes de remover
    local backup_suffix=$(date +%Y%m%d-%H%M%S)
    
    # Mover configurações sysctl
    if [[ -f /etc/sysctl.d/99-dev-performance-conservative.conf ]]; then
        sudo mv /etc/sysctl.d/99-dev-performance-conservative.conf \
               "/etc/sysctl.d/99-dev-performance-conservative.conf.backup.$backup_suffix"
    fi
    
    # Remover limites antigos
    sudo rm -f /etc/security/limits.d/99-dev-*.conf
    
    # Remover cron jobs antigos
    sudo rm -f /etc/cron.d/dev-*
    
    # Remover scripts utilitários antigos (serão recriados)
    sudo rm -f /usr/local/bin/dev-*
    
    log_success "Configurações prévias removidas (backup criado)"
}

# =============================================================================
# VALIDAÇÃO DE SEGURANÇA
# =============================================================================

validate_security_environment() {
    section_header "Validação de Ambiente de Segurança" "$SYMBOL_SECURITY"
    
    local security_warnings=()
    
    # 1. Verificar se SSH está exposto
    if systemctl is-active --quiet ssh; then
        if ss -tulpn | grep -q ":22.*0.0.0.0"; then
            security_warnings+=("SSH exposto na internet (porta 22 aberta)")
        fi
    fi
    
    # 2. Verificar firewall
    if command_exists ufw; then
        if ufw status | grep -q "inactive"; then
            security_warnings+=("Firewall UFW desativado")
        fi
    else
        security_warnings+=("Firewall UFW não instalado")
    fi
    
    # 3. Verificar atualizações de segurança
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -c security 2>/dev/null || echo 0)
    if [[ $security_updates -gt 5 ]]; then
        security_warnings+=("$security_updates atualizações de segurança pendentes")
    fi
    
    # 4. Verificar utilizadores com sudo
    local sudo_users=$(getent group sudo | cut -d: -f4 | tr ',' ' ' | wc -w)
    if [[ $sudo_users -gt 3 ]]; then
        security_warnings+=("Muitos utilizadores com sudo ($sudo_users)")
    fi
    
    # 5. Verificar fail2ban se SSH ativo
    if systemctl is-active --quiet ssh && ! systemctl is-active --quiet fail2ban; then
        security_warnings+=("SSH ativo mas fail2ban não instalado")
    fi
    
    # Reportar avisos de segurança
    if [[ ${#security_warnings[@]} -eq 0 ]]; then
        status_message "success" "Ambiente de segurança adequado"
    else
        status_message "warning" "Avisos de segurança:"
        for warning in "${security_warnings[@]}"; do
            echo -e "   ${YELLOW}⚠️${NC} $warning"
        done
        
        echo ""
        echo -e "${BLUE}💡 Sugestão:${NC} O script pode configurar segurança básica automaticamente"
        
        if confirm "Continuar com otimizações?" "y"; then
            return 0
        else
            return 1
        fi
    fi
    
    return 0
}

# =============================================================================
# VALIDAÇÃO COMPLETA (FUNÇÃO PRINCIPAL)
# =============================================================================

validate_system() {
    log_header "🔍 VALIDAÇÃO COMPLETA DO SISTEMA"
    
    echo ""
    echo -e "${BLUE}Verificações a executar:${NC}"
    bullet_list \
        "Requisitos base do sistema" \
        "Integridade e funcionalidade" \
        "Recursos disponíveis" \
        "Configurações existentes" \
        "Ambiente de segurança"
    
    echo ""
    
    if ! confirm "Executar validação completa?" "y"; then
        log_warning "Validação ignorada - prosseguindo por conta e risco"
        return 0
    fi
    
    # Executar todas as validações
    validate_system_requirements || return 1
    check_system_integrity || return 1
    validate_system_resources || return 1
    check_existing_configurations || return 1
    validate_security_environment || return 1
    
    log_success "🎉 Validação completa aprovada - sistema pronto para otimizações!"
    echo ""
    pause_and_return
    
    return 0
}

# =============================================================================
# VALIDAÇÕES ESPECÍFICAS PARA MÓDULOS
# =============================================================================

validate_for_network_changes() {
    log_info "Validando para alterações de rede..."
    
    # Verificar se há VPN ativa
    if detect_vpn_active; then
        log_warning "VPN ativa detectada - alterações de rede podem causar problemas"
        return 1
    fi
    
    # Verificar conectividade crítica
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_warning "Sem conectividade básica - alterações de rede arriscadas"
        return 1
    fi
    
    return 0
}

validate_for_docker_changes() {
    log_info "Validando para alterações Docker..."
    
    if ! command_exists docker; then
        return 0  # Sem Docker, sem problemas
    fi
    
    # Verificar containers críticos em execução
    local running_containers=$(docker ps -q 2>/dev/null | wc -l || echo 0)
    if [[ $running_containers -gt 5 ]]; then
        log_warning "Muitos containers em execução ($running_containers) - alterações podem afetar"
        return 1
    fi
    
    return 0
}

validate_for_kernel_changes() {
    log_info "Validando para alterações de kernel..."
    
    # Verificar se kernel é muito antigo
    local kernel_version=$(uname -r)
    local kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    local kernel_minor=$(echo "$kernel_version" | cut -d. -f2)
    
    if [[ $kernel_major -lt 5 ]] || [[ $kernel_major -eq 5 && $kernel_minor -lt 4 ]]; then
        log_warning "Kernel antigo ($kernel_version) - algumas otimizações podem não funcionar"
        return 1
    fi
    
    return 0
}