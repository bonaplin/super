#!/bin/bash
# =============================================================================
# LAPTOP OPTIMIZER - SCRIPT PRINCIPAL INTEGRADO
# Verificação automática de dependências + sistema completo
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="4.0-modular"

# =============================================================================
# VERIFICAÇÃO AUTOMÁTICA DE DEPENDÊNCIAS
# =============================================================================

check_essential_dependencies() {
    # Definir cores se não estiverem já definidas
    [[ -z "${RED:-}" ]] && RED='\033[0;31m'
    [[ -z "${GREEN:-}" ]] && GREEN='\033[0;32m'
    [[ -z "${YELLOW:-}" ]] && YELLOW='\033[1;33m'
    [[ -z "${BLUE:-}" ]] && BLUE='\033[0;34m'
    [[ -z "${NC:-}" ]] && NC='\033[0m'

    echo -e "${BLUE}🔍 Verificando dependências essenciais...${NC}"

    local missing_commands=()
    local essential_commands=("sudo" "systemctl" "bc" "curl" "git" "grep" "awk" "sed" "free" "df" "nproc")

    for cmd in "${essential_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    # Verificar se não é root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}❌ NÃO execute como root!${NC}"
        echo "   Execute como utilizador normal: ./optimize-laptop.sh"
        exit 1
    fi

    # Se há comandos em falta
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ Comandos em falta: ${missing_commands[*]}${NC}"
        echo ""
        echo -e "${BLUE}💡 SOLUÇÕES:${NC}"
        echo "   1. Instalação automática: ./check-dependencies.sh"
        echo "   2. Instalação manual: sudo apt update && sudo apt install ${missing_commands[*]}"
        echo "   3. Verificação rápida: ./quick-check.sh"
        echo ""

        read -p "Tentar instalação automática agora? (y/N): " auto_install

        if [[ "$auto_install" =~ ^[Yy] ]]; then
            if [[ -f "$SCRIPT_DIR/check-dependencies.sh" ]]; then
                echo ""
                echo -e "${BLUE}🔧 Executando instalação automática...${NC}"
                "$SCRIPT_DIR/check-dependencies.sh"
                echo ""
                echo -e "${BLUE}🔄 Verificando novamente após instalação...${NC}"
                # Verificar novamente após instalação
                exec "$0" "$@"
            else
                echo -e "${RED}❌ Script check-dependencies.sh não encontrado${NC}"
                echo "   Instalar manualmente: sudo apt update && sudo apt install ${missing_commands[*]}"
                exit 1
            fi
        else
            echo -e "${YELLOW}⚠️ Dependências em falta - algumas funcionalidades podem falhar${NC}"
            echo -n "Continuar mesmo assim? (y/N): "
            read response
            if [[ ! "$response" =~ ^[Yy] ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✅ Todas as dependências essenciais presentes${NC}"
    fi

    # Verificar sudo
    if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
        echo -e "${RED}❌ Sudo não configurado corretamente${NC}"
        exit 1
    fi

    echo ""
}

# =============================================================================
# VERIFICAÇÃO DE ESTRUTURA
# =============================================================================

verify_project_structure() {
    local required_files=(
        "lib/colors.sh"
        "lib/common.sh"
        "config/settings.conf"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            echo -e "${RED:-}❌ Ficheiro crítico em falta: $file${NC:-}"
            echo "   Certifica-te que tens a estrutura completa do projeto"
            exit 1
        fi
    done
}

# =============================================================================
# CARREGAR BIBLIOTECAS (após verificação)
# =============================================================================

# Carregar bibliotecas se existirem
[[ -f "$SCRIPT_DIR/lib/colors.sh" ]] && source "$SCRIPT_DIR/lib/colors.sh"
[[ -f "$SCRIPT_DIR/lib/common.sh" ]] && source "$SCRIPT_DIR/lib/common.sh"
[[ -f "$SCRIPT_DIR/config/settings.conf" ]] && source "$SCRIPT_DIR/config/settings.conf"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

confirm() {
    local question="$1"
    local default="${2:-n}"
    local response

    read -p "$question [$default]: " response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
}

log_header() {
    echo ""
    echo -e "${BLUE}╔$(printf '═%.0s' {1..78})╗${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..78})║${NC}"
    echo -e "${BLUE}║  $1$(printf ' %.0s' $(seq 1 $((76 - ${#1}))))║${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..78})║${NC}"
    echo -e "${BLUE}╚$(printf '═%.0s' {1..78})╝${NC}"
    echo ""
}

bullet_list() {
    while [[ $# -gt 0 ]]; do
        echo -e "   ${BLUE}•${NC} $1"
        shift
    done
}

pause_and_return() {
    echo ""
    read -p "Prima Enter para continuar..."
    clear
}

show_system_info() {
    echo -e "${BLUE}📊 INFORMAÇÃO DO SISTEMA:${NC}"
    echo "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Desconhecido")"
    echo "   Kernel: $(uname -r)"
    echo "   CPU: $(nproc) cores"
    echo "   RAM: $(free -g | awk '/^Mem:/{print $2}')GB"
    echo ""
}

# =============================================================================
# ARGUMENTOS E AJUDA
# =============================================================================

show_help() {
    echo "Laptop Optimizer v$VERSION - Sistema modular de otimização"
    echo ""
    echo "Uso: ./optimize-laptop.sh [opção]"
    echo ""
    echo "Opções:"
    echo "  --version, -v         Mostrar versão"
    echo "  --help, -h           Mostrar esta ajuda"
    echo "  --check-deps         Verificar dependências"
    echo "  --quick-check        Verificação rápida"
    echo ""
    echo "🎯 CENÁRIOS DE USO:"
    echo "  Primeira vez:        ./optimize-laptop.sh"
    echo "  Uso empresarial:     ./optimize-laptop.sh (opção 9)"
    echo "  Uso pessoal:         ./optimize-laptop.sh (opção 8)"
    echo ""
    echo "📁 Estrutura:"
    echo "  lib/                 Bibliotecas comuns"
    echo "  modules/             Módulos funcionais"
    echo "  config/              Configurações"
    echo "  tests/               Testes e benchmarks"
    echo ""
    echo "🔗 Scripts auxiliares:"
    echo "  ./check-dependencies.sh    Verificação completa de dependências"
    echo "  ./quick-check.sh          Verificação rápida"
    echo "  ./setup.sh                Instalação global"
    echo ""
}

# Verificar argumentos especiais ANTES de carregar dependências
case "${1:-}" in
    "--version"|"-v")
        echo "Laptop Optimizer v$VERSION"
        exit 0
        ;;
    "--help"|"-h")
        show_help
        exit 0
        ;;
    "--check-deps")
        if [[ -f "$SCRIPT_DIR/check-dependencies.sh" ]]; then
            exec "$SCRIPT_DIR/check-dependencies.sh"
        else
            echo "❌ Script check-dependencies.sh não encontrado"
            exit 1
        fi
        ;;
    "--quick-check")
        if [[ -f "$SCRIPT_DIR/quick-check.sh" ]]; then
            exec "$SCRIPT_DIR/quick-check.sh"
        else
            echo "❌ Script quick-check.sh não encontrado"
            exit 1
        fi
        ;;
