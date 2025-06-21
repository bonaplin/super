#!/bin/bash
# =============================================================================
# INSTALLER DE FERRAMENTAS DA COMUNIDADE
# Instala ferramentas testadas e mantidas pela comunidade
# =============================================================================

set -euo pipefail

# Diretórios
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar bibliotecas
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# CONFIGURAÇÃO E DETECÇÃO
# =============================================================================

detect_system_specs() {
    export RAM_GB=$(get_ram_gb)
    export CPU_CORES=$(get_cpu_cores)
    export STORAGE_TYPE=$(detect_storage_type)
    export IS_LAPTOP=$(is_laptop && echo "true" || echo "false")
    
    log_info "Sistema detectado: ${RAM_GB}GB RAM, ${CPU_CORES} cores, ${STORAGE_TYPE^^}, $(is_laptop && echo "laptop" || echo "desktop")"
}

# =============================================================================
# TLP - GESTÃO DE ENERGIA (GOLD STANDARD)
# =============================================================================

install_tlp() {
    section_header "TLP - Gestão Inteligente de Energia" "$SYMBOL_FIRE"
    
    if command_exists tlp; then
        log_info "TLP já instalado: $(tlp --version 2>/dev/null | head -1 || echo "versão desconhecida")"
        return 0
    fi
    
    if ! confirm "Instalar TLP para gestão de energia?" "y"; then
        return 0
    fi
    
    log_info "Instalando TLP..."
    
    # Instalar TLP e dependências
    if safe_apt_install tlp tlp-rdw; then
        # Configuração básica para laptop
        if [[ "$IS_LAPTOP" == "true" ]]; then
            sudo tee /etc/tlp.d/01-laptop-config.conf > /dev/null << 'EOF'
# Configuração TLP para laptop

# CPU scaling
CPU_SCALING_GOVERNOR_ON_AC=ondemand
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU boost (conservador para thermal)
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0

# Performance vs battery
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Disk management
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"

# Networking
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# USB autosuspend
USB_AUTOSUSPEND=1
EOF
        fi
        
        # Ativar serviço
        safe_service_action "enable" "tlp"
        safe_service_action "start" "tlp"
        
        log_success "TLP instalado e configurado!"
        echo ""
        bullet_list \
            "Configuração em: /etc/tlp.d/" \
            "Ver status: sudo tlp-stat" \
            "Aplicar configuração: sudo tlp start"
    else
        log_error "Falha na instalação do TLP"
        return 1
    fi
}

# =============================================================================
# AUTO-CPUFREQ - CPU SCALING INTELIGENTE
# =============================================================================

install_auto_cpufreq() {
    section_header "Auto-CPUfreq - CPU Scaling Inteligente" "$SYMBOL_ROCKET"
    
    if command_exists auto-cpufreq; then
        log_info "auto-cpufreq já instalado"
        return 0
    fi
    
    if ! confirm "Instalar auto-cpufreq para gestão automática de CPU?" "y"; then
        return 0
    fi
    
    log_info "Instalando auto-cpufreq..."
    
    # Método 1: Tentar via snap (mais fácil)
    if command_exists snap; then
        log_info "Tentando instalação via snap..."
        if sudo snap install auto-cpufreq 2>/dev/null; then
            log_success "auto-cpufreq instalado via snap"
            
            # Configurar como daemon
            if sudo auto-cpufreq --install 2>/dev/null; then
                log_success "auto-cpufreq daemon ativado"
            else
                log_warning "Falha ao ativar daemon - funciona mas sem auto-start"
            fi
            return 0
        else
            log_warning "Falha na instalação via snap, tentando método alternativo..."
        fi
    fi
    
    # Método 2: Git clone (fallback)
    log_info "Instalando via git clone..."
    
    local temp_dir="/tmp/auto-cpufreq-install"
    rm -rf "$temp_dir"
    
    if git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$temp_dir" 2>/dev/null; then
        cd "$temp_dir"
        
        # Verificar se installer existe
        if [[ -f "./auto-cpufreq-installer" ]]; then
            if sudo ./auto-cpufreq-installer --install 2>/dev/null; then
                log_success "auto-cpufreq instalado via git!"
                cd - >/dev/null
                rm -rf "$temp_dir"
                return 0
            else
                log_error "Falha no installer git"
            fi
        else
            log_error "Installer não encontrado no repositório"
        fi
        
        cd - >/dev/null
        rm -rf "$temp_dir"
    else
        log_error "Falha ao clonar repositório auto-cpufreq"
    fi
    
    log_warning "Não foi possível instalar auto-cpufreq. TLP vai gerir CPU scaling."
    return 1
}

# =============================================================================
# PRELOAD - PRELOADING INTELIGENTE DE APLICAÇÕES
# =============================================================================

install_preload() {
    section_header "Preload - Precarregamento Inteligente" "$SYMBOL_LOADING"
    
    if package_is_installed preload; then
        log_info "Preload já instalado"
        return 0
    fi
    
    if ! confirm "Instalar preload para acelerar aplicações?" "y"; then
        return 0
    fi
    
    log_info "Instalando preload..."
    
    if safe_apt_install preload; then
        log_success "Preload instalado!"
        echo ""
        bullet_list \
            "Funciona automaticamente em background" \
            "Aprende quais aplicações usa mais" \
            "Pré-carrega aplicações frequentes" \
            "Configuração em: /etc/preload.conf"
        
        # Verificar se está a correr
        if service_is_active preload; then
            log_success "Preload ativo e a funcionar"
        else
            log_info "Preload vai começar a funcionar após reinício"
        fi
    else
        log_error "Falha na instalação do preload"
        return 1
    fi
}

# =============================================================================
# EARLYOOM - PREVENÇÃO DE OUT-OF-MEMORY
# =============================================================================

install_earlyoom() {
    section_header "EarlyOOM - Prevenção de Sistema Congelado" "$SYMBOL_SHIELD"
    
    if package_is_installed earlyoom; then
        log_info "EarlyOOM já instalado"
        return 0
    fi
    
    # Só recomendar se RAM baixa
    if [[ $RAM_GB -lt 8 ]]; then
        log_info "RAM detectado: ${RAM_GB}GB - EarlyOOM recomendado"
        if ! confirm "Instalar EarlyOOM para evitar sistema congelado?" "y"; then
            return 0
        fi
    else
        if ! confirm "Instalar EarlyOOM? (opcional com ${RAM_GB}GB RAM)" "n"; then
            return 0
        fi
    fi
    
    log_info "Instalando EarlyOOM..."
    
    if safe_apt_install earlyoom; then
        # Configuração conservadora
        sudo tee /etc/default/earlyoom > /dev/null << 'EOF'
# EarlyOOM configuration
# Kill processes when memory usage is high to prevent complete freeze

# Memory thresholds (% of RAM)
EARLYOOM_ARGS="-m 5 -s 10 --avoid '(^|/)(systemd|Xorg|ssh|dbus)$' --prefer '(^|/)(chrome|firefox|code|java)$'"

# -m 5: start killing when 5% RAM left
# -s 10: start killing when 10% swap left  
# --avoid: never kill critical system processes
# --prefer: prefer to kill memory-hungry apps
EOF
        
        # Ativar serviço
        safe_service_action "enable" "earlyoom"
        safe_service_action "start" "earlyoom"
        
        log_success "EarlyOOM instalado e ativo!"
        echo ""
        bullet_list \
            "Previne sistema congelado por falta de memória" \
            "Mata processos automaticamente quando necessário" \
            "Protege processos críticos do sistema" \
            "Ver logs: journalctl -u earlyoom"
    else
        log_error "Falha na instalação do EarlyOOM"
        return 1
    fi
}

# =============================================================================
# ZRAM - SWAP COMPRIMIDO (PARA POUCA RAM)
# =============================================================================

install_zram() {
    section_header "ZRAM - Swap Comprimido em RAM" "$SYMBOL_STORAGE"
    
    # Só instalar se pouca RAM
    if [[ $RAM_GB -ge 16 ]]; then
        log_info "RAM suficiente (${RAM_GB}GB) - ZRAM não necessário"
        return 0
    fi
    
    if package_is_installed zram-config; then
        log_info "ZRAM já instalado"
        return 0
    fi
    
    if ! confirm "Instalar ZRAM para swap comprimido? (recomendado para <16GB RAM)" "y"; then
        return 0
    fi
    
    log_info "Instalando ZRAM..."
    
    if safe_apt_install zram-config; then
        log_success "ZRAM instalado!"
        echo ""
        bullet_list \
            "Cria swap comprimido na RAM" \
            "Reduz uso de SSD/HDD para swap" \
            "Funciona automaticamente" \
            "Ver status: cat /proc/swaps"
        
        # Verificar se está ativo
        if [[ -f /dev/zram0 ]]; then
            log_success "ZRAM ativo"
        else
            log_info "ZRAM será ativado no próximo boot"
        fi
    else
        log_error "Falha na instalação do ZRAM"
        return 1
    fi
}

# =============================================================================
# PROFILE-SYNC-DAEMON - BROWSERS MAIS RÁPIDOS
# =============================================================================

install_profile_sync_daemon() {
    section_header "Profile-Sync-Daemon - Browsers Mais Rápidos" "$SYMBOL_ROCKET"
    
    if package_is_installed profile-sync-daemon; then
        log_info "Profile-sync-daemon já instalado"
        return 0
    fi
    
    # Só oferecer se usar browsers comuns
    local has_browsers=false
    for browser in firefox google-chrome chromium snap/firefox; do
        if command_exists "$browser" || [[ -d "$HOME/.mozilla" ]] || [[ -d "$HOME/.config/google-chrome" ]]; then
            has_browsers=true
            break
        fi
    done
    
    if [[ "$has_browsers" == "false" ]]; then
        log_info "Browsers não detectados - PSD não necessário"
        return 0
    fi
    
    if ! confirm "Instalar profile-sync-daemon para browsers mais rápidos?" "n"; then
        return 0
    fi
    
    log_info "Instalando profile-sync-daemon..."
    
    if safe_apt_install profile-sync-daemon; then
        log_success "Profile-sync-daemon instalado!"
        echo ""
        bullet_list \
            "Move perfis de browsers para RAM" \
            "Browsers iniciam mais rápido" \
            "Reduz escrita no SSD" \
            "Configurar: psd preview && psd set"
        
        important_warning "Execute 'psd preview' e depois 'psd set' para configurar browsers específicos"
    else
        log_error "Falha na instalação do profile-sync-daemon"
        return 1
    fi
}

# =============================================================================
# FERRAMENTAS ADICIONAIS OPCIONAIS
# =============================================================================

install_optional_tools() {
    section_header "Ferramentas Adicionais Opcionais" "$SYMBOL_GEAR"
    
    echo ""
    echo -e "${BLUE}Ferramentas adicionais disponíveis:${NC}"
    echo ""
    
    # Lista de ferramentas opcionais
    local tools=(
        "thermald:Gestão térmica automática"
        "cpufrequtils:Utilitários CPU frequency"
        "powertop:Análise consumo energia"
        "iotop:Monitorização I/O"
        "htop:Monitor sistema melhorado"
        "ncdu:Análise uso disco"
    )
    
    local install_tools=()
    
    for tool_desc in "${tools[@]}"; do
        local tool="${tool_desc%%:*}"
        local desc="${tool_desc##*:}"
        
        if ! package_is_installed "$tool"; then
            if confirm "Instalar $tool ($desc)?" "n"; then
                install_tools+=("$tool")
            fi
        else
            log_info "$tool já instalado"
        fi
    done
    
    if [[ ${#install_tools[@]} -gt 0 ]]; then
        log_info "Instalando ferramentas selecionadas..."
        safe_apt_install "${install_tools[@]}"
        log_success "Ferramentas opcionais instaladas!"
    fi
}

# =============================================================================
# VERIFICAÇÃO E RELATÓRIO FINAL
# =============================================================================

verify_installations() {
    section_header "Verificação das Instalações" "$SYMBOL_CHECK"
    
    echo ""
    echo -e "${BLUE}Estado das ferramentas instaladas:${NC}"
    echo ""
    
    # TLP
    if command_exists tlp; then
        if service_is_active tlp; then
            status_message "success" "TLP: Instalado e ativo"
        else
            status_message "warning" "TLP: Instalado mas inativo"
        fi
    else
        status_message "info" "TLP: Não instalado"
    fi
    
    # Auto-CPUfreq
    if command_exists auto-cpufreq; then
        if pgrep -f auto-cpufreq >/dev/null; then
            status_message "success" "Auto-CPUfreq: Instalado e ativo"
        else
            status_message "warning" "Auto-CPUfreq: Instalado mas inativo"
        fi
    else
        status_message "info" "Auto-CPUfreq: Não instalado"
    fi
    
    # Preload
    if package_is_installed preload; then
        if service_is_active preload; then
            status_message "success" "Preload: Instalado e ativo"
        else
            status_message "warning" "Preload: Instalado mas inativo"
        fi
    else
        status_message "info" "Preload: Não instalado"
    fi
    
    # EarlyOOM
    if package_is_installed earlyoom; then
        if service_is_active earlyoom; then
            status_message "success" "EarlyOOM: Instalado e ativo"
        else
            status_message "warning" "EarlyOOM: Instalado mas inativo"
        fi
    else
        status_message "info" "EarlyOOM: Não instalado"
    fi
    
    # ZRAM
    if package_is_installed zram-config; then
        if [[ -f /dev/zram0 ]]; then
            status_message "success" "ZRAM: Instalado e ativo"
        else
            status_message "warning" "ZRAM: Instalado (ativo no próximo boot)"
        fi
    else
        status_message "info" "ZRAM: Não instalado"
    fi
    
    # Profile-sync-daemon
    if package_is_installed profile-sync-daemon; then
        status_message "success" "Profile-sync-daemon: Instalado"
        highlight_note "Execute 'psd preview' e 'psd set' para configurar"
    else
        status_message "info" "Profile-sync-daemon: Não instalado"
    fi
}

show_next_steps() {
    section_header "Próximos Passos Recomendados" "$SYMBOL_ARROW"
    
    echo ""
    echo -e "${GREEN}🔄 REINICIAR SISTEMA:${NC}"
    echo "   sudo reboot"
    echo ""
    echo -e "${GREEN}🔍 VERIFICAR FUNCIONAMENTO:${NC}"
    bullet_list \
        "TLP status: sudo tlp-stat -s" \
        "Auto-CPUfreq stats: sudo auto-cpufreq --stats" \
        "Processos ativos: ps aux | grep -E '(tlp|preload|earlyoom)'" \
        "ZRAM status: cat /proc/swaps"
    
    echo ""
    echo -e "${GREEN}⚙️ CONFIGURAÇÃO ADICIONAL:${NC}"
    bullet_list \
        "TLP configuração: /etc/tlp.d/" \
        "Preload configuração: /etc/preload.conf" \
        "EarlyOOM configuração: /etc/default/earlyoom" \
        "Profile-sync-daemon: psd preview && psd set"
    
    echo ""
    echo -e "${GREEN}📊 MONITORIZAÇÃO:${NC}"
    bullet_list \
        "Consumo energia: powertop (se instalado)" \
        "CPU frequency: watch grep MHz /proc/cpuinfo" \
        "Memória: free -h && cat /proc/swaps" \
        "Logs sistema: journalctl -f"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    clear
    
    log_header "🌍 INSTALLER DE FERRAMENTAS DA COMUNIDADE"
    
    echo ""
    echo -e "${BLUE}Este installer vai configurar ferramentas testadas e mantidas pela comunidade:${NC}"
    echo ""
    bullet_list \
        "TLP - Gestão inteligente de energia (padrão-ouro)" \
        "Auto-CPUfreq - CPU scaling automático" \
        "Preload - Precarregamento de aplicações" \
        "EarlyOOM - Prevenção de sistema congelado" \
        "ZRAM - Swap comprimido (se RAM < 16GB)" \
        "Profile-sync-daemon - Browsers mais rápidos (opcional)"
    
    echo ""
    important_warning "Estas ferramentas são mantidas pela comunidade e recebem atualizações regulares"
    
    if ! confirm "Continuar com instalação?" "y"; then
        log_info "Instalação cancelada"
        exit 0
    fi
    
    # Detectar sistema
    detect_system_specs
    show_system_info
    
    echo ""
    if ! confirm "Especificações corretas?" "y"; then
        log_error "Verificar especificações manualmente"
        exit 1
    fi
    
    # Atualizar sistema primeiro
    log_info "Atualizando cache de pacotes..."
    sudo apt update -qq
    
    # Instalar ferramentas
    install_tlp
    install_auto_cpufreq
    install_preload
    install_earlyoom
    install_zram
    install_profile_sync_daemon
    install_optional_tools
    
    # Verificação final
    verify_installations
    
    # Relatório final
    show_next_steps
    
    echo ""
    log_success "🎉 Instalação de ferramentas da comunidade concluída!"
    echo ""
    highlight_note "REINICIE o sistema para ativar todas as otimizações: sudo reboot"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi