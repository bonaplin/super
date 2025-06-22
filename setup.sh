#!/bin/bash
# =============================================================================
# SETUP.SH - INSTALLER PRINCIPAL DO LAPTOP OPTIMIZER
# Instala o sistema globalmente e cria comando 'laptop-optimizer'
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="/opt/laptop-optimizer"
readonly BIN_DIR="/usr/local/bin"

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log() {
    echo -e "${BLUE}[SETUP]${NC} $*"
}

success() {
    echo -e "${GREEN}✅${NC} $*"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $*"
}

error() {
    echo -e "${RED}❌${NC} $*"
}

check_requirements() {
    log "Verificando requisitos..."
    
    # Verificar se é root
    if [[ $EUID -ne 0 ]]; then
        error "Execute como root: sudo ./setup.sh"
        exit 1
    fi
    
    # Verificar estrutura
    local required_files=(
        "optimize-laptop.sh"
        "laptop-optimizer-main.sh"
        "lib/colors.sh"
        "lib/common.sh"
        "config/settings.conf"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            error "Ficheiro em falta: $file"
            exit 1
        fi
    done
    
    success "Requisitos verificados"
}

install_system() {
    log "Instalando Laptop Optimizer..."
    
    # Criar directório de instalação
    mkdir -p "$INSTALL_DIR"
    
    # Copiar ficheiros
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
    
    # Definir permissões
    chmod +x "$INSTALL_DIR"/*.sh
    chmod +x "$INSTALL_DIR"/lib/*.sh
    chmod +x "$INSTALL_DIR"/modules/*.sh
    chmod +x "$INSTALL_DIR"/tests/*.sh
    
    success "Ficheiros copiados para $INSTALL_DIR"
}

create_global_command() {
    log "Criando comando global 'laptop-optimizer'..."
    
    cat > "$BIN_DIR/laptop-optimizer" << EOF
#!/bin/bash
# Laptop Optimizer - Comando Global
exec "$INSTALL_DIR/optimize-laptop.sh" "\$@"
EOF
    
    chmod +x "$BIN_DIR/laptop-optimizer"
    
    success "Comando 'laptop-optimizer' disponível globalmente"
}

create_uninstaller() {
    log "Criando uninstaller..."
    
    cat > "$BIN_DIR/laptop-optimizer-uninstall" << 'EOF'
#!/bin/bash
# Uninstaller do Laptop Optimizer

if [[ $EUID -ne 0 ]]; then
    echo "Execute como root: sudo laptop-optimizer-uninstall"
    exit 1
fi

echo "🗑️ Removendo Laptop Optimizer..."

# Remover ficheiros
rm -rf /opt/laptop-optimizer
rm -f /usr/local/bin/laptop-optimizer
rm -f /usr/local/bin/laptop-optimizer-uninstall

# Remover scripts utilitários (opcional)
read -p "Remover scripts utilitários (dev-*)? (y/N): " remove_utils
if [[ "$remove_utils" =~ ^[Yy] ]]; then
    rm -f /usr/local/bin/dev-*
    rm -f /usr/local/bin/docker-clean
    echo "Scripts utilitários removidos"
fi

# Remover configurações (opcional)
read -p "Remover configurações de otimização? (y/N): " remove_configs
if [[ "$remove_configs" =~ ^[Yy] ]]; then
    rm -f /etc/sysctl.d/99-dev-*.conf
    rm -f /etc/sysctl.d/99-essential-*.conf
    rm -f /etc/security/limits.d/99-dev-*.conf
    rm -f /etc/cron.d/dev-*
    echo "Configurações removidas"
fi

echo "✅ Laptop Optimizer removido com sucesso"
EOF
    
    chmod +x "$BIN_DIR/laptop-optimizer-uninstall"
    
    success "Uninstaller criado"
}

main() {
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    📦 LAPTOP OPTIMIZER - INSTALLER                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    log "Instalando Laptop Optimizer globalmente..."
    echo ""
    
    check_requirements
    install_system
    create_global_command
    create_uninstaller
    
    echo ""
    success "🎉 Instalação concluída!"
    echo ""
    echo -e "${YELLOW}💡 COMANDOS DISPONÍVEIS:${NC}"
    echo "   laptop-optimizer                 - Executar optimizer"
    echo "   laptop-optimizer --help          - Ver ajuda"
    echo "   laptop-optimizer-uninstall       - Remover sistema"
    echo ""
    echo -e "${YELLOW}🚀 PRÓXIMO PASSO:${NC}"
    echo "   laptop-optimizer"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi