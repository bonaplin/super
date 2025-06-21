#!/bin/bash
# =============================================================================
# LAPTOP OPTIMIZER - SETUP AUTOMÁTICO
# Instala e configura o sistema modular completo
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="4.0-modular"
readonly INSTALL_DIR="/opt/laptop-optimizer"
readonly BIN_DIR="/usr/local/bin"

# Cores básicas
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# FUNÇÕES DE LOG
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")    echo -e "${BLUE}ℹ️${NC} ${message}" ;;
        "SUCCESS") echo -e "${GREEN}✅${NC} ${message}" ;;
        "WARNING") echo -e "${YELLOW}⚠️${NC} ${message}" ;;
        "ERROR")   echo -e "${RED}❌${NC} ${message}" ;;
    esac
}

header() {
    echo ""
    echo -e "${BLUE}╔$(printf '═%.0s' {1..60})╗${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..60})║${NC}"
    echo -e "${BLUE}║  $1$(printf ' %.0s' $(seq 1 $((58 - ${#1}))))║${NC}"
    echo -e "${BLUE}║$(printf ' %.0s' {1..60})║${NC}"
    echo -e "${BLUE}╚$(printf '═%.0s' {1..60})╝${NC}"
    echo ""
}

# =============================================================================
# VERIFICAÇÕES PRÉ-INSTALAÇÃO
# =============================================================================

check_requirements() {
    header "Verificação de Requisitos"
    
    # Root check
    if [[ $EUID -eq 0 ]]; then
        log "ERROR" "Não execute como root! Use: ./setup.sh"
        exit 1
    fi
    
    # Sudo check
    if ! sudo -n true 2>/dev/null; then
        log "INFO" "Verificando permissões sudo..."
        sudo -v
    fi
    
    # Sistema check
    if [[ ! -f /etc/lsb-release ]] && [[ ! -f /etc/debian_version ]]; then
        log "WARNING" "Sistema não-Ubuntu/Debian detectado"
        if ! confirm "Continuar mesmo assim?" "n"; then
            exit 1
        fi
    fi
    
    # Espaço em disco
    local free_space_gb=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    if (( $(echo "$free_space_gb < 1.0" | bc -l) )); then
        log "ERROR" "Espaço insuficiente: ${free_space_gb}GB"
        exit 1
    fi
    
    log "SUCCESS" "Requisitos verificados"
}

confirm() {
    local question="$1"
    local default="${2:-n}"
    local response
    
    read -p "$(echo -e "${YELLOW}?${NC} ${question} [${default}]: ")" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# =============================================================================
# INSTALAÇÃO DO SISTEMA
# =============================================================================

install_system() {
    header "Instalação do Laptop Optimizer"
    
    log "INFO" "Instalando para: $INSTALL_DIR"
    
    # Criar diretórios
    sudo mkdir -p "$INSTALL_DIR"
    sudo mkdir -p "$INSTALL_DIR"/{lib,modules,config,tools}
    
    # Copiar ficheiros principais
    sudo cp "$SCRIPT_DIR/optimize-laptop.sh" "$INSTALL_DIR/"
    sudo cp "$SCRIPT_DIR/install-community-tools.sh" "$INSTALL_DIR/"
    
    # Copiar bibliotecas
    if [[ -d "$SCRIPT_DIR/lib" ]]; then
        sudo cp -r "$SCRIPT_DIR/lib"/* "$INSTALL_DIR/lib/"
    fi
    
    # Copiar módulos
    if [[ -d "$SCRIPT_DIR/modules" ]]; then
        sudo cp -r "$SCRIPT_DIR/modules"/* "$INSTALL_DIR/modules/"
    fi
    
    # Copiar configurações
    if [[ -d "$SCRIPT_DIR/config" ]]; then
        sudo cp -r "$SCRIPT_DIR/config"/* "$INSTALL_DIR/config/"
    fi
    
    # Dar permissões
    sudo chmod +x "$INSTALL_DIR"/*.sh
    sudo chmod +x "$INSTALL_DIR/lib"/*.sh 2>/dev/null || true
    sudo chmod +x "$INSTALL_DIR/modules"/*.sh 2>/dev/null || true
    
    # Criar symlink no PATH
    sudo ln -sf "$INSTALL_DIR/optimize-laptop.sh" "$BIN_DIR/laptop-optimizer"
    
    log "SUCCESS" "Sistema instalado em $INSTALL_DIR"
}

# =============================================================================
# CONFIGURAÇÃO INICIAL
# =============================================================================

configure_system() {
    header "Configuração Inicial"
    
    # Criar configuração de utilizador
    local user_config="$HOME/.laptop-optimizer-config"
    
    if [[ ! -f "$user_config" ]]; then
        cat > "$user_config" << 'EOF'
# Configuração pessoal do Laptop Optimizer
# Sobrescreve configurações em /opt/laptop-optimizer/config/settings.conf

# Configurações gerais
# AUTO_BACKUP="true"
# MAX_BACKUPS=10
# ENABLE_NOTIFICATIONS="true"

# Configurações de desenvolvimento  
# INSTALL_MODERN_TOOLS="yes"
# DEFAULT_ANSWER="y"

# Configurações empresariais
# AUTO_ENTERPRISE_MODE="true"
# ENTERPRISE_SCORE_THRESHOLD=5
EOF
        log "SUCCESS" "Configuração de utilizador criada: $user_config"
    fi
    
    # Configurar alias global
    if confirm "Criar alias 'laptop-opt' para acesso rápido?" "y"; then
        # Adicionar ao bashrc se não existir
        if ! grep -q "alias laptop-opt" ~/.bashrc 2>/dev/null; then
            echo "alias laptop-opt='laptop-optimizer'" >> ~/.bashrc
        fi
        
        # Se zsh existe, adicionar também
        if [[ -f ~/.zshrc ]] && ! grep -q "alias laptop-opt" ~/.zshrc 2>/dev/null; then
            echo "alias laptop-opt='laptop-optimizer'" >> ~/.zshrc
        fi
        
        log "SUCCESS" "Alias 'laptop-opt' criado"
    fi
    
    log "SUCCESS" "Configuração inicial concluída"
}

# =============================================================================
# VERIFICAÇÃO DA INSTALAÇÃO
# =============================================================================

verify_installation() {
    header "Verificação da Instalação"
    
    local issues=()
    
    # Verificar ficheiros principais
    [[ ! -f "$INSTALL_DIR/optimize-laptop.sh" ]] && issues+=("Script principal em falta")
    [[ ! -f "$INSTALL_DIR/install-community-tools.sh" ]] && issues+=("Installer de ferramentas em falta")
    
    # Verificar bibliotecas
    [[ ! -f "$INSTALL_DIR/lib/common.sh" ]] && issues+=("Biblioteca comum em falta")
    [[ ! -f "$INSTALL_DIR/lib/colors.sh" ]] && issues+=("Biblioteca de cores em falta")
    
    # Verificar módulos críticos
    [[ ! -f "$INSTALL_DIR/modules/enterprise-conflicts.sh" ]] && issues+=("Módulo empresarial em falta")
    [[ ! -f "$INSTALL_DIR/modules/development-config.sh" ]] && issues+=("Módulo desenvolvimento em falta")
    
    # Verificar comando global
    [[ ! -L "$BIN_DIR/laptop-optimizer" ]] && issues+=("Comando global não criado")
    [[ ! -x "$BIN_DIR/laptop-optimizer" ]] && issues+=("Comando global não executável")
    
    # Verificar configuração
    [[ ! -f "$INSTALL_DIR/config/settings.conf" ]] && issues+=("Configuração principal em falta")
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log "SUCCESS" "Instalação verificada com sucesso!"
        return 0
    else
        log "ERROR" "Problemas encontrados na instalação:"
        for issue in "${issues[@]}"; do
            echo "   • $issue"
        done
        return 1
    fi
}

# =============================================================================
# TESTE BÁSICO
# =============================================================================

run_basic_test() {
    header "Teste Básico do Sistema"
    
    if ! confirm "Executar teste básico?" "y"; then
        return 0
    fi
    
    log "INFO" "Testando comando principal..."
    
    # Teste do comando
    if "$INSTALL_DIR/optimize-laptop.sh" --version >/dev/null 2>&1; then
        log "SUCCESS" "Comando principal funcional"
    else
        log "WARNING" "Comando principal pode ter problemas"
    fi
    
    # Teste das bibliotecas
    log "INFO" "Testando bibliotecas..."
    if source "$INSTALL_DIR/lib/common.sh" >/dev/null 2>&1; then
        log "SUCCESS" "Bibliotecas carregam corretamente"
    else
        log "WARNING" "Problemas no carregamento de bibliotecas"
    fi
    
    # Teste da configuração
    log "INFO" "Testando configuração..."
    if source "$INSTALL_DIR/config/settings.conf" >/dev/null 2>&1; then
        log "SUCCESS" "Configuração carrega corretamente"
    else
        log "WARNING" "Problemas na configuração"
    fi
    
    log "SUCCESS" "Teste básico concluído"
}

# =============================================================================
# LIMPEZA DE INSTALAÇÃO ANTERIOR
# =============================================================================

cleanup_previous_installation() {
    if [[ -d "$INSTALL_DIR" ]]; then
        log "WARNING" "Instalação anterior detectada em $INSTALL_DIR"
        
        if confirm "Remover instalação anterior?" "y"; then
            # Backup de configurações de utilizador
            if [[ -f "$INSTALL_DIR/config/settings.conf" ]]; then
                local backup_config="/tmp/laptop-optimizer-config-backup.conf"
                cp "$INSTALL_DIR/config/settings.conf" "$backup_config" 2>/dev/null || true
                log "INFO" "Backup de configuração criado: $backup_config"
            fi
            
            # Remover instalação
            sudo rm -rf "$INSTALL_DIR"
            sudo rm -f "$BIN_DIR/laptop-optimizer"
            
            log "SUCCESS" "Instalação anterior removida"
        else
            log "ERROR" "Não é possível continuar com instalação anterior"
            exit 1
        fi
    fi
}

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

show_completion_report() {
    header "Instalação Concluída"
    
    echo -e "${GREEN}🎉 Laptop Optimizer v$VERSION instalado com sucesso!${NC}"
    echo ""
    echo -e "${BLUE}📁 Localização:${NC} $INSTALL_DIR"
    echo -e "${BLUE}🔗 Comando global:${NC} laptop-optimizer"
    echo -e "${BLUE}⚡ Alias rápido:${NC} laptop-opt (se criado)"
    echo ""
    echo -e "${BLUE}🚀 COMO USAR:${NC}"
    echo "   laptop-optimizer              # Menu principal"
    echo "   laptop-opt                    # Alias rápido"
    echo "   cd $INSTALL_DIR && ./optimize-laptop.sh  # Direto"
    echo ""
    echo -e "${BLUE}⚙️ CONFIGURAÇÃO:${NC}"
    echo "   Global: $INSTALL_DIR/config/settings.conf"
    echo "   Pessoal: $HOME/.laptop-optimizer-config"
    echo ""
    echo -e "${BLUE}📖 DOCUMENTAÇÃO:${NC}"
    echo "   README: $INSTALL_DIR/README.md"
    echo "   Logs: /tmp/laptop-optimizer.log"
    echo ""
    echo -e "${YELLOW}💡 PRÓXIMOS PASSOS:${NC}"
    echo "   1. Executar: laptop-optimizer"
    echo "   2. Escolher cenário adequado (empresarial/pessoal)"
    echo "   3. Seguir recomendações do sistema"
    echo ""
    echo -e "${GREEN}✨ Aproveite o seu laptop otimizado!${NC}"
    echo ""
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    clear
    
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 LAPTOP OPTIMIZER v$VERSION                             ║
║                           INSTALAÇÃO AUTOMÁTICA                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    echo -e "${BLUE}Este instalador vai:${NC}"
    echo "   • Instalar o sistema modular em $INSTALL_DIR"
    echo "   • Criar comando global 'laptop-optimizer'"
    echo "   • Configurar alias e configurações de utilizador"
    echo "   • Verificar e testar a instalação"
    echo ""
    
    if ! confirm "Continuar com a instalação?" "y"; then
        log "INFO" "Instalação cancelada"
        exit 0
    fi
    
    # Executar instalação
    check_requirements
    cleanup_previous_installation
    install_system
    configure_system
    
    # Verificar e testar
    if verify_installation; then
        run_basic_test
        show_completion_report
    else
        log "ERROR" "Instalação falhou - verificar problemas acima"
        exit 1
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi