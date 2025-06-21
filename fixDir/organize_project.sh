#!/bin/bash
# =============================================================================
# ORGANIZADOR AUTOMÁTICO DO LAPTOP OPTIMIZER
# Cria estrutura correta e move ficheiros para locais adequados
# =============================================================================

set -euo pipefail

echo "🚀 ORGANIZANDO PROJETO LAPTOP OPTIMIZER"
echo "======================================="
echo ""

# Verificar se estamos no diretório correto
if [[ ! -f "main_optimizer_script.sh" ]]; then
    echo "❌ Erro: main_optimizer_script.sh não encontrado!"
    echo "   Execute este script no diretório onde estão todos os ficheiros"
    exit 1
fi

echo "✅ Ficheiros encontrados no diretório atual"
echo ""

# =============================================================================
# CRIAR ESTRUTURA DE DIRETÓRIOS
# =============================================================================

echo "📁 Criando estrutura de diretórios..."

mkdir -p lib
mkdir -p modules  
mkdir -p config
mkdir -p tests
mkdir -p tools

echo "   ✅ Diretórios criados: lib/ modules/ config/ tests/ tools/"
echo ""

# =============================================================================
# MOVER BIBLIOTECAS
# =============================================================================

echo "📚 Organizando bibliotecas..."

# Bibliotecas principais
[[ -f "colors_lib.sh" ]] && mv "colors_lib.sh" "lib/colors.sh" && echo "   ✅ colors_lib.sh → lib/colors.sh"
[[ -f "common_lib.sh" ]] && mv "common_lib.sh" "lib/common.sh" && echo "   ✅ common_lib.sh → lib/common.sh"
[[ -f "validation_lib.sh" ]] && mv "validation_lib.sh" "lib/validation.sh" && echo "   ✅ validation_lib.sh → lib/validation.sh"
[[ -f "backup_lib.sh" ]] && mv "backup_lib.sh" "lib/backup.sh" && echo "   ✅ backup_lib.sh → lib/backup.sh"

echo ""

# =============================================================================
# MOVER MÓDULOS
# =============================================================================

echo "🔧 Organizando módulos..."

[[ -f "enterprise_conflicts_module.sh" ]] && mv "enterprise_conflicts_module.sh" "modules/enterprise-conflicts.sh" && echo "   ✅ enterprise_conflicts_module.sh → modules/enterprise-conflicts.sh"
[[ -f "development_config_module.sh" ]] && mv "development_config_module.sh" "modules/development-config.sh" && echo "   ✅ development_config_module.sh → modules/development-config.sh"
[[ -f "smart_maintenance_module.sh" ]] && mv "smart_maintenance_module.sh" "modules/smart-maintenance.sh" && echo "   ✅ smart_maintenance_module.sh → modules/smart-maintenance.sh"
[[ -f "utility_scripts_module.sh" ]] && mv "utility_scripts_module.sh" "modules/utility-scripts.sh" && echo "   ✅ utility_scripts_module.sh → modules/utility-scripts.sh"
[[ -f "docker_cleanup_module.sh" ]] && mv "docker_cleanup_module.sh" "modules/docker-cleanup.sh" && echo "   ✅ docker_cleanup_module.sh → modules/docker-cleanup.sh"
[[ -f "essential_tweaks_module.sh" ]] && mv "essential_tweaks_module.sh" "modules/essential-tweaks.sh" && echo "   ✅ essential_tweaks_module.sh → modules/essential-tweaks.sh"

echo ""

# =============================================================================
# MOVER CONFIGURAÇÕES
# =============================================================================

echo "⚙️ Organizando configurações..."

[[ -f "main_config_file.sh" ]] && mv "main_config_file.sh" "config/settings.conf" && echo "   ✅ main_config_file.sh → config/settings.conf"

# Criar enterprise.conf se não existir
if [[ ! -f "config/enterprise.conf" ]]; then
    cat > "config/enterprise.conf" << 'EOF'
# Configuração empresarial - override conservador
ENTERPRISE_MODE="true"
SKIP_DNS_CONFIG="true"
SKIP_NETWORK_CONFIG="true"
AUTO_BACKUP="true"
DEFAULT_ANSWER="n"
EOF
    echo "   ✅ config/enterprise.conf criado"
fi

echo ""

# =============================================================================
# MOVER TESTES
# =============================================================================

echo "🧪 Organizando testes..."

[[ -f "validate-optimizations.sh" ]] && mv "validate-optimizations.sh" "tests/" && echo "   ✅ validate-optimizations.sh → tests/"
[[ -f "benchmark.sh" ]] && mv "benchmark.sh" "tests/" && echo "   ✅ benchmark.sh → tests/"

echo ""

# =============================================================================
# SCRIPTS PRINCIPAIS
# =============================================================================

echo "🚀 Organizando scripts principais..."

# Renomear script principal
[[ -f "main_optimizer_script.sh" ]] && mv "main_optimizer_script.sh" "laptop-optimizer-main.sh" && echo "   ✅ main_optimizer_script.sh → laptop-optimizer-main.sh"

# Mover installer
[[ -f "community_tools_installer.sh" ]] && mv "community_tools_installer.sh" "install-community-tools.sh" && echo "   ✅ community_tools_installer.sh → install-community-tools.sh"
[[ -f "setup_installer.sh" ]] && mv "setup_installer.sh" "setup.sh" && echo "   ✅ setup_installer.sh → setup.sh"

echo ""

# =============================================================================
# CRIAR SCRIPT PRINCIPAL DE ENTRADA
# =============================================================================

echo "📄 Criando script principal optimize-laptop.sh..."

cat > "optimize-laptop.sh" << 'EOF'
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
EOF

chmod +x "optimize-laptop.sh"
echo "   ✅ optimize-laptop.sh criado e executável"

echo ""

# =============================================================================
# CRIAR README
# =============================================================================

echo "📖 Criando README.md..."

cat > "README.md" << 'EOF'
# 🚀 Laptop Optimizer v4.0 - Híbrido

**Sistema modular de otimização para laptops Ubuntu/Debian focado em desenvolvimento**

## 🚀 Uso Rápido

```bash
# Executar otimizador
./optimize-laptop.sh

# Ou instalar permanentemente
./setup.sh
laptop-optimizer
```

## 📋 Cenários

- **🏢 Empresarial**: Opção 9 (verificações de conflitos)
- **💻 Pessoal**: Opção 8 (otimização completa)  
- **🔧 Primeira vez**: Opção 1 (ferramentas da comunidade)

## 🛠️ Comandos (após otimização)

```bash
dev-status      # Dashboard do sistema
dev-clean now   # Limpeza rápida
dev-health      # Health check
dev-tools       # Verificar ferramentas
```

## 📁 Estrutura

```
laptop-optimizer/
├── optimize-laptop.sh           # 🚀 Script principal
├── lib/                         # 📚 Bibliotecas
├── modules/                     # 🔧 Módulos funcionais
├── config/                      # ⚙️ Configurações
└── tests/                       # 🧪 Testes e benchmarks
```

## ✨ Especialidades Únicas

- 🏢 **Verificação de conflitos empresariais** (VPN, Docker, SSH)
- 🐳 **Docker cleanup inteligente** (preserva BDs automaticamente) 
- 🧹 **Sistema de manutenção** com monitorização
- ⚡ **Scripts utilitários práticos**
- 🔄 **Sistema de backup/rollback**

---
**Objetivo**: Laptop de desenvolvimento otimizado e seguro! 🎯
EOF

echo "   ✅ README.md criado"

echo ""

# =============================================================================
# DAR PERMISSÕES
# =============================================================================

echo "🔐 Configurando permissões..."

chmod +x *.sh 2>/dev/null || true
chmod +x lib/*.sh 2>/dev/null || true  
chmod +x modules/*.sh 2>/dev/null || true
chmod +x tests/*.sh 2>/dev/null || true

echo "   ✅ Permissões de execução configuradas"

echo ""

# =============================================================================
# VERIFICAR ESTRUTURA FINAL
# =============================================================================

echo "🔍 Verificando estrutura final..."

echo ""
echo "📁 ESTRUTURA CRIADA:"
tree -a -L 2 2>/dev/null || {
    echo "lib/"
    ls lib/ 2>/dev/null | sed 's/^/   /'
    echo "modules/" 
    ls modules/ 2>/dev/null | sed 's/^/   /'
    echo "config/"
    ls config/ 2>/dev/null | sed 's/^/   /'
    echo "tests/"
    ls tests/ 2>/dev/null | sed 's/^/   /'
    echo ""
    echo "Scripts principais:"
    ls *.sh 2>/dev/null | sed 's/^/   /'
}

echo ""

# =============================================================================
# TESTE BÁSICO
# =============================================================================

echo "🧪 Teste básico..."

if [[ -f "optimize-laptop.sh" ]] && [[ -f "lib/colors.sh" ]] && [[ -f "laptop-optimizer-main.sh" ]]; then
    echo "   ✅ Estrutura correta criada"
    
    # Teste de carregamento
    if ./optimize-laptop.sh --version >/dev/null 2>&1; then
        echo "   ✅ Script principal funcional"
    else
        echo "   ⚠️ Script principal pode precisar de ajustes"
    fi
else
    echo "   ❌ Alguns ficheiros críticos em falta"
fi

echo ""

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

echo "🎉 ORGANIZAÇÃO CONCLUÍDA!"
echo "========================"
echo ""
echo "✅ Estrutura modular criada"
echo "✅ Ficheiros organizados por categoria"  
echo "✅ Permissões configuradas"
echo "✅ Scripts principais prontos"
echo ""
echo "🚀 PRÓXIMOS PASSOS:"
echo "   1. Testar: ./optimize-laptop.sh --help"
echo "   2. Executar: ./optimize-laptop.sh"  
echo "   3. Ou instalar: ./setup.sh"
echo ""
echo "📋 COMANDOS DISPONÍVEIS:"
echo "   ./optimize-laptop.sh        # Menu principal"
echo "   ./optimize-laptop.sh -v     # Ver versão"
echo "   ./setup.sh                  # Instalar permanentemente"
echo "   ./tests/benchmark.sh        # Testar performance"
echo ""
echo "🎯 Projeto organizado e pronto para uso!"
EOF

Agora executa estes comandos **no diretório onde tens todos os scripts**:

```bash
# 1. Criar e executar o organizador
cat > organize.sh << 'SCRIPT_CONTENT'
# (cola aqui todo o conteúdo do script acima)
SCRIPT_CONTENT

# 2. Dar permissão e executar
chmod +x organize.sh
./organize.sh
```

O script vai:
- ✅ **Criar estrutura** `lib/`, `modules/`, `config/`, `tests/`
- ✅ **Mover ficheiros** para locais corretos  
- ✅ **Renomear** conforme necessário
- ✅ **Criar scripts principais** em falta
- ✅ **Configurar permissões** 
- ✅ **Testar estrutura** final

Depois podes testar:
```bash
# Testar se funcionou
./optimize-laptop.sh --help
./optimize-laptop.sh --version

# Executar otimizador  
./optimize-laptop.sh
```

**Quer que eu crie um script ainda mais simples que faças copy/paste direto?** 🤔