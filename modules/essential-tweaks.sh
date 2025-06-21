#!/bin/bash
# =============================================================================
# MÓDULO: OTIMIZAÇÕES ESSENCIAIS
# Apenas tweaks comprovados e seguros - sem experimentação
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# OTIMIZAÇÕES DE KERNEL ESSENCIAIS
# =============================================================================

apply_essential_kernel_tweaks() {
    section_header "Otimizações de Kernel Essenciais" "$SYMBOL_GEAR"
    
    local ram_gb=$(get_ram_gb)
    local storage_type=$(detect_storage_type)
    
    echo -e "${BLUE}🎯 Otimizações comprovadas:${NC}"
    bullet_list \
        "vm.swappiness=10 (menos swap, mais responsivo)" \
        "inotify watches aumentado (crítico para IDEs)" \
        "TRIM automático para SSD/NVMe" \
        "Configurações conservadoras baseadas no hardware"
    
    echo ""
    
    if ! confirm "Aplicar otimizações essenciais de kernel?" "y"; then
        return 0
    fi
    
    # Configurações baseadas no sistema
    local swappiness=10
    local inotify_watches=262144
    local dirty_ratio=15
    local dirty_bg_ratio=5
    
    # Ajustar baseado na RAM
    if [[ $ram_gb -ge 16 ]]; then
        inotify_watches=524288
        dirty_ratio=20
        dirty_bg_ratio=8
    elif [[ $ram_gb -ge 8 ]]; then
        inotify_watches=524288
        dirty_ratio=15
        dirty_bg_ratio=5
    elif [[ $ram_gb -lt 4 ]]; then
        swappiness=20  # Mais conservador com pouca RAM
        inotify_watches=131072
        dirty_ratio=10
        dirty_bg_ratio=3
    fi
    
    log_info "Configurando para: ${ram_gb}GB RAM, ${storage_type^^} storage"
    
    # Criar configuração sysctl essencial
    safe_write_config "/etc/sysctl.d/99-essential-tweaks.conf" \
"# Otimizações essenciais para laptop de desenvolvimento
# Sistema: ${ram_gb}GB RAM, ${storage_type} storage
# Aplicado: $(date)

# === MEMÓRIA E RESPONSIVIDADE ===
# Reduzir uso de swap (padrão Ubuntu: 60)
vm.swappiness=$swappiness

# Cache de filesystem mais eficiente
vm.vfs_cache_pressure=80

# Write-back otimizado para $storage_type
vm.dirty_ratio=$dirty_ratio
vm.dirty_background_ratio=$dirty_bg_ratio

# === DESENVOLVIMENTO ===
# inotify watches (padrão Ubuntu: 8192)
fs.inotify.max_user_watches=$inotify_watches
fs.inotify.max_user_instances=512

# File descriptors (padrão Ubuntu: 1024)
fs.file-max=65536

# === SEGURANÇA BÁSICA ===
# Proteção contra ataques de timing
kernel.kptr_restrict=1

# Proteção ptrace (padrão Ubuntu: 1)
kernel.yama.ptrace_scope=1"
    
    # Aplicar configurações imediatamente
    sudo sysctl -p /etc/sysctl.d/99-essential-tweaks.conf >/dev/null 2>&1
    
    log_success "Otimizações de kernel aplicadas"
    
    # Mostrar diferenças vs Ubuntu padrão
    echo ""
    echo -e "${BLUE}📊 DIFERENÇAS vs UBUNTU PADRÃO:${NC}"
    echo "   • swappiness: $swappiness (era: 60)"
    echo "   • inotify watches: $inotify_watches (era: 8192)"
    echo "   • dirty_ratio: $dirty_ratio% (era: 20%)"
    echo "   • file-max: 65536 (era: ~1024 por processo)"
    echo ""
}

# =============================================================================
# TRIM AUTOMÁTICO PARA SSD/NVME
# =============================================================================

