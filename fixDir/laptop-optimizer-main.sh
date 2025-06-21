#!/bin/bash
# =============================================================================
# LAPTOP OPTIMIZER - SCRIPT PRINCIPAL MODULAR
# Versão: 4.0 - Abordagem Híbrida (Comunidade + Personalizado)
# =============================================================================

set -euo pipefail

# Diretórios e configuração
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="4.0-modular"
readonly CONFIG_FILE="$SCRIPT_DIR/config/settings.conf"

# Carregar bibliotecas
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# =============================================================================
# MENU PRINCIPAL
# =============================================================================

show_main_menu() {
    clear
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║               🚀 LAPTOP OPTIMIZER v${VERSION} - HÍBRIDO                        ║
║                                                                              ║
║  🎯 ESTRATÉGIA: Ferramentas Comunidade + Configurações Únicas               ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"

    echo ""
    echo -e "${GREEN}📋 OPÇÕES PRINCIPAIS:${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} 🌍 Instalar ferramentas da comunidade ${BLUE}(TLP, auto-cpufreq, preload)${NC}"
    echo -e "  ${YELLOW}2.${NC} 🏢 Verificar conflitos empresariais ${BLUE}(VPN, Docker, SSH)${NC}"
    echo -e "  ${YELLOW}3.${NC} 🛠️  Configurações para desenvolvimento ${BLUE}(inotify, limits, aliases)${NC}"
    echo -e "  ${YELLOW}4.${NC} 🧹 Sistema de manutenção inteligente ${BLUE}(limpeza automática)${NC}"
    echo -e "  ${YELLOW}5.${NC} ⚡ Scripts utilitários práticos ${BLUE}(dev-status, dev-clean)${NC}"
    echo -e "  ${YELLOW}6.${NC} 🐳 Docker cleanup inteligente ${BLUE}(preserva DBs)${NC}"
    echo -e "  ${YELLOW}7.${NC} 🔧 Apenas otimizações essenciais ${BLUE}(mínimo seguro)${NC}"
    echo ""
    echo -e "${GREEN}🚀 OPÇÕES COMPLETAS:${NC}"
    echo ""
    echo -e "  ${YELLOW}8.${NC} 🎯 Otimização completa recomendada ${BLUE}(todas as opções)${NC}"
    echo -e "  ${YELLOW}9.${NC} 🏢 Modo empresarial conservador ${BLUE}(máxima compatibilidade)${NC}"
    echo ""
    echo -e "${GREEN}📊 INFORMAÇÃO:${NC}"
    echo ""
    echo -e "  ${YELLOW}s.${NC} 📊 Status atual do sistema"
    echo -e "  ${YELLOW}t.${NC} 🧪 Testar otimizações existentes"
    echo -e "  ${YELLOW}h.${NC} ❓ Ajuda e documentação"
    echo -e "  ${YELLOW}q.${NC} 🚪 Sair"
    echo ""
    
    read -p "$(echo -e "${CYAN}Escolha uma opção:${NC} ")" choice
    handle_menu_choice "$choice"
}

handle_menu_choice() {
    local choice="$1"
    
    case "$choice" in
        1) install_community_tools ;;
        2) run_enterprise_check ;;
        3) configure_development ;;
        4) setup_maintenance ;;
        5) install_utilities ;;
        6) setup_docker_cleanup ;;
        7) apply_essential_only ;;
        8) run_complete_optimization ;;
        9) run_enterprise_mode ;;
        s|S) show_system_status ;;
        t|T) test_optimizations ;;
        h|H) show_help ;;
        q|Q) exit 0 ;;
        *) 
            echo -e "${RED}❌ Opção inválida: $choice${NC}"
            sleep 2
            show_main_menu
            ;;
    esac
}

# =============================================================================
# FUNÇÕES PRINCIPAIS (DELEGAM PARA MÓDULOS)
# =============================================================================

install_community_tools() {
    log_header "🌍 INSTALANDO FERRAMENTAS DA COMUNIDADE"
    
    if confirm "Instalar ferramentas da comunidade (TLP, auto-cpufreq, preload, earlyoom)?" "y"; then
        "$SCRIPT_DIR/install-community-tools.sh"
        
        log_success "Ferramentas da comunidade instaladas!"
        echo ""
        echo -e "${BLUE}💡 PRÓXIMOS PASSOS:${NC}"
        echo "   • Reiniciar para ativar TLP e auto-cpufreq"
        echo "   • Verificar: sudo tlp-stat"
        echo "   • Verificar: sudo auto-cpufreq --stats"
        pause_and_return
    fi
}

