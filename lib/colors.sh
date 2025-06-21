#!/bin/bash
# =============================================================================
# BIBLIOTECA DE CORES E FORMATAÇÃO
# =============================================================================

# Verificar se terminal suporta cores
if [[ -t 1 ]] && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    # Cores básicas
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly NC='\033[0m' # No Color
    
    # Cores com fundo
    readonly BG_RED='\033[41m'
    readonly BG_GREEN='\033[42m'
    readonly BG_YELLOW='\033[43m'
    readonly BG_BLUE='\033[44m'
    
    # Formatação
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly UNDERLINE='\033[4m'
    readonly BLINK='\033[5m'
    readonly REVERSE='\033[7m'
    
    # Cores específicas para logs
    readonly COLOR_INFO="$BLUE"
    readonly COLOR_SUCCESS="$GREEN"
    readonly COLOR_WARNING="$YELLOW"
    readonly COLOR_ERROR="$RED"
    readonly COLOR_HEADER="$CYAN"
    readonly COLOR_EMPHASIS="$PURPLE"
else
    # Terminal sem suporte a cores - usar variáveis vazias
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly PURPLE=''
    readonly CYAN=''
    readonly WHITE=''
    readonly NC=''
    readonly BG_RED=''
    readonly BG_GREEN=''
    readonly BG_YELLOW=''
    readonly BG_BLUE=''
    readonly BOLD=''
    readonly DIM=''
    readonly UNDERLINE=''
    readonly BLINK=''
    readonly REVERSE=''
    readonly COLOR_INFO=''
    readonly COLOR_SUCCESS=''
    readonly COLOR_WARNING=''
    readonly COLOR_ERROR=''
    readonly COLOR_HEADER=''
    readonly COLOR_EMPHASIS=''
fi

# =============================================================================
# FUNÇÕES DE FORMATAÇÃO
# =============================================================================

# Funções para aplicar cores facilmente
colorize() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${NC}"
}

red() {
    colorize "$RED" "$*"
}

green() {
    colorize "$GREEN" "$*"
}

yellow() {
    colorize "$YELLOW" "$*"
}

blue() {
    colorize "$BLUE" "$*"
}

purple() {
    colorize "$PURPLE" "$*"
}

cyan() {
    colorize "$CYAN" "$*"
}

white() {
    colorize "$WHITE" "$*"
}

bold() {
    colorize "$BOLD" "$*"
}

# =============================================================================
# SÍMBOLOS E ÍCONES UNICODE
# =============================================================================

# Verificar se terminal suporta UTF-8
if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]]; then
    # Símbolos de status
    readonly SYMBOL_SUCCESS="✅"
    readonly SYMBOL_ERROR="❌"
    readonly SYMBOL_WARNING="⚠️"
    readonly SYMBOL_INFO="ℹ️"
    readonly SYMBOL_QUESTION="❓"
    readonly SYMBOL_ARROW="➜"
    readonly SYMBOL_BULLET="•"
    
    # Símbolos funcionais
    readonly SYMBOL_CHECK="✓"
    readonly SYMBOL_CROSS="✗"
    readonly SYMBOL_STAR="⭐"
    readonly SYMBOL_FIRE="🔥"
    readonly SYMBOL_ROCKET="🚀"
    readonly SYMBOL_GEAR="⚙️"
    readonly SYMBOL_WRENCH="🔧"
    readonly SYMBOL_COMPUTER="💻"
    readonly SYMBOL_SHIELD="🛡️"
    readonly SYMBOL_CLEAN="🧹"
    
    # Símbolos de progresso
    readonly SYMBOL_LOADING="⏳"
    readonly SYMBOL_DONE="✨"
    readonly SYMBOL_BUILDING="🏗️"
    readonly SYMBOL_TESTING="🧪"
    
    # Símbolos de categoria
    readonly SYMBOL_SYSTEM="🖥️"
    readonly SYMBOL_NETWORK="📶"
    readonly SYMBOL_STORAGE="💾"
    readonly SYMBOL_SECURITY="🔒"
    readonly SYMBOL_PERFORMANCE="⚡"
    readonly SYMBOL_DEVELOPMENT="🛠️"
    readonly SYMBOL_ENTERPRISE="🏢"
    readonly SYMBOL_COMMUNITY="🌍"
else
    # Terminal sem UTF-8 - usar ASCII
    readonly SYMBOL_SUCCESS="[OK]"
    readonly SYMBOL_ERROR="[ERR]"
    readonly SYMBOL_WARNING="[WARN]"
    readonly SYMBOL_INFO="[INFO]"
    readonly SYMBOL_QUESTION="[?]"
    readonly SYMBOL_ARROW="->"
    readonly SYMBOL_BULLET="*"
    readonly SYMBOL_CHECK="+"
    readonly SYMBOL_CROSS="x"
    readonly SYMBOL_STAR="*"
    readonly SYMBOL_FIRE="!"
    readonly SYMBOL_ROCKET="^"
    readonly SYMBOL_GEAR="o"
    readonly SYMBOL_WRENCH="+"
    readonly SYMBOL_COMPUTER="PC"
    readonly SYMBOL_SHIELD="[S]"
    readonly SYMBOL_CLEAN="~"
    readonly SYMBOL_LOADING="..."
    readonly SYMBOL_DONE="!"
    readonly SYMBOL_BUILDING="..."
    readonly SYMBOL_TESTING="?"
    readonly SYMBOL_SYSTEM="SYS"
    readonly SYMBOL_NETWORK="NET"
    readonly SYMBOL_STORAGE="DSK"
    readonly SYMBOL_SECURITY="SEC"
    readonly SYMBOL_PERFORMANCE="PWR"
    readonly SYMBOL_DEVELOPMENT="DEV"
    readonly SYMBOL_ENTERPRISE="ENT"
    readonly SYMBOL_COMMUNITY="COM"
fi

# =============================================================================
# FUNÇÕES DE FORMATAÇÃO AVANÇADA
# =============================================================================

# Caixa simples
draw_box() {
    local text="$1"
    local width="${2:-60}"
    local padding=$(( (width - ${#text} - 2) / 2 ))
    
    echo "┌$(printf '─%.0s' $(seq 1 $width))┐"
    printf "│%*s%s%*s│\n" $padding "" "$text" $padding ""
    echo "└$(printf '─%.0s' $(seq 1 $width))┘"
}

# Header com linha
print_header() {
    local text="$1"
    local char="${2:-=}"
    local width="${3:-60}"
    
    echo -e "${CYAN}${text}${NC}"
    printf "${char}%.0s" $(seq 1 $width)
    echo ""
}

# Separador
print_separator() {
    local char="${1:--}"
    local width="${2:-60}"
    printf "${char}%.0s" $(seq 1 $width)
    echo ""
}

# Progress bar simples
show_progress() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}Progress: [${GREEN}"
    printf "█%.0s" $(seq 1 $filled)
    printf "${NC}"
    printf " %.0s" $(seq 1 $empty)
    printf "${BLUE}] ${percentage}%%${NC}"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Spinner simples
spinner() {
    local pid=$1
    local delay=0.1
    local spinchars='|/-\'
    
    while kill -0 $pid 2>/dev/null; do
        for char in $(echo $spinchars | fold -w1); do
            printf "\r${BLUE}%c${NC} A processar..." "$char"
            sleep $delay
        done
    done
    printf "\r${GREEN}${SYMBOL_SUCCESS}${NC} Concluído!    \n"
}

# =============================================================================
# TEMPLATES DE MENSAGENS
# =============================================================================

# Status messages com ícones
status_message() {
    local type="$1"
    local message="$2"
    
    case "$type" in
        "success")  echo -e "${GREEN}${SYMBOL_SUCCESS}${NC} $message" ;;
        "error")    echo -e "${RED}${SYMBOL_ERROR}${NC} $message" ;;
        "warning")  echo -e "${YELLOW}${SYMBOL_WARNING}${NC} $message" ;;
        "info")     echo -e "${BLUE}${SYMBOL_INFO}${NC} $message" ;;
        "question") echo -e "${YELLOW}${SYMBOL_QUESTION}${NC} $message" ;;
        *)          echo -e "${SYMBOL_BULLET} $message" ;;
    esac
}

# Seção com cabeçalho
section_header() {
    local title="$1"
    local icon="${2:-$SYMBOL_GEAR}"
    
    echo ""
    echo -e "${CYAN}${icon} ${title}${NC}"
    echo -e "${CYAN}$(printf '─%.0s' $(seq 1 $((${#title} + 3))))${NC}"
}

# Lista com bullets
bullet_list() {
    while [[ $# -gt 0 ]]; do
        echo -e "   ${BLUE}${SYMBOL_BULLET}${NC} $1"
        shift
    done
}

# Nota destacada
highlight_note() {
    local message="$1"
    echo ""
    echo -e "${YELLOW}${BG_YELLOW}${NC} ${BOLD}NOTA:${NC} $message"
    echo ""
}

# Aviso importante
important_warning() {
    local message="$1"
    echo ""
    echo -e "${RED}${SYMBOL_WARNING} ${BOLD}IMPORTANTE:${NC} $message"
    echo ""
}

# =============================================================================
# FUNÇÕES DE DEBUG
# =============================================================================

# Mostrar todas as cores (para teste)
show_color_test() {
    echo "Teste de cores:"
    echo -e "${RED}Vermelho${NC} | ${GREEN}Verde${NC} | ${YELLOW}Amarelo${NC} | ${BLUE}Azul${NC}"
    echo -e "${PURPLE}Roxo${NC} | ${CYAN}Ciano${NC} | ${WHITE}Branco${NC}"
    echo ""
    echo "Formatação:"
    echo -e "${BOLD}Negrito${NC} | ${DIM}Escurecido${NC} | ${UNDERLINE}Sublinhado${NC}"
    echo ""
    echo "Símbolos:"
    echo -e "${SYMBOL_SUCCESS} Sucesso | ${SYMBOL_ERROR} Erro | ${SYMBOL_WARNING} Aviso | ${SYMBOL_INFO} Info"
    echo ""
}

# Verificar suporte a cores
check_color_support() {
    if [[ -t 1 ]]; then
        local colors=$(tput colors 2>/dev/null || echo 0)
        echo "Terminal: suporta $colors cores"
        [[ $colors -ge 8 ]] && echo "✓ Cores básicas suportadas" || echo "✗ Cores não suportadas"
        [[ $colors -ge 256 ]] && echo "✓ Cores estendidas suportadas" || echo "○ Apenas cores básicas"
    else
        echo "✗ Terminal não interativo - sem cores"
    fi
}