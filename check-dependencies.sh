#!/bin/bash
# =============================================================================
# VERIFICADOR E INSTALADOR DE DEPENDÊNCIAS - LAPTOP OPTIMIZER
# Verifica, reporta e instala todas as dependências necessárias
# =============================================================================

set -euo pipefail

readonly VERSION="1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Contadores
declare -g checks_total=0
declare -g checks_passed=0
declare -g checks_failed=0
declare -g installs_attempted=0
declare -g installs_successful=0

# =============================================================================
# FUNÇÕES DE LOG E INTERFACE
# =============================================================================

log() {
    echo -e "${BLUE}[CHECK]${NC} $*"
}

success() {
    echo -e "${GREEN}✅${NC} $*"
    ((checks_passed++))
}

fail() {
    echo -e "${RED}❌${NC} $*"
    ((checks_failed++))
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $*"
}

info() {
    echo -e "${CYAN}ℹ️${NC} $*"
}

section() {
    echo ""
    echo -e "${PURPLE}╔═══ $1 ═══╗${NC}"
}

# =============================================================================
# DETECÇÃO DO SISTEMA
# =============================================================================

detect_system() {
    local os_name="unknown"
    local os_version="unknown"
    local package_manager="unknown"
    
    # Detectar OS
    if [[ -f /etc/lsb-release ]] && grep -q "Ubuntu" /etc/lsb-release; then
        os_name="ubuntu"
        os_version=$(lsb_release -rs 2>/dev/null || echo "unknown")
        package_manager="apt"
    elif [[ -f /etc/debian_version ]]; then
        os_name="debian"
        os_version=$(cat /etc/debian_version 2>/dev/null || echo "unknown")
        package_manager="apt"
    elif [[ -f /etc/fedora-release ]]; then
        os_name="fedora"
        package_manager="dnf"
    elif [[ -f /etc/redhat-release ]]; then
        os_name="rhel"
        package_manager="yum"
    elif [[ -f /etc/arch-release ]]; then
        os_name="arch"
        package_manager="pacman"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_name="macos"
        package_manager="brew"
    fi
    
    echo "$os_name:$os_version:$package_manager"
}

# =============================================================================
# DEFINIÇÃO DE DEPENDÊNCIAS
# =============================================================================

declare -A ESSENTIAL_COMMANDS=(
    ["sudo"]="Execução com privilégios elevados"
    ["bash"]="Shell necessário para scripts"
    ["grep"]="Busca em texto"
    ["awk"]="Processamento de texto"
    ["sed"]="Edição de texto"
    ["cut"]="Manipulação de texto"
    ["sort"]="Ordenação"
    ["uniq"]="Remoção de duplicados"
    ["tr"]="Tradução de caracteres"
    ["head"]="Primeiras linhas"
    ["tail"]="Últimas linhas"
    ["wc"]="Contagem de linhas/palavras"
    ["find"]="Busca de ficheiros"
    ["xargs"]="Execução em lote"
)

declare -A SYSTEM_COMMANDS=(
    ["systemctl"]="Gestão de serviços systemd"
    ["service"]="Gestão de serviços (fallback)"
    ["ps"]="Lista de processos"
    ["top"]="Monitor de processos"
    ["free"]="Informação de memória"
    ["df"]="Uso de disco"
    ["du"]="Tamanho de diretórios"
    ["lsof"]="Ficheiros abertos"
    ["netstat"]="Estatísticas de rede"
    ["ss"]="Socket statistics (moderno)"
    ["ip"]="Configuração de rede"
    ["ping"]="Teste de conectividade"
    ["nproc"]="Número de processadores"
    ["lscpu"]="Informação da CPU"
    ["lsblk"]="Informação de blocos"
)

declare -A DEVELOPMENT_COMMANDS=(
    ["git"]="Controlo de versão"
    ["curl"]="Download de ficheiros"
    ["wget"]="Download alternativo"
    ["bc"]="Calculadora"
    ["which"]="Localização de comandos"
    ["whereis"]="Localização de binários"
    ["file"]="Tipo de ficheiro"
    ["stat"]="Estatísticas de ficheiro"
    ["chmod"]="Permissões"
    ["chown"]="Propriedade"
    ["ln"]="Links simbólicos"
    ["tar"]="Arquivos comprimidos"
    ["gzip"]="Compressão"
    ["zip"]="Compressão ZIP"
    ["unzip"]="Descompressão ZIP"
)

declare -A PACKAGE_DEPENDENCIES=(
    # Ubuntu/Debian packages
    ["ubuntu:bc"]="bc"
    ["ubuntu:curl"]="curl"
    ["ubuntu:wget"]="wget"
    ["ubuntu:git"]="git"
    ["ubuntu:systemd"]="systemd"
    ["ubuntu:coreutils"]="coreutils"
    ["ubuntu:util-linux"]="util-linux"
    ["ubuntu:procps"]="procps"
    ["ubuntu:net-tools"]="net-tools"
    ["ubuntu:iproute2"]="iproute2"
    ["ubuntu:lsb-release"]="lsb-release"
    ["ubuntu:ca-certificates"]="ca-certificates"
    
    # Debian packages (similar)
    ["debian:bc"]="bc"
    ["debian:curl"]="curl"
    ["debian:wget"]="wget"
    ["debian:git"]="git"
    ["debian:systemd"]="systemd"
    ["debian:coreutils"]="coreutils"
    ["debian:util-linux"]="util-linux"
    ["debian:procps"]="procps"
    ["debian:net-tools"]="net-tools"
    ["debian:iproute2"]="iproute2"
    ["debian:lsb-release"]="lsb-release"
    ["debian:ca-certificates"]="ca-certificates"
)

declare -A OPTIONAL_TOOLS=(
    ["htop"]="Monitor de sistema melhorado"
    ["tree"]="Visualização de árvore de diretórios"
    ["rsync"]="Sincronização de ficheiros"
    ["screen"]="Multiplexador de terminal"
    ["tmux"]="Multiplexador de terminal moderno"
    ["vim"]="Editor de texto"
    ["nano"]="Editor de texto simples"
    ["jq"]="Processador JSON"
    ["docker"]="Containerização"
    ["python3"]="Python 3"
    ["nodejs"]="Node.js"
    ["npm"]="Node Package Manager"
)

# =============================================================================
# VERIFICAÇÃO DE COMANDOS
# =============================================================================

check_command() {
    local cmd="$1"
    local description="$2"
    local required="${3:-true}"
    
    ((checks_total++))
    
    printf "   %-15s " "$cmd"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        # Verificar se funciona basicamente
        case "$cmd" in
            "systemctl")
                if systemctl --version >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Instalado${NC} - $description"
                    ((checks_passed++))
                else
                    echo -e "${YELLOW}⚠️ Instalado mas não funcional${NC}"
                    ((checks_failed++))
                fi
                ;;
            "bc")
                if echo "2+2" | bc >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Instalado${NC} - $description"
                    ((checks_passed++))
                else
                    echo -e "${YELLOW}⚠️ Instalado mas não funcional${NC}"
                    ((checks_failed++))
                fi
                ;;
            "curl")
                if curl --version >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Instalado${NC} - $description"
                    ((checks_passed++))
                else
                    echo -e "${YELLOW}⚠️ Instalado mas não funcional${NC}"
                    ((checks_failed++))
                fi
                ;;
            *)
                echo -e "${GREEN}✅ Instalado${NC} - $description"
                ((checks_passed++))
                ;;
        esac
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}❌ EM FALTA${NC} - $description"
        else
            echo -e "${BLUE}○ Opcional${NC} - $description"
        fi
        ((checks_failed++))
    fi
}

# =============================================================================
# VERIFICAÇÃO DE PACOTES
# =============================================================================

check_package() {
    local package="$1"
    local description="$2"
    local os_name="$3"
    
    printf "   %-20s " "$package"
    
    case "$os_name" in
        "ubuntu"|"debian")
            if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                echo -e "${GREEN}✅ Instalado${NC} - $description"
                return 0
            else
                echo -e "${RED}❌ EM FALTA${NC} - $description"
                return 1
            fi
            ;;
        "fedora")
            if rpm -q "$package" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Instalado${NC} - $description"
                return 0
            else
                echo -e "${RED}❌ EM FALTA${NC} - $description"
                return 1
            fi
            ;;
        *)
            echo -e "${YELLOW}⚠️ Sistema não suportado${NC}"
            return 1
            ;;
    esac
}

# =============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS
# =============================================================================

install_packages() {
    local os_name="$1"
    local package_manager="$2"
    shift 2
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        info "Nenhum pacote para instalar"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}📦 PACOTES A INSTALAR:${NC}"
    for pkg in "${packages[@]}"; do
        echo "   • $pkg"
    done
    echo ""
    
    read -p "$(echo -e "${CYAN}Instalar estes pacotes? (y/N):${NC} ")" install_confirm
    
    if [[ ! "$install_confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        warning "Instalação cancelada pelo utilizador"
        return 0
    fi
    
    echo ""
    log "Instalando pacotes..."
    
    case "$package_manager" in
        "apt")
            # Atualizar cache
            log "Atualizando cache de pacotes..."
            if sudo apt update -qq; then
                success "Cache atualizado"
            else
                fail "Falha ao atualizar cache"
                return 1
            fi
            
            # Instalar pacotes
            for package in "${packages[@]}"; do
                ((installs_attempted++))
                log "Instalando: $package"
                
                if sudo apt install -y "$package" >/dev/null 2>&1; then
                    success "Instalado: $package"
                    ((installs_successful++))
                else
                    fail "Falha ao instalar: $package"
                fi
            done
            ;;
        "dnf")
            for package in "${packages[@]}"; do
                ((installs_attempted++))
                log "Instalando: $package"
                
                if sudo dnf install -y "$package" >/dev/null 2>&1; then
                    success "Instalado: $package"
                    ((installs_successful++))
                else
                    fail "Falha ao instalar: $package"
                fi
            done
            ;;
        "yum")
            for package in "${packages[@]}"; do
                ((installs_attempted++))
                log "Instalando: $package"
                
                if sudo yum install -y "$package" >/dev/null 2>&1; then
                    success "Instalado: $package"
                    ((installs_successful++))
                else
                    fail "Falha ao instalar: $package"
                fi
            done
            ;;
        "brew")
            for package in "${packages[@]}"; do
                ((installs_attempted++))
                log "Instalando: $package"
                
                if brew install "$package" >/dev/null 2>&1; then
                    success "Instalado: $package"
                    ((installs_successful++))
                else
                    fail "Falha ao instalar: $package"
                fi
            done
            ;;
        *)
            fail "Gestor de pacotes não suportado: $package_manager"
            return 1
            ;;
    esac
}

# =============================================================================
# VERIFICAÇÕES ESPECÍFICAS DO SISTEMA
# =============================================================================

