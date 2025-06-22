#!/bin/bash
# =============================================================================
# VERIFICAÇÃO RÁPIDA DE DEPENDÊNCIAS - LAPTOP OPTIMIZER
# Verificação básica e rápida antes de executar o otimizador
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

check_ready=true

quick_check() {
    local cmd="$1"
    local name="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅${NC} $name"
    else
        echo -e "   ${RED}❌${NC} $name (comando: $cmd)"
        check_ready=false
    fi
}

echo -e "${BLUE}🔍 VERIFICAÇÃO RÁPIDA DE DEPENDÊNCIAS${NC}"
echo "============================================"
echo ""

# Comandos essenciais
echo -e "${BLUE}Comandos essenciais:${NC}"
quick_check "sudo" "Sudo"
quick_check "systemctl" "SystemD"
quick_check "bc" "Calculadora BC"
quick_check "curl" "cURL"
quick_check "git" "Git"

echo ""

# Sistema
echo -e "${BLUE}Sistema:${NC}"

# Verificar se não é root
if [[ $EUID -eq 0 ]]; then
    echo -e "   ${RED}❌${NC} Utilizador (não deve ser root)"
    check_ready=false
else
    echo -e "   ${GREEN}✅${NC} Utilizador ($USER)"
fi

# Verificar sudo
if sudo -n true 2>/dev/null || sudo -v 2>/dev/null; then
    echo -e "   ${GREEN}✅${NC} Sudo configurado"
else
    echo -e "   ${RED}❌${NC} Sudo não configurado"
    check_ready=false
fi

# Verificar espaço (corrigido - sem 'local' fora de função)
free_space=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
if command -v bc >/dev/null 2>&1 && (( $(echo "$free_space > 2.0" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "   ${GREEN}✅${NC} Espaço livre (${free_space}GB)"
else
    echo -e "   ${RED}❌${NC} Pouco espaço (${free_space}GB)"
    check_ready=false
fi

echo ""

# Resultado
if [[ "$check_ready" == true ]]; then
    echo -e "${GREEN}🎉 SISTEMA PRONTO!${NC}"
    echo ""
    echo -e "${BLUE}Próximos passos:${NC}"
    echo "   ./optimize-laptop.sh          - Executar otimizador"
    echo "   ./check-dependencies.sh       - Verificação completa"
else
    echo -e "${RED}❌ SISTEMA NÃO ESTÁ PRONTO${NC}"
    echo ""
    echo -e "${YELLOW}Soluções rápidas:${NC}"
    echo "   sudo apt update && sudo apt install bc curl git"
    echo "   ./check-dependencies.sh       - Verificação e instalação completa"
fi

echo ""