esac

# =============================================================================
# VERIFICAÇÕES INICIAIS
# =============================================================================

echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 LAPTOP OPTIMIZER v$VERSION                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"

# 1. Verificar estrutura do projeto
verify_project_structure

# 2. Verificar dependências automaticamente
check_essential_dependencies

# 3. Mostrar informação do sistema
show_system_info

# =============================================================================
# MENU PRINCIPAL
# =============================================================================

show_main_menu() {
    clear
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 LAPTOP OPTIMIZER v$VERSION                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"

    echo ""
    echo -e "${BLUE}🎯 ESCOLHE A TUA OPÇÃO:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} 🛠️ Ferramentas de Desenvolvimento (preload, earlyoom, zram, etc.)"
    echo -e "${GREEN}2.${NC} 🔧 Otimizações Essenciais (kernel, limites, inotify)"
    echo -e "${GREEN}3.${NC} 💻 Configurações de Desenvolvimento"
    echo -e "${GREEN}4.${NC} 🧹 Sistema de Manutenção Inteligente"
    echo -e "${GREEN}5.${NC} ⚡ Scripts Utilitários Práticos"
    echo -e "${GREEN}6.${NC} 🐳 Docker Cleanup Inteligente"
    echo ""
    echo -e "${YELLOW}8.${NC} 💻 Otimização Completa (Pessoal)"
    echo -e "${YELLOW}9.${NC} 🏢 Modo Empresarial (Conservador)"
    echo ""
    echo -e "${BLUE}0.${NC} ❌ Sair"
    echo ""
    echo -e "${BLUE}📋 Comandos úteis:${NC}"
    echo "   --check-deps     Verificar dependências completa"
    echo "   --quick-check    Verificação rápida"
    echo "   --help           Ajuda completa"
    echo ""
    echo -e "${YELLOW}⚠️ NOTA:${NC} Gestão energia removida - sistema usa configuração nativa"
    echo ""
}

# =============================================================================
# EXECUÇÃO DOS MÓDULOS
# =============================================================================

run_community_tools() {
    log_header "🌍 INSTALANDO FERRAMENTAS DA COMUNIDADE"
    if [[ -f "$SCRIPT_DIR/install-community-tools.sh" ]]; then
        "$SCRIPT_DIR/install-community-tools.sh"
    else
        echo "❌ Script install-community-tools.sh não encontrado"
    fi
}

run_essential_tweaks() {
    log_header "🔧 APLICANDO OTIMIZAÇÕES ESSENCIAIS"
    if [[ -f "$SCRIPT_DIR/modules/essential-tweaks.sh" ]]; then
        source "$SCRIPT_DIR/modules/essential-tweaks.sh"
        apply_essential_tweaks
    else
        echo "❌ Módulo essential-tweaks.sh não encontrado"
    fi
}

run_development_config() {
    log_header "🛠️ CONFIGURAÇÕES DE DESENVOLVIMENTO"
    if [[ -f "$SCRIPT_DIR/modules/development-config.sh" ]]; then
        source "$SCRIPT_DIR/modules/development-config.sh"
        apply_development_config
    else
        echo "❌ Módulo development-config.sh não encontrado"
    fi
}

run_smart_maintenance() {
    log_header "🧹 SISTEMA DE MANUTENÇÃO"
    if [[ -f "$SCRIPT_DIR/modules/smart-maintenance.sh" ]]; then
        source "$SCRIPT_DIR/modules/smart-maintenance.sh"
        setup_smart_maintenance
    else
        echo "❌ Módulo smart-maintenance.sh não encontrado"
    fi
}

run_utility_scripts() {
    log_header "⚡ SCRIPTS UTILITÁRIOS"
    if [[ -f "$SCRIPT_DIR/modules/utility-scripts.sh" ]]; then
        source "$SCRIPT_DIR/modules/utility-scripts.sh"
        create_utility_scripts
    else
        echo "❌ Módulo utility-scripts.sh não encontrado"
    fi
}

run_docker_cleanup() {
    log_header "🐳 DOCKER CLEANUP"
    if [[ -f "$SCRIPT_DIR/modules/docker-cleanup.sh" ]]; then
        source "$SCRIPT_DIR/modules/docker-cleanup.sh"
        setup_smart_docker_cleanup
    else
        echo "❌ Módulo docker-cleanup.sh não encontrado"
    fi
}

run_personal_optimization() {
    log_header "💻 OTIMIZAÇÃO COMPLETA PESSOAL"

    echo ""
    echo -e "${BLUE}Esta opção vai aplicar:${NC}"
    bullet_list \
        "✅ Ferramentas de desenvolvimento (preload, earlyoom, zram)" \
        "✅ Otimizações de kernel e sistema" \
        "✅ Configurações de desenvolvimento" \
        "✅ Sistema de manutenção automática" \
        "✅ Scripts utilitários práticos" \
        "✅ Docker cleanup inteligente"

    echo ""
    echo -e "${YELLOW}⚠️ NOTA:${NC} SEM gestão energia (TLP/auto-cpufreq) - usa configuração nativa"
    echo ""
    if ! confirm "Aplicar otimização completa?" "y"; then
        return 0
    fi

    # Validação do sistema
    if [[ -f "$SCRIPT_DIR/lib/validation.sh" ]]; then
        source "$SCRIPT_DIR/lib/validation.sh"
        if ! validate_system; then
            echo "❌ Sistema não passou na validação"
            return 1
        fi
    fi

    # Backup automático
    if [[ -f "$SCRIPT_DIR/lib/backup.sh" ]]; then
        source "$SCRIPT_DIR/lib/backup.sh"
        create_system_backup
    fi

    # Aplicar otimizações
    run_essential_tweaks
    run_development_config
    run_community_tools
    run_smart_maintenance
    run_utility_scripts
    run_docker_cleanup

    # Verificação final
    echo ""
    echo -e "${GREEN}🎉 Otimização completa concluída!${NC}"
    echo ""
    echo -e "${YELLOW}💡 PRÓXIMOS PASSOS:${NC}"
    bullet_list \
        "Reiniciar o sistema: sudo reboot" \
        "Testar: dev-status" \
        "Verificar: dev-health" \
        "Benchmark: dev-benchmark"

    echo ""
}

run_enterprise_optimization() {
    log_header "🏢 MODO EMPRESARIAL"

    echo ""
    echo -e "${BLUE}Modo empresarial aplica apenas:${NC}"
    bullet_list \
        "🔍 Verificação de conflitos empresariais" \
        "🔧 Otimizações essenciais (conservador)" \
        "🛠️ Configurações básicas de desenvolvimento" \
        "⚡ Scripts utilitários (sempre seguros)" \
        "💾 Backup completo obrigatório"

    echo ""
    if ! confirm "Aplicar modo empresarial?" "y"; then
        return 0
    fi

    # Verificação empresarial
    if [[ -f "$SCRIPT_DIR/modules/enterprise-conflicts.sh" ]]; then
        source "$SCRIPT_DIR/modules/enterprise-conflicts.sh"
        local enterprise_score
        enterprise_score=$(detect_enterprise_environment)
        check_enterprise_conflicts
    fi

    # Backup obrigatório
    if [[ -f "$SCRIPT_DIR/lib/backup.sh" ]]; then
        source "$SCRIPT_DIR/lib/backup.sh"
        create_system_backup
    fi

    # Apenas ferramentas seguras
    if confirm "Instalar ferramentas da comunidade (modo conservador)?" "y"; then
        run_community_tools
    fi

    # Configurações mínimas
    run_essential_tweaks

    # Scripts utilitários (sempre seguros)
    run_utility_scripts

    # Mostrar resumo empresarial
    show_enterprise_summary "${enterprise_score:-0}"

    echo -e "${GREEN}🎉 Modo empresarial aplicado com segurança!${NC}"
}

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

# =============================================================================
# LOOP PRINCIPAL DO MENU
# =============================================================================

main() {
    while true; do
        show_main_menu

        read -p "Escolhe uma opção [1-9, 0 para sair]: " choice

        case "$choice" in
            1)
                run_community_tools
                pause_and_return
                ;;
            2)
                run_essential_tweaks
                pause_and_return
                ;;
            3)
                run_development_config
                pause_and_return
                ;;
            4)
                run_smart_maintenance
                pause_and_return
                ;;
            5)
                run_utility_scripts
                pause_and_return
                ;;
            6)
                run_docker_cleanup
                pause_and_return
                ;;
            8)
                run_personal_optimization
                pause_and_return
                ;;
            9)
                run_enterprise_optimization
                pause_and_return
                ;;
            0)
                echo ""
                echo "👋 Obrigado por usar o Laptop Optimizer!"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo "❌ Opção inválida: $choice"
                echo ""
                read -p "Prima Enter para continuar..."
                ;;
        esac
    done
}

# =============================================================================
# EXECUÇÃO
# =============================================================================

# Executar menu principal
main "$@"