run_enterprise_check() {
    log_header "🏢 VERIFICAÇÃO DE CONFLITOS EMPRESARIAIS"
    
    source "$SCRIPT_DIR/modules/enterprise-conflicts.sh"
    
    echo -e "${BLUE}🔍 Esta verificação vai detectar:${NC}"
    echo "   • VPN ativo (conflitos DNS/rede)"
    echo "   • Configurações Docker empresariais"
    echo "   • Políticas SSH da empresa"
    echo "   • DNS e firewall mandatórios"
    echo ""
    
    if confirm "Executar verificação empresarial?" "y"; then
        check_enterprise_conflicts
        pause_and_return
    fi
}

configure_development() {
    log_header "🛠️ CONFIGURAÇÕES PARA DESENVOLVIMENTO"
    
    source "$SCRIPT_DIR/modules/development-config.sh"
    
    echo -e "${BLUE}🔧 Configurações a aplicar:${NC}"
    echo "   • Aumentar inotify watches (crítico para IDEs)"
    echo "   • Configurar limits para file descriptors"
    echo "   • Aliases inteligentes para desenvolvimento"
    echo "   • Configuração Git básica"
    echo "   • Bash/Zsh history melhorado"
    echo ""
    
    if confirm "Aplicar configurações de desenvolvimento?" "y"; then
        apply_development_config
        pause_and_return
    fi
}

setup_maintenance() {
    log_header "🧹 SISTEMA DE MANUTENÇÃO INTELIGENTE"
    
    source "$SCRIPT_DIR/modules/smart-maintenance.sh"
    
    echo -e "${BLUE}🔧 Sistema de manutenção inclui:${NC}"
    echo "   • Limpeza automática diária/semanal/mensal"
    echo "   • Monitorização de espaço em disco"
    echo "   • Alertas quando espaço baixo"
    echo "   • Limpeza Docker inteligente (preserva DBs)"
    echo "   • Logs estruturados"
    echo ""
    
    if confirm "Instalar sistema de manutenção?" "y"; then
        setup_smart_maintenance
        pause_and_return
    fi
}

install_utilities() {
    log_header "⚡ SCRIPTS UTILITÁRIOS PRÁTICOS"
    
    source "$SCRIPT_DIR/modules/utility-scripts.sh"
    
    echo -e "${BLUE}🛠️ Scripts a instalar:${NC}"
    echo "   • dev-status    - Dashboard do sistema"
    echo "   • dev-clean     - Limpeza inteligente"
    echo "   • dev-health    - Health check completo"
    echo "   • dev-tools     - Verificar ferramentas instaladas"
    echo "   • dev-benchmark - Testar performance"
    echo ""
    
    if confirm "Instalar scripts utilitários?" "y"; then
        create_utility_scripts
        pause_and_return
    fi
}

setup_docker_cleanup() {
    log_header "🐳 DOCKER CLEANUP INTELIGENTE"
    
    if ! command -v docker >/dev/null 2>&1; then
        log_warning "Docker não instalado - skip"
        pause_and_return
        return
    fi
    
    source "$SCRIPT_DIR/modules/docker-cleanup.sh"
    
    echo -e "${BLUE}🔧 Limpeza Docker inteligente:${NC}"
    echo "   • Detecta automaticamente containers de BD"
    echo "   • Remove apenas containers/imagens não-BD"
    echo "   • Preserva volumes com dados importantes"
    echo "   • Três modos: conservador, moderado, agressivo"
    echo ""
    
    if confirm "Configurar Docker cleanup inteligente?" "y"; then
        setup_smart_docker_cleanup
        pause_and_return
    fi
}

apply_essential_only() {
    log_header "🔧 APENAS OTIMIZAÇÕES ESSENCIAIS"
    
    source "$SCRIPT_DIR/modules/essential-tweaks.sh"
    
    echo -e "${BLUE}🎯 Otimizações mínimas e seguras:${NC}"
    echo "   • vm.swappiness=10 (menos swap)"
    echo "   • inotify watches aumentado"
    echo "   • TLP para gestão de energia"
    echo "   • TRIM automático para SSD"
    echo ""
    
    if confirm "Aplicar apenas essenciais?" "y"; then
        apply_essential_tweaks
        pause_and_return
    fi
}

run_complete_optimization() {
    log_header "🚀 OTIMIZAÇÃO COMPLETA"
    
    echo -e "${BLUE}🎯 Otimização completa inclui:${NC}"
    echo "   1. Verificação de conflitos empresariais"
    echo "   2. Backup automático do sistema"
    echo "   3. Instalação de ferramentas da comunidade"
    echo "   4. Configurações para desenvolvimento"
    echo "   5. Sistema de manutenção automático"
    echo "   6. Scripts utilitários práticos"
    echo ""
    echo -e "${YELLOW}⏱️ Tempo estimado: 10-15 minutos${NC}"
    echo ""
    
    if confirm "Executar otimização completa?" "y"; then
        run_full_optimization
    fi
}

run_enterprise_mode() {
    log_header "🏢 MODO EMPRESARIAL CONSERVADOR"
    
    echo -e "${BLUE}🛡️ Modo empresarial:${NC}"
    echo "   • Verificação extensiva de conflitos"
    echo "   • Apenas mudanças conservadoras"
    echo "   • Backup obrigatório"
    echo "   • Configurações reversíveis"
    echo "   • Foco em compatibilidade"
    echo ""
    
    if confirm "Executar modo empresarial?" "y"; then
        run_enterprise_optimization
    fi
}

# =============================================================================
# FUNÇÕES DE EXECUÇÃO COMPLETA
# =============================================================================

run_full_optimization() {
    log_info "🚀 Iniciando otimização completa..."
    
    # 1. Validação sistema
    source "$SCRIPT_DIR/lib/validation.sh"
    validate_system_requirements
    
    # 2. Verificação empresarial
    source "$SCRIPT_DIR/modules/enterprise-conflicts.sh"
    check_enterprise_conflicts
    
    # 3. Backup
    source "$SCRIPT_DIR/lib/backup.sh"
    create_system_backup
    
    # 4. Ferramentas comunidade
    "$SCRIPT_DIR/install-community-tools.sh"
    
    # 5. Configurações desenvolvimento
    source "$SCRIPT_DIR/modules/development-config.sh"
    apply_development_config
    
    # 6. Sistema manutenção
    source "$SCRIPT_DIR/modules/smart-maintenance.sh"
    setup_smart_maintenance
    
    # 7. Scripts utilitários
    source "$SCRIPT_DIR/modules/utility-scripts.sh"
    create_utility_scripts
    
    # 8. Docker (se disponível)
    if command -v docker >/dev/null 2>&1; then
        source "$SCRIPT_DIR/modules/docker-cleanup.sh"
        setup_smart_docker_cleanup
    fi
    
    show_completion_report
}

run_enterprise_optimization() {
    log_info "🏢 Iniciando modo empresarial..."
    
    # Verificação extensiva
    source "$SCRIPT_DIR/modules/enterprise-conflicts.sh"
    check_enterprise_conflicts_extensive
    
    # Backup obrigatório
    source "$SCRIPT_DIR/lib/backup.sh"
    create_system_backup
    
    # Apenas ferramentas seguras
    install_safe_community_tools
    
    # Configurações mínimas
    source "$SCRIPT_DIR/modules/essential-tweaks.sh"
    apply_essential_tweaks
    
    # Scripts utilitários (sempre seguros)
    source "$SCRIPT_DIR/modules/utility-scripts.sh"
    create_utility_scripts
    
    show_enterprise_report
}

# =============================================================================
# FUNÇÕES DE INFORMAÇÃO
# =============================================================================

show_system_status() {
    clear
    echo -e "${BLUE}📊 STATUS ATUAL DO SISTEMA${NC}"
    echo "================================"
    echo ""
    
    # Usar script dev-status se disponível
    if [[ -f /usr/local/bin/dev-status ]]; then
        /usr/local/bin/dev-status
    else
        # Fallback básico
        echo "💾 ESPAÇO:"
        df -h / | awk 'NR==2 {printf "   %s usado de %s (%s livre)\n", $3, $2, $4}'
        echo ""
        echo "🖥️ SISTEMA:"
        echo "   RAM: $(free -h | awk '/^Mem:/{printf "%s usado de %s", $3, $2}')"
        echo "   CPU: $(nproc) cores"
        echo ""
        echo "🔧 OTIMIZAÇÕES:"
        [[ -f /etc/sysctl.d/99-dev-*.conf ]] && echo "   ✅ Configurações sysctl aplicadas" || echo "   ❌ Sem configurações sysctl"
        command -v tlp >/dev/null && echo "   ✅ TLP instalado" || echo "   ❌ TLP não instalado"
        command -v auto-cpufreq >/dev/null && echo "   ✅ auto-cpufreq instalado" || echo "   ❌ auto-cpufreq não instalado"
    fi
    
    pause_and_return
}

test_optimizations() {
    clear
    echo -e "${BLUE}🧪 TESTANDO OTIMIZAÇÕES${NC}"
    echo "========================"
    echo ""
    
    if [[ -f /usr/local/bin/dev-benchmark ]]; then
        /usr/local/bin/dev-benchmark
    else
        echo "⚠️ Script de benchmark não encontrado"
        echo "Execute primeiro: opção 5 (Scripts utilitários)"
    fi
    
    pause_and_return
}

show_help() {
    clear
    echo -e "${BLUE}❓ AJUDA E DOCUMENTAÇÃO${NC}"
    echo "========================"
    echo ""
    echo -e "${GREEN}📖 FILOSOFIA DO PROJETO:${NC}"
    echo "   Este optimizer usa abordagem híbrida:"
    echo "   • Ferramentas da comunidade para performance base"
    echo "   • Configurações únicas para ambiente empresarial"
    echo "   • Scripts práticos para desenvolvimento"
    echo ""
    echo -e "${GREEN}🎯 QUANDO USAR CADA OPÇÃO:${NC}"
    echo ""
    echo -e "${YELLOW}1. Ferramentas comunidade:${NC}"
    echo "   → Primeira vez, laptop novo"
    echo "   → Quer melhor performance geral"
    echo ""
    echo -e "${YELLOW}2. Verificação empresarial:${NC}"
    echo "   → Laptop da empresa"
    echo "   → Tem VPN, Docker, SSH configurado"
    echo ""
    echo -e "${YELLOW}3. Config desenvolvimento:${NC}"
    echo "   → Programador/desenvolvedor"
    echo "   → Usa IDEs, Node.js, Docker"
    echo ""
    echo -e "${YELLOW}8. Otimização completa:${NC}"
    echo "   → Laptop pessoal"
    echo "   → Primeira execução"
    echo "   → Quer tudo configurado"
    echo ""
    echo -e "${YELLOW}9. Modo empresarial:${NC}"
    echo "   → Laptop da empresa"
    echo "   → Máxima compatibilidade"
    echo "   → Configurações conservadoras"
    echo ""
    
    pause_and_return
}

show_completion_report() {
    clear
    echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🎉 OTIMIZAÇÃO COMPLETA CONCLUÍDA                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    echo -e "${GREEN}✅ APLICADO:${NC}"
    echo "   🌍 Ferramentas da comunidade instaladas"
    echo "   🛠️ Configurações de desenvolvimento aplicadas"
    echo "   🧹 Sistema de manutenção ativo"
    echo "   ⚡ Scripts utilitários disponíveis"
    echo ""
    echo -e "${BLUE}🎯 COMANDOS DISPONÍVEIS:${NC}"
    echo "   dev-status    - Ver status do sistema"
    echo "   dev-clean     - Limpeza inteligente"
    echo "   dev-health    - Health check"
    echo "   dev-benchmark - Testar performance"
    echo ""
    echo -e "${YELLOW}🔄 PRÓXIMOS PASSOS:${NC}"
    echo "   1. Reiniciar: sudo reboot"
    echo "   2. Testar: dev-status"
    echo "   3. Benchmark: dev-benchmark"
    echo ""
    
    pause_and_return
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Carregar configuração
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
    
    # Verificação básica
    if [[ $EUID -eq 0 ]]; then
        log_error "Não execute como root! Use: ./optimize-laptop.sh"
        exit 1
    fi
    
    # Menu principal
    while true; do
        show_main_menu
    done
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi