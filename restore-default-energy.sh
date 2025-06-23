#!/bin/bash
# =============================================================================
# RESTAURAR GESTÃO DE ENERGIA PADRÃO INTELIGENTE
# Remove ferramentas externas e usa configuração padrão do sistema
# =============================================================================

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}🔄 RESTAURAR GESTÃO ENERGIA PADRÃO${NC}"
echo "=================================="
echo ""

echo -e "${BLUE}🎯 OBJETIVO:${NC}"
echo "   ✅ Gestão inteligente sempre (não performance fixo)"
echo "   ✅ Sem boosts de CPU (menos calor)"
echo "   ✅ Configuração padrão do sistema"
echo "   ✅ Remover ferramentas externas"
echo ""

# Verificar estado atual
echo -e "${BLUE}📊 ESTADO ATUAL:${NC}"
current_gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
available_govs=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "unknown")

echo "   Governor atual: $current_gov"
echo "   Governors disponíveis: $available_govs"

# Verificar ferramentas instaladas
auto_cpufreq_active=false
tlp_active=false

if command -v auto-cpufreq >/dev/null 2>&1 && pgrep -f auto-cpufreq >/dev/null 2>&1; then
    auto_cpufreq_active=true
    echo "   🔧 Auto-cpufreq: Ativo (será removido)"
fi

if command -v tlp >/dev/null 2>&1 && systemctl is-active --quiet tlp 2>/dev/null; then
    tlp_active=true
    echo "   🔧 TLP: Ativo (será removido)"
fi

if [[ "$auto_cpufreq_active" == false && "$tlp_active" == false ]]; then
    echo "   ✅ Sem ferramentas externas ativas"
fi

echo ""

if ! read -p "Continuar com restauração para configuração padrão? (Y/n): " confirm || [[ "$confirm" =~ ^[Nn] ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo ""
echo -e "${BLUE}🔧 EXECUTANDO LIMPEZA...${NC}"
echo ""

# 1. Remover auto-cpufreq se ativo
if [[ "$auto_cpufreq_active" == true ]]; then
    echo "1. Removendo auto-cpufreq..."
    sudo auto-cpufreq --remove 2>/dev/null || true
    sudo pkill -f auto-cpufreq 2>/dev/null || true
    echo "   ✅ Auto-cpufreq removido"
else
    echo "1. Auto-cpufreq: já não está ativo"
fi

# 2. Remover TLP se ativo
if [[ "$tlp_active" == true ]]; then
    echo "2. Parando TLP..."
    sudo systemctl stop tlp 2>/dev/null || true
    sudo systemctl disable tlp 2>/dev/null || true
    echo "   ✅ TLP desativado"
else
    echo "2. TLP: não está ativo"
fi

# 3. Remover configurações forçadas
echo "3. Removendo configurações forçadas..."

# Remover cpufrequtils se existir
if [[ -f /etc/default/cpufrequtils ]]; then
    sudo mv /etc/default/cpufrequtils /etc/default/cpufrequtils.backup.$(date +%Y%m%d)
    echo "   ✅ cpufrequtils config removido (backup criado)"
fi

# Remover configs TLP personalizadas
for tlp_config in /etc/tlp.d/01-*.conf; do
    if [[ -f "$tlp_config" ]]; then
        sudo mv "$tlp_config" "${tlp_config}.backup.$(date +%Y%m%d)" 2>/dev/null || true
        echo "   ✅ Config TLP removido: $(basename "$tlp_config")"
    fi
done

echo "   ✅ Configurações forçadas removidas"

# 4. Configurar governor padrão inteligente
echo "4. Configurando gestão energia padrão..."

# Verificar que governors estão disponíveis
if [[ "$available_govs" =~ powersave ]]; then
    target_governor="powersave"
    echo "   🎯 Usando 'powersave' (gestão dinâmica inteligente)"
elif [[ "$available_govs" =~ ondemand ]]; then
    target_governor="ondemand"
    echo "   🎯 Usando 'ondemand' (gestão automática)"
else
    target_governor="performance"
    echo "   ⚠️ Apenas 'performance' disponível"
fi

# Aplicar governor a todos os CPUs
for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [[ -f "$cpu_gov" ]]; then
        echo "$target_governor" | sudo tee "$cpu_gov" >/dev/null 2>&1 || true
    fi
done

echo "   ✅ Governor configurado: $target_governor"

# 5. Desativar CPU boost (reduzir calor)
echo "5. Desativando CPU boost..."

boost_disabled=false

# Intel boost
if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    echo "1" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1 || true
    echo "   ✅ Intel Turbo Boost desativado"
    boost_disabled=true
fi

# AMD boost
if [[ -f /sys/devices/system/cpu/cpufreq/boost ]]; then
    echo "0" | sudo tee /sys/devices/system/cpu/cpufreq/boost >/dev/null 2>&1 || true
    echo "   ✅ AMD Boost desativado"
    boost_disabled=true
fi

# Boost genérico por CPU
for cpu_boost in /sys/devices/system/cpu/cpu*/cpufreq/boost; do
    if [[ -f "$cpu_boost" ]]; then
        echo "0" | sudo tee "$cpu_boost" >/dev/null 2>&1 || true
        boost_disabled=true
    fi
done

if [[ "$boost_disabled" == true ]]; then
    echo "   ✅ CPU Boost desativado"
else
    echo "   ℹ️ CPU Boost não disponível ou já desativado"
fi

# 6. Criar configuração permanente para manter após reboot
echo "6. Criando configuração permanente..."

sudo tee /etc/systemd/system/cpu-energy-default.service > /dev/null << EOF
[Unit]
Description=Default CPU Energy Management
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/apply-default-cpu-config

[Install]
WantedBy=multi-user.target
EOF

sudo tee /usr/local/bin/apply-default-cpu-config > /dev/null << EOF
#!/bin/bash
# Aplicar configuração padrão de energia

# Governor inteligente
for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [[ -f "\$cpu_gov" ]]; then
        echo "$target_governor" > "\$cpu_gov" 2>/dev/null || true
    fi
done

# Desativar boost
[[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]] && echo "1" > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
[[ -f /sys/devices/system/cpu/cpufreq/boost ]] && echo "0" > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true

for cpu_boost in /sys/devices/system/cpu/cpu*/cpufreq/boost; do
    [[ -f "\$cpu_boost" ]] && echo "0" > "\$cpu_boost" 2>/dev/null || true
done
EOF

sudo chmod +x /usr/local/bin/apply-default-cpu-config
sudo systemctl enable cpu-energy-default.service 2>/dev/null || true

echo "   ✅ Configuração permanente criada"

echo ""
echo -e "${BLUE}🔄 AGUARDANDO APLICAÇÃO...${NC}"
sleep 2

# Verificar resultado
echo ""
echo -e "${BLUE}📊 ESTADO APÓS CONFIGURAÇÃO:${NC}"

new_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
current_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{print $4}' | cut -d. -f1 2>/dev/null || echo "unknown")

echo "   Governor: $new_governor"
echo "   Frequência atual: ${current_freq}MHz"

# Verificar boost
boost_status="desconhecido"
if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "0")
    [[ "$no_turbo" == "1" ]] && boost_status="desativado (Intel)" || boost_status="ativo (Intel)"
elif [[ -f /sys/devices/system/cpu/cpufreq/boost ]]; then
    boost_enabled=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo "1")
    [[ "$boost_enabled" == "0" ]] && boost_status="desativado (AMD)" || boost_status="ativo (AMD)"
fi

echo "   CPU Boost: $boost_status"

# Verificar frequência máxima configurada
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
    max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo "0")
    max_freq_mhz=$((max_freq / 1000))
    
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq ]]; then
        scaling_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "0")
        scaling_max_mhz=$((scaling_max / 1000))
        
        echo "   Freq. máxima hardware: ${max_freq_mhz}MHz"
        echo "   Freq. máxima scaling: ${scaling_max_mhz}MHz"
    fi
fi

echo ""
echo -e "${GREEN}✅ CONFIGURAÇÃO PADRÃO RESTAURADA!${NC}"
echo ""
echo -e "${BLUE}💡 COMO FUNCIONA AGORA:${NC}"

case "$target_governor" in
    "powersave")
        echo "   🧠 Governor 'powersave': Gestão dinâmica inteligente"
        echo "      • Frequência adapta-se automaticamente à carga"
        echo "      • Prioriza eficiência energética"
        echo "      • Sem boosts (menos calor)"
        ;;
    "ondemand")
        echo "   🧠 Governor 'ondemand': Gestão automática"
        echo "      • Frequência aumenta sob carga"
        echo "      • Reduz quando sistema idle"
        echo "      • Sem boosts (menos calor)"
        ;;
    "performance")
        echo "   ⚠️ Governor 'performance': Frequência fixa alta"
        echo "      • Sistema limitado a este governor"
        echo "      • Boosts desativados para reduzir calor"
        ;;
esac

echo ""
echo -e "${BLUE}🔧 COMANDOS PARA MONITORIZAR:${NC}"
echo "   # Ver governor atual:"
echo "   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | uniq"
echo ""
echo "   # Ver frequências em tempo real:"
echo "   watch 'grep MHz /proc/cpuinfo | head -4'"
echo ""
echo "   # Ver temperatura (se disponível):"
echo "   sensors"
echo ""
echo "   # Testar carga CPU:"
echo "   stress --cpu 2 --timeout 10s"
echo ""

echo -e "${YELLOW}⚡ CONFIGURAÇÃO PERSISTENTE:${NC}"
echo "   • Aplicada automaticamente no boot"
echo "   • Sem dependências externas"
echo "   • Usa gestão nativa do kernel Linux"
echo ""

echo -e "${GREEN}🎯 OBJETIVO ALCANÇADO:${NC}"
echo "   ✅ Gestão energia inteligente sempre ativa"
echo "   ✅ CPU boost desativado (menos calor)"
echo "   ✅ Configuração padrão do sistema"
echo "   ✅ Sem ferramentas externas"
echo ""