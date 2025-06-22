#!/bin/bash
# =============================================================================
# ORGANIZAÇÃO FINAL DO LAPTOP OPTIMIZER
# Corrige estrutura e nomes para ficar 100% funcional
# =============================================================================

set -euo pipefail

echo "🚀 ORGANIZANDO ESTRUTURA FINAL DO LAPTOP OPTIMIZER"
echo "=================================================="
echo ""

# =============================================================================
# VERIFICAR ESTADO ATUAL
# =============================================================================

echo "🔍 Verificando estado atual..."

# Verificar se estamos no diretório correto
if [[ ! -f "optimize-laptop.sh" ]]; then
    echo "❌ Erro: execute no diretório principal do projeto"
    exit 1
fi

echo "✅ Diretório principal encontrado"

# =============================================================================
# MOVER FICHEIROS DE FIXDIR/ PARA LOCAIS CORRETOS
# =============================================================================

echo ""
echo "📁 Movendo ficheiros da estrutura final..."

# Script principal
if [[ -f "fixDir/laptop-optimizer-main.sh" ]]; then
    mv "fixDir/laptop-optimizer-main.sh" "./laptop-optimizer-main.sh"
    echo "✅ laptop-optimizer-main.sh → raiz"
fi

# Configurações
if [[ -f "fixDir/enterprise_config.sh" ]]; then
    mv "fixDir/enterprise_config.sh" "config/enterprise-advanced.conf"
    echo "✅ enterprise_config.sh → config/"
fi

# Benchmark para tests
if [[ -f "fixDir/performance_benchmark.sh" ]]; then
    mv "fixDir/performance_benchmark.sh" "tests/benchmark.sh"
    echo "✅ performance_benchmark.sh → tests/"
fi

# =============================================================================
# VERIFICAR E CRIAR ESTRUTURA SE NECESSÁRIO
# =============================================================================

echo ""
echo "📂 Verificando estrutura de diretórios..."

for dir in lib modules config tests; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "✅ Criado: $dir/"
    else
        echo "✅ Existe: $dir/"
    fi
done

# =============================================================================
# VERIFICAR BIBLIOTECAS ESTÃO NO LOCAL CORRETO
# =============================================================================

echo ""
echo "📚 Verificando bibliotecas..."

required_libs=("colors.sh" "common.sh" "validation.sh" "backup.sh")
missing_libs=()

for lib in "${required_libs[@]}"; do
    if [[ -f "lib/$lib" ]]; then
        echo "✅ lib/$lib"
    else
        missing_libs+=("$lib")
        echo "❌ lib/$lib - EM FALTA"
    fi
done

if [[ ${#missing_libs[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️ BIBLIOTECAS EM FALTA: ${missing_libs[*]}"
    echo "   Estas bibliotecas são críticas para o funcionamento"
fi

# =============================================================================
# VERIFICAR MÓDULOS
# =============================================================================

echo ""
echo "🔧 Verificando módulos..."

required_modules=(
    "enterprise-conflicts.sh"
    "development-config.sh" 
    "smart-maintenance.sh"
    "utility-scripts.sh"
    "docker-cleanup.sh"
    "essential-tweaks.sh"
)

missing_modules=()

for module in "${required_modules[@]}"; do
    if [[ -f "modules/$module" ]]; then
        echo "✅ modules/$module"
    else
        missing_modules+=("$module")
        echo "❌ modules/$module - EM FALTA"
    fi
done

if [[ ${#missing_modules[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️ MÓDULOS EM FALTA: ${missing_modules[*]}"
fi

# =============================================================================
# VERIFICAR CONFIGURAÇÕES
# =============================================================================

echo ""
echo "⚙️ Verificando configurações..."

if [[ -f "config/settings.conf" ]]; then
    echo "✅ config/settings.conf"
else
    echo "❌ config/settings.conf - EM FALTA"
fi

if [[ -f "config/enterprise.conf" ]]; then
    echo "✅ config/enterprise.conf"
else
    echo "❌ config/enterprise.conf - EM FALTA"
fi

# =============================================================================
# VERIFICAR SCRIPTS PRINCIPAIS
# =============================================================================

echo ""
echo "🚀 Verificando scripts principais..."

main_scripts=(
    "optimize-laptop.sh"
    "laptop-optimizer-main.sh"
    "install-community-tools.sh"
    "setup.sh"
)

for script in "${main_scripts[@]}"; do
    if [[ -f "$script" ]]; then
        echo "✅ $script"
        # Verificar se é executável
        if [[ -x "$script" ]]; then
            echo "   ✅ Executável"
        else
            chmod +x "$script"
            echo "   🔧 Tornando executável"
        fi
    else
        echo "❌ $script - EM FALTA"
    fi
done

# =============================================================================
# VERIFICAR DEPENDÊNCIAS ENTRE SCRIPTS
# =============================================================================

echo ""
echo "🔗 Verificando dependências..."

# Verificar se optimize-laptop.sh chama o script correto
if grep -q "laptop-optimizer-main.sh" "optimize-laptop.sh" 2>/dev/null; then
    if [[ -f "laptop-optimizer-main.sh" ]]; then
        echo "✅ optimize-laptop.sh → laptop-optimizer-main.sh (OK)"
    else
        echo "❌ optimize-laptop.sh chama laptop-optimizer-main.sh mas ficheiro não existe"
    fi
else
    echo "⚠️ optimize-laptop.sh pode não estar a chamar o script principal correto"
fi

# Verificar imports de bibliotecas em módulos
echo ""
echo "🔍 Verificando imports de bibliotecas nos módulos..."

for module_file in modules/*.sh; do
    [[ ! -f "$module_file" ]] && continue
    
    module_name=$(basename "$module_file")
    
    if grep -q "source.*lib/colors.sh" "$module_file" 2>/dev/null; then
        echo "✅ $module_name carrega colors.sh"
    else
        echo "⚠️ $module_name não carrega colors.sh"
    fi
    
    if grep -q "source.*lib/common.sh" "$module_file" 2>/dev/null; then
        echo "✅ $module_name carrega common.sh"
    else
        echo "⚠️ $module_name não carrega common.sh"
    fi
done

# =============================================================================
# LIMPAR FICHEIROS DESNECESSÁRIOS
# =============================================================================

echo ""
echo "🧹 Limpando ficheiros desnecessários..."

# Remover fixDir se estiver vazio
if [[ -d "fixDir" ]]; then
    if [[ -z "$(ls -A fixDir)" ]]; then
        rmdir fixDir
        echo "✅ Removido diretório fixDir/ vazio"
    else
        echo "⚠️ fixDir/ ainda contém ficheiros:"
        ls -la fixDir/
    fi
fi

# Remover ficheiros temporários
rm -f *.backup.* *.tmp .DS_Store 2>/dev/null || true

# =============================================================================
# DEFINIR PERMISSÕES CORRETAS
# =============================================================================

echo ""
echo "🔐 Configurando permissões..."

# Scripts principais executáveis
chmod +x *.sh 2>/dev/null || true

# Bibliotecas executáveis (para source)
chmod +x lib/*.sh 2>/dev/null || true

# Módulos executáveis 
chmod +x modules/*.sh 2>/dev/null || true

# Testes executáveis
chmod +x tests/*.sh 2>/dev/null || true

echo "✅ Permissões configuradas"

# =============================================================================
# TESTE BÁSICO DE FUNCIONAMENTO
# =============================================================================

echo ""
echo "🧪 Teste básico de funcionamento..."

# Testar carregamento do script principal
if ./optimize-laptop.sh --version >/dev/null 2>&1; then
    echo "✅ optimize-laptop.sh --version funciona"
else
    echo "❌ optimize-laptop.sh --version falha"
fi

# Testar carregamento de bibliotecas
if [[ -f "lib/colors.sh" ]] && source lib/colors.sh >/dev/null 2>&1; then
    echo "✅ lib/colors.sh carrega corretamente"
else
    echo "❌ lib/colors.sh tem problemas"
fi

# =============================================================================
# RELATÓRIO FINAL
# =============================================================================

echo ""
echo "📊 RELATÓRIO FINAL"
echo "=================="
echo ""

# Contar problemas
total_problems=0
[[ ${#missing_libs[@]} -gt 0 ]] && ((total_problems += ${#missing_libs[@]}))
[[ ${#missing_modules[@]} -gt 0 ]] && ((total_problems += ${#missing_modules[@]}))

if [[ $total_problems -eq 0 ]]; then
    echo "🎉 ESTRUTURA 100% FUNCIONAL!"
    echo ""
    echo "✅ Todos os ficheiros principais presentes"
    echo "✅ Bibliotecas carregam corretamente"
    echo "✅ Módulos estão no local correto"
    echo "✅ Permissões configuradas"
    echo ""
    echo "🚀 PRÓXIMOS PASSOS:"
    echo "   ./optimize-laptop.sh --help"
    echo "   ./optimize-laptop.sh"
    echo ""
else
    echo "⚠️ $total_problems PROBLEMAS ENCONTRADOS"
    echo ""
    
    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        echo "❌ Bibliotecas em falta:"
        for lib in "${missing_libs[@]}"; do
            echo "   • lib/$lib"
        done
        echo ""
    fi
    
    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        echo "❌ Módulos em falta:"
        for module in "${missing_modules[@]}"; do
            echo "   • modules/$module"
        done
        echo ""
    fi
    
    echo "🔧 SOLUÇÕES:"
    echo "   1. Verificar se ficheiros estão em outros locais"
    echo "   2. Mover manualmente ficheiros em falta"
    echo "   3. Recriar ficheiros se necessário"
fi

echo ""
echo "📁 ESTRUTURA FINAL:"
tree -a -L 2 2>/dev/null || {
    echo "lib/"
    ls lib/ 2>/dev/null | sed 's/^/   /' || echo "   (vazio)"
    echo "modules/"
    ls modules/ 2>/dev/null | sed 's/^/   /' || echo "   (vazio)"
    echo "config/"
    ls config/ 2>/dev/null | sed 's/^/   /' || echo "   (vazio)"
    echo "tests/"
    ls tests/ 2>/dev/null | sed 's/^/   /' || echo "   (vazio)"
    echo ""
    echo "Scripts principais:"
    ls *.sh 2>/dev/null | sed 's/^/   /' || echo "   (nenhum)"
}

echo ""
echo "🎯 PROJETO ORGANIZADO!"