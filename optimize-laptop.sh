#!/bin/bash
# =============================================================================
# LAPTOP OPTIMIZER - SCRIPT PRINCIPAL 
# Ponto de entrada único para o sistema
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="4.0-modular"

# Verificar se está na estrutura correta
if [[ ! -f "$SCRIPT_DIR/lib/colors.sh" ]]; then
    echo "❌ Erro: Estrutura de ficheiros incorreta!"
    echo "   Execute o script organize.sh primeiro"
    exit 1
fi

# Verificar argumentos especiais
case "${1:-}" in
    "--version"|"-v")
        echo "Laptop Optimizer v$VERSION"
        exit 0
        ;;
    "--help"|"-h")
        echo "Laptop Optimizer v$VERSION - Sistema modular de otimização"
        echo ""
        echo "Uso: ./optimize-laptop.sh [opção]"
        echo ""
        echo "Opções:"
        echo "  --version, -v    Mostrar versão"
        echo "  --help, -h       Mostrar esta ajuda"
        echo ""
        echo "📁 Estrutura:"
        echo "  lib/             Bibliotecas comuns"
        echo "  modules/         Módulos funcionais"
        echo "  config/          Configurações"
        echo "  tests/           Testes e benchmarks"
        echo ""
        exit 0
        ;;
esac

# Carregar e executar o script principal modular
exec "$SCRIPT_DIR/laptop-optimizer-main.sh" "$@"
