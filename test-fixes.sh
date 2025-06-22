#!/bin/bash
# =============================================================================
# SCRIPT DE TESTE DAS CORREÇÕES
# Verifica se os problemas identificados foram corrigidos
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

test_passed=0
test_failed=0

test_result() {
    local test_name="$1"
    local result="$2"
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "   ${GREEN}✅ PASS${NC} - $test_name"
        ((test_passed++))
    else
        echo -e "   ${RED}❌ FAIL${NC} - $test_name"
        ((test_failed++))
    fi
}

echo -e "${BLUE}🧪 TESTE DAS CORREÇÕES APLICADAS${NC}"
echo "=================================="
echo ""

# Teste 1: Verificar se quick-check.sh executa sem erro
echo -e "${BLUE}Teste 1: quick-check.sh${NC}"
if ./quick-check.sh >/dev/null 2>&1; then
    test_result "quick-check.sh executa sem erro" "PASS"
else
    test_result "quick-check.sh tem erros" "FAIL"
fi

# Teste 2: Verificar se optimize-laptop.sh --help funciona
echo -e "${BLUE}Teste 2: optimize-laptop.sh --help${NC}"
if ./optimize-laptop.sh --help >/dev/null 2>&1; then
    test_result "optimize-laptop.sh --help funciona" "PASS"
else
    test_result "optimize-laptop.sh --help falha" "FAIL"
fi

# Teste 3: Verificar se colors.sh carrega sem erro
echo -e "${BLUE}Teste 3: lib/colors.sh${NC}"
if source lib/colors.sh 2>/dev/null; then
    test_result "lib/colors.sh carrega sem erro" "PASS"
else
    test_result "lib/colors.sh tem erros" "FAIL"
fi

# Teste 4: Verificar se common.sh carrega sem erro
echo -e "${BLUE}Teste 4: lib/common.sh${NC}"
if source lib/common.sh 2>/dev/null; then
    test_result "lib/common.sh carrega sem erro" "PASS"
else
    test_result "lib/common.sh tem erros" "FAIL"
fi

# Teste 5: Verificar sintaxe dos scripts principais
echo -e "${BLUE}Teste 5: Verificação de sintaxe${NC}"
syntax_ok=true

for script in optimize-laptop.sh quick-check.sh setup.sh check-dependencies.sh; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "   ${GREEN}✓${NC} $script - sintaxe OK"
        else
            echo -e "   ${RED}✗${NC} $script - erro de sintaxe"
            syntax_ok=false
        fi
    else
        echo -e "   ${YELLOW}?${NC} $script - ficheiro não encontrado"
    fi
done

if [[ "$syntax_ok" == true ]]; then
    test_result "Sintaxe de todos os scripts" "PASS"
else
    test_result "Sintaxe com erros" "FAIL"
fi

# Teste 6: Verificar se setup.sh não procura ficheiros inexistentes
echo -e "${BLUE}Teste 6: setup.sh sem ficheiros inexistentes${NC}"
if ! grep -q "laptop-optimizer-main.sh" setup.sh 2>/dev/null; then
    test_result "setup.sh não procura laptop-optimizer-main.sh" "PASS"
else
    test_result "setup.sh ainda procura ficheiro inexistente" "FAIL"
fi

# Teste 7: Verificar se optimize-laptop.sh carrega bibliotecas corretamente
echo -e "${BLUE}Teste 7: Carregamento de bibliotecas${NC}"
if bash -c 'source lib/colors.sh && source lib/common.sh && echo "OK"' >/dev/null 2>&1; then
    test_result "Bibliotecas carregam sem conflito" "PASS"
else
    test_result "Conflito no carregamento de bibliotecas" "FAIL"
fi

# Teste 8: Verificar permissões
echo -e "${BLUE}Teste 8: Permissões de execução${NC}"
executables=("optimize-laptop.sh" "quick-check.sh" "setup.sh" "check-dependencies.sh")
perms_ok=true

for script in "${executables[@]}"; do
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            echo -e "   ${GREEN}✓${NC} $script - executável"
        else
            echo -e "   ${RED}✗${NC} $script - não executável"
            perms_ok=false
        fi
    fi
done

if [[ "$perms_ok" == true ]]; then
    test_result "Permissões de execução corretas" "PASS"
else
    test_result "Permissões em falta" "FAIL"
fi

# Relatório final
echo ""
echo -e "${BLUE}📊 RELATÓRIO FINAL:${NC}"
echo "=================="
echo -e "${GREEN}✅ Testes passou: $test_passed${NC}"
echo -e "${RED}❌ Testes falharam: $test_failed${NC}"
echo ""

if [[ $test_failed -eq 0 ]]; then
    echo -e "${GREEN}🎉 TODAS AS CORREÇÕES FUNCIONAM!${NC}"
    echo ""
    echo -e "${BLUE}💡 Próximos passos:${NC}"
    echo "   1. ./quick-check.sh           # Verificação rápida"
    echo "   2. ./optimize-laptop.sh       # Executar optimizer"
    echo "   3. ./setup.sh                 # Instalação global (opcional)"
elif [[ $test_failed -le 2 ]]; then
    echo -e "${YELLOW}⚠️ Maioria das correções funciona (apenas $test_failed problemas)${NC}"
    echo ""
    echo -e "${BLUE}💡 Recomendação:${NC}"
    echo "   Prosseguir com testes mais detalhados"
else
    echo -e "${RED}❌ Várias correções ainda têm problemas${NC}"
    echo ""
    echo -e "${BLUE}💡 Ação necessária:${NC}"
    echo "   Verificar logs e aplicar correções adicionais"
fi

echo ""
echo -e "${CYAN}📋 Para debug detalhado:${NC}"
echo "   bash -x ./optimize-laptop.sh --help"
echo "   bash -x ./quick-check.sh"
echo ""

exit $test_failed