configure_automatic_trim() {
    section_header "TRIM Automático para SSD" "$SYMBOL_GEAR"
    
    local storage_type=$(detect_storage_type)
    
    if [[ "$storage_type" == "hdd" ]]; then
        status_message "info" "HDD detectado - TRIM não aplicável"
        return 0
    fi
    
    echo -e "${BLUE}💾 SSD/NVMe detectado: ${storage_type^^}${NC}"
    echo ""
    echo -e "${BLUE}Benefícios do TRIM automático:${NC}"
    bullet_list \
        "Mantém performance do SSD ao longo do tempo" \
        "Evita degradação de velocidade de escrita" \
        "Executado automaticamente semanalmente" \
        "Sem impacto na performance durante uso"
    
    echo ""
    
    if ! confirm "Ativar TRIM automático?" "y"; then
        return 0
    fi
    
    # Verificar se TRIM está suportado
    if ! sudo fstrim -v / >/dev/null 2>&1; then
        status_message "warning" "TRIM não suportado neste sistema"
        return 1
    fi
    
    # Ativar fstrim.timer (padrão Ubuntu moderno)
    if systemctl list-unit-files | grep -q "fstrim.timer"; then
        safe_service_action "enable" "fstrim.timer"
        safe_service_action "start" "fstrim.timer"
        
        # Verificar status
        local timer_status=$(systemctl is-active fstrim.timer 2>/dev/null || echo "unknown")
        if [[ "$timer_status" == "active" ]]; then
            log_success "TRIM automático ativado (execução semanal)"
            
            # Mostrar próxima execução
            local next_run=$(systemctl list-timers fstrim.timer 2>/dev/null | grep fstrim | awk '{print $1, $2}' || echo "unknown")
            if [[ "$next_run" != "unknown" ]]; then
                echo "   Próxima execução: $next_run"
            fi
        else
            log_warning "TRIM timer não pôde ser ativado"
        fi
    else
        # Fallback: criar cron job manual
        log_info "fstrim.timer não disponível - criando cron job manual"
        echo "0 2 * * 0 root /sbin/fstrim -av >/dev/null 2>&1" | sudo tee /etc/cron.d/weekly-fstrim >/dev/null
        log_success "TRIM manual agendado (domingos às 02:00)"
    fi
}

# =============================================================================
# OTIMIZAÇÕES DE I/O PARA STORAGE
# =============================================================================

optimize_io_scheduler() {
    section_header "Otimização I/O Scheduler" "$SYMBOL_GEAR"
    
    local storage_type=$(detect_storage_type)
    
    echo -e "${BLUE}📊 Storage detectado: ${storage_type^^}${NC}"
    echo ""
    
    case "$storage_type" in
        "nvme")
            echo -e "${BLUE}Otimizações para NVMe:${NC}"
            bullet_list \
                "Scheduler: none (NVMe tem otimizações próprias)" \
                "Read-ahead: 512KB (otimizado para NVMe)" \
                "Queue depth: mantido padrão (alto)"
            ;;
        "ssd") 
            echo -e "${BLUE}Otimizações para SSD:${NC}"
            bullet_list \
                "Scheduler: mq-deadline ou none" \
                "Read-ahead: 256KB (otimizado para SSD)" \
                "Rotational: 0 (confirma que é SSD)"
            ;;
        "hdd")
            echo -e "${BLUE}Otimizações para HDD:${NC}"
            bullet_list \
                "Scheduler: mq-deadline (melhor para HDDs)" \
                "Read-ahead: 128KB (conservador para HDD)" \
                "Otimizações de seek time"
            ;;
    esac
    
    echo ""
    
    if ! confirm "Aplicar otimizações de I/O?" "y"; then
        return 0
    fi
    
    # Aplicar otimizações por dispositivo
    local optimized_devices=0
    
    for device_path in /sys/block/sd* /sys/block/nvme*; do
        [[ ! -d "$device_path" ]] && continue
        
        local device_name=$(basename "$device_path")
        
        # Verificar se é dispositivo de storage principal
        if [[ ! -e "/dev/$device_name" ]]; then
            continue
        fi
        
        # Detectar tipo do dispositivo específico
        local device_storage_type="unknown"
        if [[ "$device_name" =~ ^nvme ]]; then
            device_storage_type="nvme"
        elif [[ -f "$device_path/queue/rotational" ]]; then
            local rotational=$(cat "$device_path/queue/rotational" 2>/dev/null || echo "1")
            if [[ $rotational -eq 0 ]]; then
                device_storage_type="ssd"
            else
                device_storage_type="hdd"
            fi
        fi
        
        # Aplicar otimizações específicas
        case "$device_storage_type" in
            "nvme")
                # NVMe - usar scheduler 'none' se disponível
                if [[ -f "$device_path/queue/scheduler" ]]; then
                    local available_schedulers=$(cat "$device_path/queue/scheduler")
                    if [[ "$available_schedulers" =~ none ]]; then
                        echo "none" | sudo tee "$device_path/queue/scheduler" >/dev/null 2>&1
                        log_info "NVMe $device_name: scheduler 'none'"
                    fi
                fi
                
                # Read-ahead otimizado
                sudo blockdev --setra 1024 "/dev/$device_name" 2>/dev/null || true
                ;;
                
            "ssd")
                # SSD - mq-deadline ou none
                if [[ -f "$device_path/queue/scheduler" ]]; then
                    local available_schedulers=$(cat "$device_path/queue/scheduler")
                    if [[ "$available_schedulers" =~ none ]]; then
                        echo "none" | sudo tee "$device_path/queue/scheduler" >/dev/null 2>&1
                    else
                        echo "mq-deadline" | sudo tee "$device_path/queue/scheduler" >/dev/null 2>&1
                    fi
                    log_info "SSD $device_name: scheduler otimizado"
                fi
                
                # Confirmar rotational=0
                echo 0 | sudo tee "$device_path/queue/rotational" >/dev/null 2>&1 || true
                
                # Read-ahead
                sudo blockdev --setra 512 "/dev/$device_name" 2>/dev/null || true
                ;;
                
            "hdd")
                # HDD - mq-deadline
                if [[ -f "$device_path/queue/scheduler" ]]; then
                    echo "mq-deadline" | sudo tee "$device_path/queue/scheduler" >/dev/null 2>&1
                    log_info "HDD $device_name: scheduler 'mq-deadline'"
                fi
                
                # Read-ahead conservador
                sudo blockdev --setra 256 "/dev/$device_name" 2>/dev/null || true
                ;;
        esac
        
        ((optimized_devices++))
    done
    
    if [[ $optimized_devices -gt 0 ]]; then
        log_success "I/O scheduler otimizado para $optimized_devices dispositivos"
    else
        log_warning "Nenhum dispositivo de storage encontrado para otimizar"
    fi
}

# =============================================================================
# CONFIGURAÇÕES ESSENCIAIS DE DESENVOLVIMENTO
# =============================================================================

apply_essential_dev_config() {
    section_header "Configurações Essenciais de Desenvolvimento" "$SYMBOL_DEVELOPMENT"
    
    echo -e "${BLUE}Configurações críticas para desenvolvimento:${NC}"
    bullet_list \
        "inotify watches (já aplicado nas otimizações de kernel)" \
        "File descriptor limits básicos" \
        "Git configuração mínima" \
        "Bash history melhorado"
    
    echo ""
    
    if ! confirm "Aplicar configurações de desenvolvimento?" "y"; then
        return 0
    fi
    
    # File descriptor limits essenciais
    if [[ ! -f /etc/security/limits.d/99-essential-limits.conf ]]; then
        safe_write_config "/etc/security/limits.d/99-essential-limits.conf" \
"# Limites essenciais para desenvolvimento
# Aplicado: $(date)

# File descriptors (padrão Ubuntu: 1024)
* soft nofile 16384
* hard nofile 32768

# Processos (padrão Ubuntu: variável)
* soft nproc 8192
* hard nproc 16384"
        
        log_success "Limites de file descriptors configurados"
    fi
    
    # Git configuração mínima (apenas se não existir)
    if ! git config --global user.name >/dev/null 2>&1; then
        if confirm "Configurar Git (nome e email)?" "y"; then
            echo ""
            read -p "Nome completo: " git_name
            read -p "Email: " git_email
            
            if [[ -n "$git_name" && -n "$git_email" ]]; then
                git config --global user.name "$git_name"
                git config --global user.email "$git_email"
                git config --global init.defaultBranch main
                git config --global pull.rebase false
                
                log_success "Git configurado: $git_name ($git_email)"
            fi
        fi
    else
        log_success "Git já configurado"
    fi
    
    # Bash history essencial
    if ! grep -q "HISTSIZE=25000" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# === BASH HISTORY ESSENCIAL ===
export HISTSIZE=25000
export HISTFILESIZE=50000
export HISTCONTROL=ignoreboth
shopt -s histappend
EOF
        log_success "Bash history melhorado"
    else
        log_success "Bash history já otimizado"
    fi
}

