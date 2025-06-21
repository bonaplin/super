#!/bin/bash
# =============================================================================
# BENCHMARK COMPLETO DE PERFORMANCE
# Testa melhorias antes/depois das otimizações
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

readonly BENCHMARK_LOG="/tmp/laptop-optimizer-benchmark.log"
readonly RESULTS_FILE="/tmp/benchmark-results.json"

# =============================================================================
# BENCHMARK DE CPU
# =============================================================================

benchmark_cpu() {
    section_header "CPU Performance" "$SYMBOL_ROCKET"
    
    echo -e "${BLUE}🔬 Testando CPU...${NC}"
    
    # Teste 1: CPU stress test
    echo "   Teste 1: CPU stress (10 segundos)"
    local start_time=$(date +%s.%N)
    timeout 10s yes >/dev/null 2>&1 || true
    local end_time=$(date +%s.%N)
    local cpu_time=$(echo "$end_time - $start_time" | bc -l | cut -c1-6)
    
    # Teste 2: Operações matemáticas
    echo "   Teste 2: Cálculos matemáticos"
    start_time=$(date +%s.%N)
    for i in {1..1000}; do
        echo "scale=10; sqrt($i)" | bc -l >/dev/null
    done
    end_time=$(date +%s.%N)
    local math_time=$(echo "$end_time - $start_time" | bc -l | cut -c1-6)
    
    # Teste 3: Compilação (se gcc disponível)
    local compile_time="N/A"
    if command -v gcc >/dev/null 2>&1; then
        echo "   Teste 3: Compilação C"
        cat > /tmp/benchmark.c << 'EOF'
#include <stdio.h>
#include <math.h>
int main() {
    for(int i=0; i<100000; i++) {
        double result = sqrt(i) * sin(i);
    }
    return 0;
}
EOF
        start_time=$(date +%s.%N)
        gcc -O2 /tmp/benchmark.c -o /tmp/benchmark -lm 2>/dev/null
        end_time=$(date +%s.%N)
        compile_time=$(echo "$end_time - $start_time" | bc -l | cut -c1-6)
        rm -f /tmp/benchmark.c /tmp/benchmark
    fi
    
    echo ""
    echo -e "${GREEN}📊 Resultados CPU:${NC}"
    echo "   • Stress test: ${cpu_time}s"
    echo "   • Cálculos: ${math_time}s"
    echo "   • Compilação: ${compile_time}s"
    
    # Guardar resultados
    cat >> "$RESULTS_FILE" << EOF
{
  "cpu": {
    "stress_time": $cpu_time,
    "math_time": $math_time,
    "compile_time": "$compile_time"
  },
EOF
    
    echo ""
}

# =============================================================================
# BENCHMARK DE MEMÓRIA
# =============================================================================

benchmark_memory() {
    section_header "Memory Performance" "$SYMBOL_STORAGE"
    
    echo -e "${BLUE}🔬 Testando Memória...${NC}"
    
    # Teste 1: Alocação de memória
    echo "   Teste 1: Alocação de memória"
    local start_time=$(date +%s.%N)
    python3 -c "
import time
start = time.time()
data = [i for i in range(1000000)]
end = time.time()
print(f'{(end-start)*1000:.1f}')
" 2>/dev/null > /tmp/mem_alloc_time || echo "0" > /tmp/mem_alloc_time
    local alloc_time=$(cat /tmp/mem_alloc_time)
    
    # Teste 2: Operações em arrays
    echo "   Teste 2: Operações em arrays"
    start_time=$(date +%s.%N)
    python3 -c "
data = list(range(100000))
result = sum(x*x for x in data)
" 2>/dev/null
    local end_time=$(date +%s.%N)
    local array_time=$(echo "($end_time - $start_time) * 1000" | bc -l | cut -c1-6)
    
    # Teste 3: Uso atual de memória
    local ram_usage=$(free | awk '/^Mem:/ {printf "%.1f", $3*100/$2}')
    local swap_usage=$(free | awk '/^Swap:/ {if($2>0) printf "%.1f", $3*100/$2; else print "0"}')
    
    echo ""
    echo -e "${GREEN}📊 Resultados Memória:${NC}"
    echo "   • Alocação: ${alloc_time}ms"
    echo "   • Operações array: ${array_time}ms"
    echo "   • RAM em uso: ${ram_usage}%"
    echo "   • Swap em uso: ${swap_usage}%"
    
    # Guardar resultados
    cat >> "$RESULTS_FILE" << EOF
  "memory": {
    "alloc_time": $alloc_time,
    "array_time": $array_time,
    "ram_usage": $ram_usage,
    "swap_usage": $swap_usage
  },
EOF
    
    echo ""
}

# =============================================================================
# BENCHMARK DE DISCO
# =============================================================================

benchmark_disk() {
    section_header "Disk Performance" "$SYMBOL_STORAGE"
    
    echo -e "${BLUE}🔬 Testando Disco...${NC}"
    
    # Teste 1: Escrita sequencial
    echo "   Teste 1: Escrita sequencial (100MB)"
    local start_time=$(date +%s.%N)
    dd if=/dev/zero of=/tmp/benchmark_write bs=1M count=100 2>/dev/null
    sync
    local end_time=$(date +%s.%N)
    local write_time=$(echo "$end_time - $start_time" | bc -l | cut -c1-6)
    local write_speed=$(echo "scale=1; 100 / $write_time" | bc -l)
    
    # Teste 2: Leitura sequencial
    echo "   Teste 2: Leitura sequencial"
    start_time=$(date +%s.%N)
    dd if=/tmp/benchmark_write of=/dev/null bs=1M 2>/dev/null
    end_time=$(date +%s.%N)
    local read_time=$(echo "$end_time - $start_time" | bc -l | cut -c1-6)
    local read_speed=$(echo "scale=1; 100 / $read_time" | bc -l)
    
    # Teste 3: I/O aleatório (pequenos arquivos)
    echo "   Teste 3: I/O aleatório (1000 arquivos)"
    start_time=$(date +%s.%N)
    for i in {1..1000}; do
        echo "test data $i" > "/tmp/benchmark_small_$i" 2>/dev/null
    done
    sync
    end_time=$(date +%s.%N)
    local random_time=$(echo "$end_time - $start_time" | bc -l | cut -c1-6)
    
    # Cleanup
    rm -f /tmp/benchmark_write /tmp/benchmark_small_*
    
    # Detectar tipo de storage
    local storage_type=$(detect_storage_type)
    
    echo ""
    echo -e "${GREEN}📊 Resultados Disco ($storage_type):${NC}"
    echo "   • Escrita: ${write_speed}MB/s (${write_time}s)"
    echo "   • Leitura: ${read_speed}MB/s (${read_time}s)"
    echo "   • I/O aleatório: ${random_time}s"
    
    # Verificar scheduler
    local scheduler="unknown"
    for device in /sys/block/sd* /sys/block/nvme*; do
        if [[ -f "$device/queue/scheduler" ]]; then
            scheduler=$(cat "$device/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]' | head -1)
            break
        fi
    done
    
    echo "   • I/O Scheduler: $scheduler"
    
    # Guardar resultados
    cat >> "$RESULTS_FILE" << EOF
  "disk": {
    "storage_type": "$storage_type",
    "write_speed": $write_speed,
    "read_speed": $read_speed,
    "random_time": $random_time,
    "io_scheduler": "$scheduler"
  },
EOF
    
    echo ""
}

# =============================================================================
# BENCHMARK DE REDE
# =============================================================================

benchmark_network() {
    section_header "Network Performance" "$SYMBOL_NETWORK"
    
    echo -e "${BLUE}🔬 Testando Rede...${NC}"
    
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo "   ❌ Sem conectividade - skip testes de rede"
        cat >> "$RESULTS_FILE" << EOF
  "network": {
    "connectivity": false
  },
EOF
        return 0
    fi
    
    # Teste 1: Latência
    echo "   Teste 1: Latência (ping)"
    local ping_avg=$(ping -c 10 8.8.8.8 2>/dev/null | tail -1 | awk -F/ '{print $5}' | cut -c1-6)
    
    # Teste 2: DNS resolution
    echo "   Teste 2: Resolução DNS"
    local start_time=$(date +%s.%N)
    for domain in google.com github.com stackoverflow.com; do
        nslookup "$domain" >/dev/null 2>&1
    done
    local end_time=$(date +%s.%N)
    local dns_time=$(echo "($end_time - $start_time) * 1000" | bc -l | cut -c1-6)
    
    # Teste 3: Download pequeno
    echo "   Teste 3: Download pequeno"
    start_time=$(date +%s.%N)
    curl -s -o /dev/null http://httpbin.org/bytes/1024 || true
    end_time=$(date +%s.%N)
    local download_time=$(echo "($end_time - $start_time) * 1000" | bc -l | cut -c1-6)
    
    # Configurações de rede
    local rmem_max=$(cat /proc/sys/net/core/rmem_max 2>/dev/null)
    local wmem_max=$(cat /proc/sys/net/core/wmem_max 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}📊 Resultados Rede:${NC}"
    echo "   • Ping médio: ${ping_avg}ms"
    echo "   • DNS resolution: ${dns_time}ms"
    echo "   • Download 1KB: ${download_time}ms"
    echo "   • Buffer RX: $rmem_max bytes"
    echo "   • Buffer TX: $wmem_max bytes"
    
    # Guardar resultados
    cat >> "$RESULTS_FILE" << EOF
  "network": {
    "connectivity": true,
    "ping_avg": $ping_avg,
    "dns_time": $dns_time,
    "download_time": $download_time,
    "rmem_max": $rmem_max,
    "wmem_max": $wmem_max
  },
EOF
    
    echo ""
}

# =============================================================================
# BENCHMARK DE SISTEMA
# =============================================================================

benchmark_system() {
    section_header "System Metrics" "$SYMBOL_COMPUTER"
    
    echo -e "${BLUE}🔬 Métricas do Sistema...${NC}"
    
    # Boot time (se disponível)
    local boot_time="N/A"
    if command -v systemd-analyze >/dev/null 2>&1; then
        boot_time=$(systemd-analyze 2>/dev/null | grep "Startup finished" | awk '{print $(NF-1)}' | tr -d '(' || echo "N/A")
    fi
    
    # Configurações otimizadas
    local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    local inotify_watches=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "8192")
    local file_max=$(cat /proc/sys/fs/file-max 2>/dev/null || echo "65536")
    
    # Serviços de otimização
    local tlp_active=$(systemctl is-active tlp 2>/dev/null || echo "inactive")
    local auto_cpufreq_active="inactive"
    if pgrep -f auto-cpufreq >/dev/null 2>&1; then
        auto_cpufreq_active="active"
    fi
    
    # Load average
    local load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_cores=$(nproc)
    
    echo ""
    echo -e "${GREEN}📊 Métricas Sistema:${NC}"
    echo "   • Boot time: $boot_time"
    echo "   • Swappiness: $swappiness (Ubuntu padrão: 60)"
    echo "   • inotify watches: $inotify_watches (Ubuntu padrão: 8192)"
    echo "   • Load (1min): $load_1min ($cpu_cores cores)"
    echo "   • TLP: $tlp_active"
    echo "   • Auto-CPUfreq: $auto_cpufreq_active"
    
    # Guardar resultados
    cat >> "$RESULTS_FILE" << EOF
  "system": {
    "boot_time": "$boot_time",
    "swappiness": $swappiness,
    "inotify_watches": $inotify_watches,
    "load_1min": $load_1min,
    "cpu_cores": $cpu_cores,
    "tlp_active": "$tlp_active",
    "auto_cpufreq_active": "$auto_cpufreq_active"
  }
}
EOF
    
    echo ""
}

