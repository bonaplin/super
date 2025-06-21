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
    echo "   Execute a partir do diretório do projeto"
    echo "   Ou use: ./setup.sh para instalar corretamente"
    exit 1
fi

# Carregar e executar o script principal modular
exec "$SCRIPT_DIR/main_optimizer_script.sh" "$@"