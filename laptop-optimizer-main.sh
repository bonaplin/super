# =============================================================================
# SUBSTITUIR a função run_enterprise_optimization() (linha ~190)
# =============================================================================

run_enterprise_optimization() {
    log_info "🏢 Iniciando modo empresarial..."

    # Verificação empresarial (função correta)
    source "$SCRIPT_DIR/modules/enterprise-conflicts.sh"
    local enterprise_score
    enterprise_score=$(detect_enterprise_environment)
    check_enterprise_conflicts  # ← CORRIGIDO: função que existe

    # Backup obrigatório
    source "$SCRIPT_DIR/lib/backup.sh"
    create_system_backup

    # Apenas ferramentas seguras (usar script, não função)
    if confirm "Instalar ferramentas da comunidade (modo conservador)?" "y"; then
        "$SCRIPT_DIR/install-community-tools.sh"  # ← CORRIGIDO: usar script
    fi

    # Configurações mínimas
    source "$SCRIPT_DIR/modules/essential-tweaks.sh"
    apply_essential_tweaks

    # Scripts utilitários (sempre seguros)
    source "$SCRIPT_DIR/modules/utility-scripts.sh"
    create_utility_scripts

    # Usar função que existe (CORRIGIDO)
    show_enterprise_summary "$enterprise_score"  # ← CORRIGIDO: função que existe
}

# =============================================================================
# ADICIONAR esta função no final do ficheiro (antes do main)
# =============================================================================

show_enterprise_summary() {
    local enterprise_score="${1:-0}"
    
    clear
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🏢 MODO EMPRESARIAL CONCLUÍDO                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    echo -e "${GREEN}✅ APLICADO (MODO CONSERVADOR):${NC}"
    echo "   🔋 Ferramentas da comunidade (se selecionado)"
    echo "   ⚙️ Otimizações essenciais de kernel"
    echo "   ⚡ Scripts utilitários práticos"
    echo "   💾 Backup completo do sistema"
    echo ""
    echo -e "${BLUE}🛡️ PRESERVADO (SEGURANÇA EMPRESARIAL):${NC}"
    echo "   📶 Configurações de rede existentes"
    echo "   🔒 Configurações SSH empresariais"
    echo "   🛡️ Firewall existente"
    echo "   🌐 DNS empresarial"
    echo ""
    echo -e "${YELLOW}🎯 COMANDOS DISPONÍVEIS:${NC}"
    echo "   dev-status    - Ver status do sistema"
    echo "   dev-health    - Health check completo"
    echo "   dev-tools     - Verificar ferramentas"
    echo ""
    echo -e "${BLUE}📊 Score empresarial detectado: $enterprise_score${NC}"
    echo ""
    
    pause_and_return
}