# =============================================================================
# ANÁLISE DE RESULTADOS
# =============================================================================

analyze_results() {
    section_header "Análise de Performance" "$SYMBOL_STAR"
    
    echo -e "${BLUE}🎯 ANÁLISE DE PERFORMANCE:${NC}"
    echo ""
    
    # Analisar otimizações
    local optimizations=0
    local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    local inotify=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "8192")
    
    [[ $swappiness -le 15 ]] && ((optimizations++))
    [[ $inotify -gt 50000 ]] && ((optimizations++))
    systemctl is-active --quiet tlp 2>/dev/null && ((optimizations++))
    [[ -f /etc/sysctl.d/99-dev-*.conf ]] && ((optimizations++))
    
    echo -e "${GREEN}⚙️ OTIMIZAÇÕES ATIVAS: $optimizations/4${NC}"
    
    # Análise de performance por componente
    echo ""
    echo -e "${BLUE}📊 ANÁLISE POR COMPONENTE:${NC}"
    
    # CPU
    if [[ -f "$RESULTS_FILE" ]]; then
        echo "   🔬 CPU: Testes concluídos"
        echo "   💾 Memória: Uso atual monitorizado"
        echo "   💿 Disco: Performance medida"
        echo "   📶 Rede: Conectividade testada"
    fi
    
    # Recomendações
    echo ""
    echo -e "${YELLOW}💡 RECOMENDAÇÕES:${NC}"
    
    if [[ $optimizations -ge 3 ]]; then
        echo "   ✅ Sistema bem otimizado!"
        echo "   📈 Performance deve estar melhorada"
        echo "   🔄 Executar benchmark periodicamente"
    elif [[ $optimizations -ge 2 ]]; then
        echo "   ⚠️ Algumas otimizações aplicadas"
        echo "   🔧 Considerar otimizações adicionais"
        echo "   📋 Executar: dev-status para verificar"
    else
        echo "   ❌ Poucas otimizações detectadas"
        echo "   🚀 Executar: ./optimize-laptop.sh"
        echo "   📋 Verificar: dev-health"
    fi
    
    echo ""
    echo -e "${BLUE}📁 Resultados salvos em: $RESULTS_FILE${NC}"
    echo -e "${BLUE}📝 Log completo em: $BENCHMARK_LOG${NC}"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    clear
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 BENCHMARK COMPLETO DE PERFORMANCE                     ║
╚══════════════════════════════════════════════════════════════════════════════╝
${NC}"
    
    echo ""
    echo -e "${BLUE}Este benchmark vai testar:${NC}"
    echo "   • 🔬 Performance CPU e memória"
    echo "   • 💿 Velocidade de disco (leitura/escrita)"
    echo "   • 📶 Conectividade de rede"
    echo "   • ⚙️ Otimizações aplicadas"
    echo ""
    echo -e "${YELLOW}⏱️ Tempo estimado: 2-3 minutos${NC}"
    echo ""
    
    if ! confirm "Executar benchmark completo?" "y"; then
        log_info "Benchmark cancelado"
        exit 0
    fi
    
    # Inicializar logs
    echo "=== LAPTOP OPTIMIZER - BENCHMARK PERFORMANCE ===" > "$BENCHMARK_LOG"
    echo "Data: $(date)" >> "$BENCHMARK_LOG"
    echo "Sistema: $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)" >> "$BENCHMARK_LOG"
    echo "" >> "$BENCHMARK_LOG"
    
    # Inicializar resultados JSON
    echo "{ \"timestamp\": \"$(date -Iseconds)\"," > "$RESULTS_FILE"
    
    # Executar benchmarks
    benchmark_cpu
    benchmark_memory
    benchmark_disk
    benchmark_network
    benchmark_system
    
    # Analisar resultados
    analyze_results
    
    echo -e "${GREEN}🎉 Benchmark completo concluído!${NC}"
    echo ""
    echo -e "${BLUE}📋 PRÓXIMOS PASSOS:${NC}"
    echo "   • Comparar com benchmarks futuros"
    echo "   • Executar: dev-status (dashboard)"
    echo "   • Verificar: dev-health (health check)"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi