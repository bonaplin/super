#!/bin/bash
# =============================================================================
# BIBLIOTECA DE CORES E FORMATAÇÃO
# =============================================================================

# Proteção contra múltiplas inclusões
[[ -n "${_COLORS_SH_LOADED:-}" ]] && return 0
_COLORS_SH_LOADED=1

# Verificar se terminal suporta cores
if [[ -t 1 ]] && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    # Cores básicas (sem readonly para evitar conflitos)
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0m' # No Color

    # Cores com fundo
    BG_RED='\033[41m'
    BG_GREEN='\033[42m'
    BG_YELLOW='\033[43m'
    BG_BLUE='\033[44m'

    # Formatação
    BOLD='\033[1m'
    DIM='\033[2m'
    UNDERLINE='\033[4m'
    BLINK='\033[5m'
    REVERSE='\033[7m'

    # Cores específicas para logs
    COLOR_INFO="$BLUE"
    COLOR_SUCCESS="$GREEN"
    COLOR_WARNING="$YELLOW"
    COLOR_ERROR="$RED"
    COLOR_HEADER="$CYAN"
    COLOR_EMPHASIS="$PURPLE"
else
    # Terminal sem suporte a cores - usar variáveis vazias
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    NC=''
    BG_RED=''
    BG_GREEN=''
    BG_YELLOW=''
    BG_BLUE=''
    BOLD=''
    DIM=''
    UNDERLINE=''
    BLINK=''
    REVERSE=''
    COLOR_INFO=''
    COLOR_SUCCESS=''
    COLOR_WARNING=''
    COLOR_ERROR=''
    COLOR_HEADER=''
    COLOR_EMPHASIS=''
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
    SYMBOL_SUCCESS="✅"
    SYMBOL_ERROR="❌"
    SYMBOL_WARNING="⚠️"
    SYMBOL_INFO="ℹ️"
    SYMBOL_QUESTION="❓"
    SYMBOL_ARROW="➜"
    SYMBOL_BULLET="•"

    # Símbolos funcionais
    SYMBOL_CHECK="✓"
    SYMBOL_CROSS="✗"
    SYMBOL_STAR="⭐"
    SYMBOL_FIRE="🔥"
    SYMBOL_ROCKET="🚀"
    SYMBOL_GEAR="⚙️"
    SYMBOL_WRENCH="🔧"
    SYMBOL_COMPUTER="💻"
    SYMBOL_SHIELD="🛡️"
    SYMBOL_CLEAN="🧹"

    # Símbolos de progresso
    SYMBOL_LOADING="⏳"
    SYMBOL_DONE="✨"
    SYMBOL_BUILDING="🏗️"
    SYMBOL_TESTING="🧪"

    # Símbolos de categoria
    SYMBOL_SYSTEM="🖥️"
    SYMBOL_NETWORK="📶"
    SYMBOL_STORAGE="💾"
    SYMBOL_SECURITY="🔒"
    SYMBOL_PERFORMANCE="⚡"
    SYMBOL_DEVELOPMENT="🛠️"
    SYMBOL_ENTERPRISE="🏢"
    SYMBOL_COMMUNITY="🌍"
else
    # Terminal sem UTF-8 - usar ASCII
    SYMBOL_SUCCESS="[OK]"
    SYMBOL_ERROR="[ERR]"
    SYMBOL_WARNING="[WARN]"
    SYMBOL_INFO="[INFO]"
    SYMBOL_QUESTION="[?]"
    SYMBOL_ARROW="->"
    SYMBOL_BULLET="*"
    SYMBOL_CHECK="+"
    SYMBOL_CROSS="x"
    SYMBOL_STAR="*"
    SYMBOL_FIRE="!"
    SYMBOL_ROCKET="^"
    SYMBOL_GEAR="o"
    SYMBOL_WRENCH="+"
    SYMBOL_COMPUTER="PC"
    SYMBOL_SHIELD="[S]"
    SYMBOL_CLEAN="~"
    SYMBOL_LOADING="..."
    SYMBOL_DONE="!"
    SYMBOL_BUILDING="..."
    SYMBOL_TESTING="?"
    SYMBOL_SYSTEM="SYS"
    SYMBOL_NETWORK="NET"
    SYMBOL_STORAGE="DSK"
    SYMBOL_SECURITY="SEC"
    SYMBOL_PERFORMANCE="PWR"
    SYMBOL_DEVELOPMENT="DEV"
    SYMBOL_ENTERPRISE="ENT"
    SYMBOL_COMMUNITY="COM"
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