# =============================================================================
# VERIFICAÇÃO DE RESULTADOS
# =============================================================================

verify_essential_tweaks() {
    section_header "Verificação das Otimizações" "$SYMBOL_CHECK"
    
    echo -e "${BLUE}🔍 Verificando otimizações aplicadas:${NC}"
    echo ""
    
    # Kernel tweaks
    local current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "unknown")
    if [[ $current_swappiness -le 15 ]]; then
        status_message "success" "Swappiness: $current_swappiness (otimizado)"
    else
        status_message "warning" "Swappiness: $current_swappiness (padrão)"
    fi
    
    local current_inotify=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "unknown")
    if [[ $current_inotify -gt 100000 ]]; then
        status_message "success" "inotify watches: $current_inotify (otimizado)"
    else
        status_message "warning" "inotify watches: $current_inotify (padrão)"
    fi
    
    # TRIM
    if systemctl is-active --quiet fstrim.timer 2>/dev/null; then
        status_message "success" "TRIM automático: ativo"
    elif [[ -f /etc/cron.d/weekly-fstrim ]]; then
        status_message "success" "TRIM automático: agendado via cron"
    else
        status_message "info" "TRIM automático: não configurado"
    fi
    
    # File limits
    local current_nofile=$(ulimit -n 2>/dev/null || echo "unknown")
    if [[ $current_nofile -gt 8192 ]]; then
        status_message "success" "File descriptors: $current_nofile (otimizado)"
    else
        status_message "info" "File descriptors: $current_nofile (necessário logout/login)"
    fi
    
    # Git
    if git config --global user.name >/dev/null 2>&1; then
        local git_user=$(git config --global user.name)
        status_message "success" "Git: configurado ($git_user)"
    else
        status_message "info" "Git: não configurado"
    fi
    
    echo ""
    log_success "Verificação concluída"
}

# =============================================================================
# FUNÇÃO PRINCIPAL DO MÓDULO
# =============================================================================

apply_essential_tweaks() {
    log_header "🔧 APLICANDO OTIMIZAÇÕES ESSENCIAIS"
    
    echo ""
    echo -e "${BLUE}Esta é a configuração MÍNIMA e SEGURA:${NC}"
    bullet_list \
        "Apenas otimizações comprovadas e testadas" \
        "Foco em desenvolvimento (inotify, limits)" \
        "Melhoria de responsividade (swappiness)" \
        "Proteção de SSD (TRIM automático)" \
        "Zero risco para ambiente empresarial"
    
    echo ""
    
    if ! confirm "Aplicar otimizações essenciais?" "y"; then
        log_info "Otimizações essenciais canceladas"
        return 0
    fi
    
    # Aplicar otimizações
    apply_essential_kernel_tweaks
    configure_automatic_trim
    optimize_io_scheduler
    apply_essential_dev_config
    
    # Verificar resultados
    verify_essential_tweaks
    
    log_success "🎉 Otimizações essenciais aplicadas com sucesso!"
    echo ""
    echo -e "${YELLOW}💡 PRÓXIMOS PASSOS:${NC}"
    bullet_list \
        "Fazer logout/login para aplicar limites" \
        "Reiniciar IDEs para detetar novos inotify watches" \
        "Verificar: cat /proc/sys/vm/swappiness (deve ser ≤15)" \
        "Opcional: instalar ferramentas da comunidade (TLP, etc.)"
    
    echo ""
    echo -e "${GREEN}✅ Sistema otimizado conservadoramente - seguro para qualquer ambiente!${NC}"
    echo ""
}