check_system_specifics() {
    local os_name="$1"
    
    section "VERIFICAÇÕES ESPECÍFICAS DO SISTEMA"
    
    # Verificar se não é root
    if [[ $EUID -eq 0 ]]; then
        fail "Executando como root (deve ser utilizador normal)"
        echo "      Execute como utilizador normal, não como root"
    else
        success "Utilizador normal: $USER"
    fi
    
    # Verificar sudo
    printf "   %-15s " "sudo"
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✅ Configurado${NC} - Cache ativo"
    elif sudo -v 2>/dev/null; then
        echo -e "${GREEN}✅ Configurado${NC} - Funcional"
    else
        echo -e "${RED}❌ Não configurado${NC} - Necessário para instalações"
    fi
    
    # Verificar espaço em disco
    local free_space=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    printf "   %-15s " "espaço livre"
    if (( $(echo "$free_space > 2.0" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}✅ Suficiente${NC} - ${free_space}GB disponíveis"
    else
        echo -e "${RED}❌ Insuficiente${NC} - ${free_space}GB (mínimo: 2GB)"
    fi
    
    # Verificar conectividade
    printf "   %-15s " "internet"
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Conectado${NC} - Para downloads de pacotes"
    else
        echo -e "${RED}❌ Offline${NC} - Necessário para instalações"
    fi
    
    # Verificar systemd (se Linux)
    if [[ "$os_name" != "macos" ]]; then
        printf "   %-15s " "systemd"
        if systemctl --version >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Ativo${NC} - Gestão de serviços"
        else
            echo -e "${YELLOW}⚠️ Não disponível${NC} - Algumas funcionalidades limitadas"
        fi
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    clear
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🔍 VERIFICADOR DE DEPENDÊNCIAS v$VERSION                 ║
║                           LAPTOP OPTIMIZER                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    log "Analisando sistema e dependências..."
    
    # Detectar sistema
    local system_info
    system_info=$(detect_system)
    local os_name=$(echo "$system_info" | cut -d: -f1)
    local os_version=$(echo "$system_info" | cut -d: -f2)
    local package_manager=$(echo "$system_info" | cut -d: -f3)
    
    echo ""
    info "Sistema detectado: $os_name $os_version"
    info "Gestor de pacotes: $package_manager"
    
    # === VERIFICAÇÕES ESPECÍFICAS DO SISTEMA ===
    check_system_specifics "$os_name"
    
    # === COMANDOS ESSENCIAIS ===
    section "COMANDOS ESSENCIAIS"
    for cmd in "${!ESSENTIAL_COMMANDS[@]}"; do
        check_command "$cmd" "${ESSENTIAL_COMMANDS[$cmd]}" "true"
    done
    
    # === COMANDOS DO SISTEMA ===
    section "COMANDOS DO SISTEMA"
    for cmd in "${!SYSTEM_COMMANDS[@]}"; do
        check_command "$cmd" "${SYSTEM_COMMANDS[$cmd]}" "true"
    done
    
    # === COMANDOS DE DESENVOLVIMENTO ===
    section "COMANDOS DE DESENVOLVIMENTO"
    for cmd in "${!DEVELOPMENT_COMMANDS[@]}"; do
        check_command "$cmd" "${DEVELOPMENT_COMMANDS[$cmd]}" "true"
    done
    
    # === FERRAMENTAS OPCIONAIS ===
    section "FERRAMENTAS OPCIONAIS"
    for cmd in "${!OPTIONAL_TOOLS[@]}"; do
        check_command "$cmd" "${OPTIONAL_TOOLS[$cmd]}" "false"
    done
    
    # === VERIFICAR PACOTES SE UBUNTU/DEBIAN ===
    if [[ "$os_name" == "ubuntu" || "$os_name" == "debian" ]]; then
        section "PACOTES DO SISTEMA"
        
        local missing_packages=()
        local essential_packages=("bc" "curl" "wget" "git" "lsb-release" "ca-certificates")
        
        for pkg in "${essential_packages[@]}"; do
            if ! check_package "$pkg" "Pacote essencial" "$os_name"; then
                missing_packages+=("$pkg")
            fi
        done
        
        # Oferecer instalação de pacotes em falta
        if [[ ${#missing_packages[@]} -gt 0 ]]; then
            echo ""
            warning "Pacotes essenciais em falta: ${missing_packages[*]}"
            install_packages "$os_name" "$package_manager" "${missing_packages[@]}"
        fi
    fi
    
    # === RELATÓRIO FINAL ===
    echo ""
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                              📊 RELATÓRIO FINAL                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    echo -e "${GREEN}✅ Verificações passou: $checks_passed${NC}"
    echo -e "${RED}❌ Verificações falharam: $checks_failed${NC}"
    echo -e "${BLUE}📋 Total verificado: $checks_total${NC}"
    
    if [[ $installs_attempted -gt 0 ]]; then
        echo ""
        echo -e "${PURPLE}📦 INSTALAÇÕES:${NC}"
        echo -e "${GREEN}✅ Instalações bem-sucedidas: $installs_successful${NC}"
        echo -e "${RED}❌ Instalações falharam: $((installs_attempted - installs_successful))${NC}"
        echo -e "${BLUE}📋 Total tentativas: $installs_attempted${NC}"
    fi
    
    echo ""
    local success_rate=$((checks_passed * 100 / checks_total))
    
    if [[ $checks_failed -eq 0 ]]; then
        echo -e "${GREEN}🎉 SISTEMA COMPLETAMENTE PREPARADO!${NC}"
        echo -e "${GREEN}   Todas as dependências estão presentes e funcionais.${NC}"
        echo ""
        echo -e "${BLUE}💡 PRÓXIMO PASSO:${NC}"
        echo "   ./optimize-laptop.sh"
    elif [[ $success_rate -ge 90 ]]; then
        echo -e "${YELLOW}⚠️ SISTEMA QUASE PRONTO ($success_rate%)${NC}"
        echo -e "${YELLOW}   A maioria das dependências está presente.${NC}"
        echo ""
        echo -e "${BLUE}💡 RECOMENDAÇÃO:${NC}"
        echo "   Continuar com ./optimize-laptop.sh"
        echo "   Algumas funcionalidades podem estar limitadas"
    elif [[ $success_rate -ge 70 ]]; then
        echo -e "${YELLOW}⚠️ SISTEMA PARCIALMENTE PRONTO ($success_rate%)${NC}"
        echo -e "${YELLOW}   Algumas dependências importantes estão em falta.${NC}"
        echo ""
        echo -e "${BLUE}💡 RECOMENDAÇÃO:${NC}"
        echo "   Instalar dependências em falta antes de continuar"
        echo "   Executar novamente: ./check-dependencies.sh"
    else
        echo -e "${RED}❌ SISTEMA NÃO ESTÁ PRONTO ($success_rate%)${NC}"
        echo -e "${RED}   Muitas dependências essenciais estão em falta.${NC}"
        echo ""
        echo -e "${BLUE}💡 AÇÃO NECESSÁRIA:${NC}"
        echo "   Instalar dependências básicas do sistema:"
        
        if [[ "$package_manager" == "apt" ]]; then
            echo "   sudo apt update && sudo apt install bc curl wget git lsb-release build-essential"
        elif [[ "$package_manager" == "dnf" ]]; then
            echo "   sudo dnf install bc curl wget git redhat-lsb-core"
        elif [[ "$package_manager" == "yum" ]]; then
            echo "   sudo yum install bc curl wget git redhat-lsb-core"
        fi
        
        echo "   Depois executar novamente: ./check-dependencies.sh"
    fi
    
    echo ""
    echo -e "${CYAN}📋 COMANDOS ÚTEIS:${NC}"
    echo "   ./check-dependencies.sh    - Executar novamente esta verificação"
    echo "   ./optimize-laptop.sh       - Executar otimizador (se pronto)"
    echo "   ./optimize-laptop.sh --help - Ver ajuda do otimizador"
    echo ""
}

# Verificar argumentos
case "${1:-}" in
    "--version"|"-v")
        echo "Verificador de Dependências v$VERSION"
        exit 0
        ;;
    "--help"|"-h")
        echo "Verificador de Dependências v$VERSION"
        echo ""
        echo "Uso: ./check-dependencies.sh [opção]"
        echo ""
        echo "Opções:"
        echo "  --version, -v    Mostrar versão"
        echo "  --help, -h       Mostrar esta ajuda"
        echo ""
        echo "Este script verifica e instala todas as dependências"
        echo "necessárias para executar o Laptop Optimizer."
        echo ""
        exit 0
        ;;
esac

# Executar função principal
main "$@"