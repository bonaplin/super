#!/bin/bash
# =============================================================================
# INSTALLER DE FERRAMENTAS DA COMUNIDADE - VERSÃO LIMPA
# Instala apenas ferramentas de desenvolvimento (SEM gestão energia)
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
        sudo tee /etc/default/earlyoom > /dev/null << 'EOF2'
# EarlyOOM configuration
# Kill processes when memory usage is high to prevent complete freeze

# Memory thresholds (% of RAM)
EARLYOOM_ARGS="-m 5 -s 10 --avoid '(^|/)(systemd|Xorg|ssh|dbus)$' --prefer '(^|/)(chrome|firefox|code|java)$'"

# -m 5: start killing when 5% RAM left
# -s 10: start killing when 10% swap left  
# --avoid: never kill critical system processes
# --prefer: prefer to kill memory-hungry apps
EOF2
        
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
# FERRAMENTAS ADICIONAIS OPCIONAIS
# =============================================================================

install_optional_tools() {
    section_header "Ferramentas Adicionais Opcionais" "$SYMBOL_GEAR"
    
    echo ""
    echo -e "${BLUE}Ferramentas adicionais disponíveis:${NC}"
    echo ""
    
    # Lista de ferramentas opcionais (sem gestão energia)
    local tools=(
        "htop:Monitor sistema melhorado"
        "iotop:Monitorização I/O"
        "ncdu:Análise uso disco"
        "tree:Visualização diretórios"
        "rsync:Sincronização ficheiros"
        "screen:Multiplexador terminal"
        "tmux:Multiplexador terminal moderno"
        "vim:Editor texto avançado"
        "jq:Processador JSON"
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
}

show_next_steps() {
    section_header "Próximos Passos Recomendados" "$SYMBOL_ARROW"
    
    echo ""
    echo -e "${GREEN}🔄 REINICIAR SISTEMA:${NC}"
    echo "   sudo reboot"
    echo ""
    echo -e "${GREEN}🔍 VERIFICAR FUNCIONAMENTO:${NC}"
    bullet_list \
        "Processos ativos: ps aux | grep -E '(preload|earlyoom)'" \
        "ZRAM status: cat /proc/swaps"
    
    echo ""
    echo -e "${GREEN}📊 MONITORIZAÇÃO:${NC}"
    bullet_list \
        "Memória: free -h && cat /proc/swaps" \
        "Processos: htop (se instalado)" \
        "I/O: iotop (se instalado)" \
        "Logs sistema: journalctl -f"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    clear
    
    log_header "🛠️ INSTALLER DE FERRAMENTAS DA COMUNIDADE (LIMPO)"
    
    echo ""
    echo -e "${BLUE}Este installer vai configurar apenas ferramentas de desenvolvimento:${NC}"
    echo ""
    bullet_list \
        "Preload - Precarregamento de aplicações" \
        "EarlyOOM - Prevenção de sistema congelado" \
        "ZRAM - Swap comprimido (se RAM < 16GB)" \
        "Ferramentas opcionais (htop, iotop, etc.)"
    
    echo ""
    echo -e "${YELLOW}⚠️ NOTA:${NC} Gestão de energia removida - usa configuração do sistema"
    
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
    
    # Instalar ferramentas (sem gestão energia)
    install_preload
    install_earlyoom
    install_zram
    install_optional_tools
    
    # Verificação final
    verify_installations
    
    # Relatório final
    show_next_steps
    
    echo ""
    log_success "🎉 Instalação de ferramentas da comunidade concluída!"
    echo ""
    highlight_note "REINICIE o sistema para ativar todas as ferramentas: sudo reboot"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
