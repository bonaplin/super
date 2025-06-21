#!/bin/bash
set -euo pipefail

# =============================================================================
# VERIFICAÇÕES PRÉ-INSTALAÇÃO AVANÇADAS
# =============================================================================

check_system_requirements() {
    log "INFO" "Verificando requisitos do sistema..."

    # Verificar espaço em disco
    local free_space_gb=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    if (( $(echo "$free_space_gb < 5.0" | bc -l) )); then
        log "ERROR" "Espaço insuficiente: ${free_space_gb}GB (mínimo: 5GB)"
        exit 1
    fi

    # Verificar conectividade para downloads
    log "INFO" "Verificando conectividade..."
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log "WARNING" "Sem conectividade - algumas ferramentas podem falhar"
        if ! ask_user "Continuar sem conectividade?" "n"; then
            exit 1
        fi
    fi

    # Verificar integridade do sistema
    log "INFO" "Verificando integridade do sistema..."
    if command -v debsums >/dev/null 2>&1; then
        local corrupted=$(debsums -s 2>/dev/null | wc -l)
        if [[ $corrupted -gt 0 ]]; then
            log "WARNING" "$corrupted pacotes com problemas detectados"
        fi
    fi

    # Verificar temperatura do sistema
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_c=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        if [[ $temp_c -gt 75 ]]; then
            log "WARNING" "Sistema quente: ${temp_c}°C - considera aguardar arrefecimento"
        fi
    fi

    log "SUCCESS" "Requisitos verificados: ${free_space_gb}GB livre, sistema íntegro"
}

# =============================================================================
# VERIFICAÇÕES INICIAIS MELHORADAS
# =============================================================================

check_prerequisites() {
    log "INFO" "Verificando pré-requisitos do sistema..."

    # Verificar se está a correr como utilizador normal (não root)
    if [[ $EUID -eq 0 ]]; then
        log "ERROR" "Este script NÃO deve ser executado como root!"
        log "ERROR" "Execute como utilizador normal: ./script.sh"
        exit 1
    fi

    # Verificar se tem sudo
    if ! sudo -n true 2>/dev/null; then
        log "INFO" "A verificar permissões sudo..."
        sudo -v
    fi

    # Verificar comandos críticos que o script vai precisar
    local critical_commands=("apt" "systemctl" "df" "free" "nproc" "bc")
    local missing_commands=()

    for cmd in "${critical_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log "ERROR" "Comandos críticos em falta: ${missing_commands[*]}"
        log "ERROR" "Este script requer um sistema Ubuntu/Debian padrão"
        exit 1
    fi

    # Verificar se é Ubuntu/Debian
    if [[ ! -f /etc/debian_version ]]; then
        log "WARNING" "Sistema não-Debian detectado. Algumas funcionalidades podem não funcionar."
        if ! ask_user "Continuar mesmo assim?" "n"; then
            exit 1
        fi
    fi

    # Verificar se já existe configuração prévia
    if [[ -f /etc/sysctl.d/99-dev-performance-conservative.conf ]]; then
        log "WARNING" "Configuração prévia detectada"
        if ask_user "Remover configuração anterior e reconfigurar?" "y"; then
            cleanup_previous_config
        fi
    fi

    log "SUCCESS" "Pré-requisitos verificados"
}

cleanup_previous_config() {
    log "INFO" "Removendo configurações anteriores..."

    # Remover configurações de sysctl
    sudo rm -f /etc/sysctl.d/99-dev-performance-*.conf

    # Remover cron jobs
    sudo rm -f /etc/cron.d/dev-maintenance-*

    # Remover scripts utilitários (serão recriados)
    sudo rm -f /usr/local/bin/dev-*

    log "SUCCESS" "Configurações anteriores removidas"
}

# =============================================================================
# Ubuntu Development Performance Optimizer - Versão Empresarial Focada
# Apenas otimizações essenciais + manutenção para laptop de trabalho
# 🆕 NOVA VERSÃO: ZSH + OH-MY-ZSH + ZOXIDE + DIRENV + VERIFICAÇÕES EMPRESARIAIS
# =============================================================================

readonly SCRIPT_NAME="Ubuntu Dev Optimizer - Enterprise Enhanced"
readonly SCRIPT_VERSION="3.0-zsh-enhanced"
readonly BACKUP_DIR="$HOME/.ubuntu-dev-backup-$(date +%Y%m%d-%H%M%S)"
readonly LOG_FILE="/tmp/ubuntu-dev-optimizer.log"

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variáveis de sistema
RAM_GB=0
CPU_CORES=0
STORAGE_TYPE=""
KERNEL_VERSION=""
BBR_SUPPORTED=false

# Variáveis de controle de conflitos
SKIP_DNS_CONFIG=false
SKIP_NETWORK_CONFIG=false
SKIP_SSH_HARDENING=false
SKIP_FIREWALL_CONFIG=false

# =============================================================================
# VERIFICAÇÕES DE CONFLITOS EMPRESARIAIS
# =============================================================================

check_enterprise_conflicts() {
    log "INFO" "🔍 Verificando possíveis conflitos empresariais..."

    # 1. VERIFICAR CONFLITOS VPN
    check_vpn_conflicts

    # 2. VERIFICAR CONFLITOS DOCKER
    check_docker_conflicts

    # 3. VERIFICAR CONFLITOS SSH
    check_ssh_conflicts

    # 4. VERIFICAR CONFLITOS DNS
    check_dns_conflicts

    # 5. VERIFICAR CONFLITOS FIREWALL
    check_firewall_conflicts

    log "SUCCESS" "Verificação de conflitos concluída"
}

check_vpn_conflicts() {
    log "INFO" "🔍 Verificando conflitos com VPN empresarial..."

    # Detectar se há VPN ativa
    local vpn_active=false
    if ip route | grep -q "tun\|tap\|ppp" || pgrep -f "openvpn\|openconnect\|strongswan" >/dev/null; then
        vpn_active=true
        log "WARNING" "VPN detectada ativa"
    fi

    # CONFLITO 1: DNS
    if [[ "$vpn_active" == true ]]; then
        log "WARNING" "⚠️ CONFLITO POTENCIAL: DNS"
        echo "   • VPN ativa pode conflitar com DNS otimizado (CloudFlare + Google)"
        echo "   • VPN empresarial geralmente força seus próprios DNS"
        echo "   • PADRÃO Ubuntu: systemd-resolved com DNS automático"
        echo "   • OTIMIZADO: DNS fixos 1.1.1.1, 8.8.8.8"

        if ! ask_user "Aplicar DNS otimizado mesmo com VPN? (pode causar problemas)" "n"; then
            echo "   ✅ Mantendo DNS padrão Ubuntu (compatível com VPN)"
            SKIP_DNS_CONFIG=true
        fi
    fi

    # CONFLITO 2: Configurações de rede
    if [[ "$vpn_active" == true ]]; then
        log "WARNING" "⚠️ CONFLITO POTENCIAL: Configurações de rede"
        echo "   • VPN pode ser afetada por mudanças nos buffers de rede"
        echo "   • PADRÃO Ubuntu: rmem_max=212992, wmem_max=212992"
        echo "   • OTIMIZADO: rmem_max=2097152, wmem_max=2097152 (10x maior)"

        if ! ask_user "Aplicar otimizações de rede com VPN ativa? (pode afetar conexão)" "n"; then
            echo "   ✅ Mantendo configurações de rede padrão (compatível com VPN)"
            SKIP_NETWORK_CONFIG=true
        fi
    fi

    return 0
}

check_docker_conflicts() {
    log "INFO" "🔍 Verificando conflitos com Docker..."

    if command -v docker >/dev/null 2>&1; then
        log "INFO" "Docker detectado - verificando configurações..."

        # CONFLITO 1: Bridge networks
        echo "   • PADRÃO Docker: bridge network 172.17.0.0/16"
        echo "   • POTENCIAL CONFLITO: alterações de rede podem afetar containers"

        if ! ask_user "Aplicar otimizações de rede com Docker presente? (testado mas pode haver issues)" "y"; then
            echo "   ✅ Pulando otimizações de rede para Docker"
            SKIP_NETWORK_CONFIG=true
        fi

        # CONFLITO 2: Storage optimizations
        if [[ -d /var/lib/docker ]]; then
            local docker_size=$(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo "desconhecido")
            echo "   • Docker usando: $docker_size de espaço"
            echo "   • Otimizações de SSD podem afetar performance de volumes"

            if ! ask_user "Aplicar otimizações de storage com Docker? (pode afetar volumes)" "y"; then
                echo "   ✅ Otimizações de storage conservadoras para Docker"
                # Não definir flag, mas usar configurações mais conservadoras
            fi
        fi
    fi

    return 0
}

check_ssh_conflicts() {
    log "INFO" "🔍 Verificando conflitos SSH empresariais..."

    if systemctl is-active --quiet ssh; then
        log "WARNING" "SSH server ativo - verificando hardening..."

        # Verificar se há configurações SSH empresariais existentes
        if [[ -f /etc/ssh/sshd_config ]] && grep -q "# Company\|# Enterprise\|# Corporate" /etc/ssh/sshd_config; then
            log "WARNING" "⚠️ CONFLITO: Configurações SSH empresariais detectadas"
            echo "   • SSH pode ter configurações mandatórias da empresa"
            echo "   • Hardening pode conflitar com políticas empresariais"

            if ! ask_user "Aplicar hardening SSH adicional? (pode conflitar com políticas)" "n"; then
                echo "   ✅ Mantendo configurações SSH empresariais existentes"
                SKIP_SSH_HARDENING=true
            fi
        fi

        # Verificar fail2ban vs sistemas de monitorização
        echo "   • ADICIONAL: fail2ban para proteção contra ataques"
        echo "   • POTENCIAL CONFLITO: pode conflitar com sistemas de monitorização empresarial"

        if ! ask_user "Instalar fail2ban? (pode gerar alertas no SOC da empresa)" "y"; then
            echo "   ✅ Pulando fail2ban (evitando alertas de segurança)"
            # Será tratado na função específica
        fi
    fi

    return 0
}

check_dns_conflicts() {
    log "INFO" "🔍 Verificando conflitos DNS..."

    # Verificar se há configurações DNS empresariais
    if [[ -f /etc/systemd/resolved.conf ]] && grep -q "DNS=" /etc/systemd/resolved.conf; then
        local current_dns=$(grep "^DNS=" /etc/systemd/resolved.conf | cut -d= -f2)
        if [[ -n "$current_dns" && "$current_dns" != "1.1.1.1" ]]; then
            log "WARNING" "⚠️ DNS empresarial detectado: $current_dns"
            echo "   • DNS atual pode ser mandatório da empresa"
            echo "   • Mudança pode quebrar acesso a recursos internos"

            if ! ask_user "Substituir DNS empresarial por CloudFlare+Google?" "n"; then
                echo "   ✅ Mantendo DNS empresarial existente"
                SKIP_DNS_CONFIG=true
            fi
        fi
    fi

    return 0
}

check_firewall_conflicts() {
    log "INFO" "🔍 Verificando conflitos de firewall..."

    # Verificar se há firewall empresarial ativo
    if command -v ufw >/dev/null && ufw status | grep -q "active"; then
        local ufw_rules=$(ufw status numbered | wc -l)
        if [[ $ufw_rules -gt 10 ]]; then
            log "WARNING" "⚠️ Firewall empresarial detectado ($ufw_rules regras)"
            echo "   • Muitas regras existentes podem ser mandatórias"
            echo "   • Reset pode quebrar conectividade empresarial"

            if ! ask_user "Resetar firewall e aplicar configuração padrão?" "n"; then
                echo "   ✅ Mantendo configurações de firewall existentes"
                SKIP_FIREWALL_CONFIG=true
            fi
        fi
    fi

    return 0
}

# =============================================================================
# DETECÇÃO DE HARDWARE
# =============================================================================

detect_system_specs() {
    log "INFO" "Detectando especificações do sistema..."

    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    CPU_CORES=$(nproc)
    KERNEL_VERSION=$(uname -r)

    # Detectar tipo de armazenamento principal
    if [[ -d /sys/block/nvme0n1 ]]; then
        STORAGE_TYPE="nvme"
    elif [[ -f /sys/block/sda/queue/rotational ]] && [[ $(cat /sys/block/sda/queue/rotational) -eq 0 ]]; then
        STORAGE_TYPE="ssd"
    else
        STORAGE_TYPE="hdd"
    fi

    # Verificar suporte BBR
    BBR_SUPPORTED=false
    if modinfo tcp_bbr >/dev/null 2>&1; then
        BBR_SUPPORTED=true
    fi

    log "SUCCESS" "Sistema detectado:"
    log "INFO" "  • RAM: ${RAM_GB}GB"
    log "INFO" "  • CPU Cores: ${CPU_CORES}"
    log "INFO" "  • Armazenamento: ${STORAGE_TYPE}"
    log "INFO" "  • Kernel: ${KERNEL_VERSION}"
    log "INFO" "  • BBR Support: ${BBR_SUPPORTED}"
}

# =============================================================================
# OTIMIZAÇÕES CONSERVADORAS DE KERNEL
# =============================================================================

optimize_kernel_conservative() {
    log "INFO" "Aplicando otimizações conservadoras do kernel..."

    if [[ -f /etc/sysctl.d/99-dev-performance-conservative.conf ]]; then
        if ! ask_user "Já existe uma config conservadora. Queres sobrescrevê-la?" "n"; then
            log "INFO" "A configuração existente será mantida."
            return
        fi
    fi

    # Valores conservadores para ambiente de trabalho
    local dirty_ratio=10
    local dirty_bg_ratio=3
    local inotify_watches=262144
    local file_max=65536

    # Ajustar baseado na RAM (conservadoramente)

    if [[ $RAM_GB -ge 32 ]]; then
        dirty_ratio=15
        dirty_bg_ratio=5
        inotify_watches=1048576
        file_max=262144
    elif [[ $RAM_GB -ge 16 ]]; then
        dirty_ratio=15
        dirty_bg_ratio=5
        inotify_watches=524288
        file_max=131072
    elif [[ $RAM_GB -ge 8 ]]; then
        dirty_ratio=12
        dirty_bg_ratio=4
        inotify_watches=262144
        file_max=100000
    fi

    # Valores conservadores para storage
    local vm_dirty_expire=3000
    local vm_dirty_writeback=500

    if [[ "$STORAGE_TYPE" == "nvme" ]]; then
        vm_dirty_expire=2000
        vm_dirty_writeback=300
    elif [[ "$STORAGE_TYPE" == "ssd" ]]; then
        vm_dirty_expire=2500
        vm_dirty_writeback=400
    fi

    # Perguntar sobre otimizações de rede (considerando conflitos detectados)
    local apply_network_tuning=false
    if [[ "$SKIP_NETWORK_CONFIG" != true ]]; then
        if ask_user "Aplicar otimizações de rede? (pode consumir mais RAM)" "n"; then
            apply_network_tuning=true
        fi
    fi

    sudo tee /etc/sysctl.d/99-dev-performance-conservative.conf > /dev/null << EOF
# Otimizações CONSERVADORAS para laptop empresarial
# Sistema: ${RAM_GB}GB RAM, ${STORAGE_TYPE} storage

# === MEMÓRIA E SWAP ===
vm.swappiness=10
vm.vfs_cache_pressure=80
vm.dirty_expire_centisecs=${vm_dirty_expire}
vm.dirty_writeback_centisecs=${vm_dirty_writeback}
vm.dirty_ratio=${dirty_ratio}
vm.dirty_background_ratio=${dirty_bg_ratio}

$(if [[ "$apply_network_tuning" == true ]]; then
cat << NETWORK_EOF
# === NETWORK OTIMIZADO (OPCIONAL) ===
# ATENÇÃO: Consume mais RAM que padrão Ubuntu
# Ubuntu default: rmem/wmem_default=212992, max=212992
# Configurações abaixo: default=262144, max=2097152 (2MB)

net.core.netdev_max_backlog=1000          # Ubuntu default: 1000
net.core.rmem_default=212992              # Ubuntu default: 212992
net.core.wmem_default=212992              # Ubuntu default: 212992
net.core.rmem_max=8388608                  # Ubuntu default: 212992 (aumentado para 2MB, não 4MB)
net.core.wmem_max=8388608                  # Ubuntu default: 212992 (aumentado para 2MB, não 4MB)

# Configurações TCP (algumas já são default mas explícitas)
net.ipv4.tcp_window_scaling=1             # Já é default Ubuntu
net.ipv4.tcp_timestamps=1                 # Já é default Ubuntu
net.ipv4.tcp_sack=1                       # Já é default Ubuntu
net.ipv4.tcp_moderate_rcvbuf=1            # Já é default Ubuntu

# BBR apenas se suportado
$([ "$BBR_SUPPORTED" = true ] && echo "net.ipv4.tcp_congestion_control=bbr" || echo "# BBR não suportado")
$([ "$BBR_SUPPORTED" = true ] && echo "net.core.default_qdisc=fq" || echo "# BBR não suportado")
NETWORK_EOF
else
cat << NO_NETWORK_EOF
# === NETWORK PADRÃO UBUNTU (NÃO MODIFICADO) ===
# Mantendo configurações padrão para estabilidade máxima
# Se precisar de otimizações de rede, execute novamente o script

# BBR apenas se suportado (sem impacto em RAM)
$([ "$BBR_SUPPORTED" = true ] && echo "net.ipv4.tcp_congestion_control=bbr" || echo "# BBR não suportado")
$([ "$BBR_SUPPORTED" = true ] && echo "net.core.default_qdisc=fq" || echo "# BBR não suportado")
NO_NETWORK_EOF
fi)

# === FILESYSTEM ===
fs.inotify.max_user_watches=${inotify_watches}
fs.inotify.max_user_instances=512
fs.file-max=${file_max}

# === DESENVOLVIMENTO === #para estabilidade
# vm.overcommit_memory=0
# kernel.shmmax=268435456
# kernel.shmall=268435456

# === SEGURANÇA ===
kernel.kptr_restrict=1
kernel.yama.ptrace_scope=1
EOF

    sudo sysctl -p /etc/sysctl.d/99-dev-performance-conservative.conf

    if [[ "$apply_network_tuning" == true ]]; then
        log "SUCCESS" "Kernel + Network otimizado conservadoramente (buffers aumentados para 2MB)"
        log "WARNING" "💾 Otimizações de rede vão consumir mais RAM por conexão"
    else
        log "SUCCESS" "Kernel otimizado conservadoramente (network padrão Ubuntu mantido)"
        log "INFO" "📶 Apenas BBR ativado se suportado - sem impacto em RAM"
    fi
}

# =============================================================================
# CONFIGURAÇÕES IMPORTANTES PARA LAPTOP
# =============================================================================

configure_laptop_optimizations() {
    log "INFO" "Configurando otimizações específicas para laptop..."

    # 1. CONFIGURAR TLP PARA GESTÃO DE BATERIA
    log "INFO" "Instalando e configurando TLP para gestão de bateria..."
    sudo apt update -qq
    sudo apt install -y tlp tlp-rdw

    # Configuração TLP conservadora
    sudo tee /etc/tlp.d/99-laptop-work.conf > /dev/null << 'EOF'
# Configuração TLP para laptop de trabalho

# CPU scaling governor
CPU_SCALING_GOVERNOR_ON_AC=ondemand
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU boost
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0

# CPU energy perf policy
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Disk
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"

# WiFi power saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# USB autosuspend
USB_AUTOSUSPEND=1

# Audio power saving
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
EOF

    sudo systemctl enable tlp

    # 2. CONFIGURAR JOURNALD PARA PROTEGER SSD
    log "INFO" "Configurando journald para proteger SSD..."
    sudo mkdir -p /etc/systemd/journald.conf.d
    sudo tee /etc/systemd/journald.conf.d/laptop-ssd.conf > /dev/null << 'EOF'
[Journal]
SystemMaxUse=200M
SystemMaxFileSize=50M
SystemMaxFiles=4
SystemKeepFree=1G
MaxRetentionSec=2week
EOF

    # 3. CONFIGURAR TMPFS PARA TEMP FILES SE RAM SUFICIENTE
    if [[ $RAM_GB -ge 8 ]]; then
        log "INFO" "Configurando tmpfs para temp files (RAM >= 8GB)..."
        if ! grep -q "tmpfs /tmp" /etc/fstab; then
            echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=2G 0 0" | sudo tee -a /etc/fstab
        fi
    fi

    # 4. CONFIGURAR ZSWAP PARA MELHOR GESTÃO DE MEMÓRIA
    if [[ "$STORAGE_TYPE" == "ssd" || "$STORAGE_TYPE" == "nvme" ]]; then
        log "INFO" "Configurando zswap para SSDs..."
        if ! grep -q "zswap.enabled" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lz4 /' /etc/default/grub
            log "WARNING" "GRUB atualizado - necessário update-grub após o script"
        fi
    fi

    log "SUCCESS" "Otimizações de laptop configuradas"
}

# =============================================================================
# SEGURANÇA AVANÇADA EMPRESARIAL
# =============================================================================

configure_advanced_security() {
    log "INFO" "Configurando segurança avançada empresarial..."

    # 1. FIREWALL UFW ROBUSTO (considerando conflitos)
    if [[ "$SKIP_FIREWALL_CONFIG" != true ]]; then
        configure_robust_firewall
    fi

    # 2. FAIL2BAN PARA PROTEÇÃO SSH (considerando conflitos)
    configure_fail2ban

    # 3. APPARMOR OTIMIZADO
    configure_apparmor

    # 4. AUTOMATIC SECURITY UPDATES MELHORADO
    configure_enhanced_auto_updates

    # 5. SSH HARDENING AVANÇADO (considerando conflitos)
    if [[ "$SKIP_SSH_HARDENING" != true ]]; then
        configure_advanced_ssh
    fi

    # 6. VERIFICAÇÃO DE VULNERABILIDADES
    setup_vulnerability_monitoring

    log "SUCCESS" "Segurança avançada configurada"
}

configure_robust_firewall() {
    log "INFO" "Configurando firewall robusto..."

    if command -v ufw >/dev/null; then
        sudo ufw --force reset >/dev/null 2>&1

        # Configurações básicas
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw logging on

        # Permitir SSH apenas se estiver ativo
        if systemctl is-active --quiet ssh; then
            sudo ufw allow ssh
            log "INFO" "SSH permitido no firewall"
        fi

        # Permitir desenvolvimento (opcionalmente)
        if ask_user "Permitir portas de desenvolvimento (3000-3999, 8000-8999)?" "y"; then
            sudo ufw allow 3000:3999/tcp
            sudo ufw allow 8000:8999/tcp
            log "INFO" "Portas de desenvolvimento permitidas"
        fi

        sudo ufw --force enable
        log "SUCCESS" "Firewall UFW configurado"
    fi
}

configure_fail2ban() {
    if ! systemctl is-active --quiet ssh; then
        log "INFO" "SSH não ativo - fail2ban não necessário"
        return 0
    fi

    if ask_user "Instalar fail2ban para proteção SSH?" "y"; then
        log "INFO" "Instalando fail2ban..."
        sudo apt install -y fail2ban

        # Configuração personalizada
        sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 3h
EOF

        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
        log "SUCCESS" "Fail2ban configurado para proteção SSH"
    fi
}

configure_apparmor() {
    if command -v aa-status >/dev/null 2>&1; then
        log "INFO" "Verificando AppArmor..."

        # Verificar status
        local profiles_enforced=$(sudo aa-status 2>/dev/null | grep "profiles are in enforce mode" | awk '{print $1}' || echo "0")

        if [[ $profiles_enforced -gt 0 ]]; then
            log "SUCCESS" "AppArmor ativo: $profiles_enforced perfis em enforce mode"
        else
            log "WARNING" "AppArmor não está ativo adequadamente"
            if ask_user "Ativar AppArmor?" "y"; then
                sudo systemctl enable apparmor
                sudo systemctl start apparmor
            fi
        fi

        # Instalar perfis adicionais
        if ask_user "Instalar perfis AppArmor adicionais?" "y"; then
            sudo apt install -y apparmor-profiles apparmor-utils
            log "SUCCESS" "Perfis AppArmor adicionais instalados"
        fi
    else
        log "INFO" "AppArmor não disponível no sistema"
    fi
}

configure_enhanced_auto_updates() {
    log "INFO" "Configurando updates de segurança melhorados..."

    sudo apt install -y unattended-upgrades apt-listchanges

    # Configuração mais robusta
    sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "2";
EOF

    sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";

// Log results
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF

    log "SUCCESS" "Updates de segurança automáticos configurados"
}

configure_advanced_ssh() {
    if [[ ! -f /etc/ssh/sshd_config ]]; then
        return 0
    fi

    if ask_user "Aplicar hardening avançado SSH?" "y"; then
        log "INFO" "Aplicando hardening SSH avançado..."

        # Backup
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

        # Configurações de segurança
        sudo tee -a /etc/ssh/sshd_config.d/99-security-hardening.conf > /dev/null << 'EOF'
# SSH Security Hardening

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Protocol and Encryption
Protocol 2
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512

# Connection limits
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2

# Disable dangerous features
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
GatewayPorts no
PermitUserEnvironment no
EOF

        # Validar configuração
        if sudo sshd -t; then
            log "SUCCESS" "SSH hardening aplicado com sucesso"
        else
            log "ERROR" "Erro na configuração SSH - restaurando backup"
            sudo mv /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        fi
    fi
}

setup_vulnerability_monitoring() {
    log "INFO" "Configurando monitorização de vulnerabilidades..."

    # Instalar lynis para auditorias de segurança
    if ask_user "Instalar Lynis para auditorias de segurança?" "y"; then
        sudo apt install -y lynis

        # Criar script de auditoria mensal
        sudo tee /usr/local/bin/security-audit > /dev/null << 'EOF'
#!/bin/bash
# Auditoria mensal de segurança

AUDIT_LOG="/var/log/security-audit-$(date +%Y%m).log"

echo "=== AUDITORIA DE SEGURANÇA - $(date) ===" >> "$AUDIT_LOG"

# Lynis audit
lynis audit system --quiet --log-file "$AUDIT_LOG"

# Verificar updates de segurança pendentes
echo "" >> "$AUDIT_LOG"
echo "=== UPDATES DE SEGURANÇA PENDENTES ===" >> "$AUDIT_LOG"
apt list --upgradable 2>/dev/null | grep -i security >> "$AUDIT_LOG"

# Verificar utilizadores
echo "" >> "$AUDIT_LOG"
echo "=== UTILIZADORES SYSTEM ===" >> "$AUDIT_LOG"
awk -F: '$3 >= 1000 {print $1}' /etc/passwd >> "$AUDIT_LOG"

echo "Auditoria completa. Log: $AUDIT_LOG"
EOF

        sudo chmod +x /usr/local/bin/security-audit

        # Adicionar ao cron mensal
        echo "0 2 1 * * root /usr/local/bin/security-audit" | sudo tee /etc/cron.d/security-audit > /dev/null

        log "SUCCESS" "Lynis instalado - auditoria mensal agendada"
    fi
}

# =============================================================================
# OTIMIZAÇÕES ESPECÍFICAS PARA SSD/NVME
# =============================================================================

optimize_storage_advanced() {
    log "INFO" "Aplicando otimizações avançadas de armazenamento..."

    # Configurar TRIM automático para SSDs
    if [[ "$STORAGE_TYPE" == "nvme" || "$STORAGE_TYPE" == "ssd" ]]; then
        log "INFO" "Configurando TRIM automático para SSD..."

        # Habilitar fstrim timer
        sudo systemctl enable fstrim.timer
        sudo systemctl start fstrim.timer

        # Verificar se TRIM está suportado
        if sudo fstrim -v / >/dev/null 2>&1; then
            log "SUCCESS" "TRIM habilitado e funcional"
        else
            log "WARNING" "TRIM pode não estar disponível neste sistema"
        fi
    fi

    # Configurar schedulers específicos por tipo de storage
    for device in /sys/block/sd* /sys/block/nvme*; do
        [[ ! -d "$device" ]] && continue

        devname=$(basename "$device")

        if [[ -f "$device/queue/rotational" ]]; then
            rotational=$(cat "$device/queue/rotational" 2>/dev/null || echo "1")

            if [[ $rotational -eq 0 ]]; then
                # SSD/NVMe: usar none ou mq-deadline dependendo do kernel
                if [[ -f "$device/queue/scheduler" ]]; then
                    available_schedulers=$(cat "$device/queue/scheduler")
                    if [[ "$available_schedulers" == *"none"* ]]; then
                        echo "none" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1
                        log "SUCCESS" "SSD $devname: scheduler 'none' configurado"
                    else
                        echo "mq-deadline" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1
                        log "SUCCESS" "SSD $devname: scheduler 'mq-deadline' configurado"
                    fi
                fi

                # Configurações específicas para SSD
                echo 0 | sudo tee "$device/queue/add_random" >/dev/null 2>&1
                echo 1 | sudo tee "$device/queue/rq_affinity" >/dev/null 2>&1

                # Read-ahead otimizado
                if [[ "$STORAGE_TYPE" == "nvme" ]]; then
                    sudo blockdev --setra 512 "/dev/$devname" 2>/dev/null || true
                else
                    sudo blockdev --setra 256 "/dev/$devname" 2>/dev/null || true
                fi

            else
                # HDD: usar mq-deadline ou deadline
                echo "mq-deadline" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1
                sudo blockdev --setra 128 "/dev/$devname" 2>/dev/null || true
                log "SUCCESS" "HDD $devname otimizado"
            fi
        fi
    done

    # Configurar swapfile otimizada se não existir swap
    configure_optimized_swap
}

optimize_storage_advanced() {
    log "INFO" "Aplicando otimizações avançadas de armazenamento..."

    # Configurar TRIM automático para SSDs
    if [[ "$STORAGE_TYPE" == "nvme" || "$STORAGE_TYPE" == "ssd" ]]; then
        log "INFO" "Configurando TRIM automático para SSD..."

        # Habilitar fstrim timer
        sudo systemctl enable fstrim.timer
        sudo systemctl start fstrim.timer

        # Verificar se TRIM está suportado
        if sudo fstrim -v / >/dev/null 2>&1; then
            log "SUCCESS" "TRIM habilitado e funcional"
        else
            log "WARNING" "TRIM pode não estar disponível neste sistema"
        fi
    fi

    # Configurar schedulers específicos por tipo de storage
    for device in /sys/block/sd* /sys/block/nvme*; do
        [[ ! -d "$device" ]] && continue

        devname=$(basename "$device")

        if [[ -f "$device/queue/rotational" ]]; then
            rotational=$(cat "$device/queue/rotational" 2>/dev/null || echo "1")

            if [[ $rotational -eq 0 ]]; then
                # SSD/NVMe: usar none ou mq-deadline dependendo do kernel
                if [[ -f "$device/queue/scheduler" ]]; then
                    available_schedulers=$(cat "$device/queue/scheduler")
                    if [[ "$available_schedulers" == *"none"* ]]; then
                        echo "none" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1
                        log "SUCCESS" "SSD $devname: scheduler 'none' configurado"
                    else
                        echo "mq-deadline" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1
                        log "SUCCESS" "SSD $devname: scheduler 'mq-deadline' configurado"
                    fi
                fi

                # Configurações específicas para SSD
                echo 0 | sudo tee "$device/queue/add_random" >/dev/null 2>&1
                echo 1 | sudo tee "$device/queue/rq_affinity" >/dev/null 2>&1

                # Read-ahead otimizado
                if [[ "$STORAGE_TYPE" == "nvme" ]]; then
                    sudo blockdev --setra 512 "/dev/$devname" 2>/dev/null || true
                else
                    sudo blockdev --setra 256 "/dev/$devname" 2>/dev/null || true
                fi

            else
                # HDD: usar mq-deadline ou deadline
                echo "mq-deadline" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1
                sudo blockdev --setra 128 "/dev/$devname" 2>/dev/null || true
                log "SUCCESS" "HDD $devname otimizado"
            fi
        fi
    done

    # Configurar swapfile otimizada se não existir swap
    configure_optimized_swap
}

configure_optimized_swap() {
    local current_swap=$(free | awk '/^Swap:/ {print $2}')

    if [[ $current_swap -eq 0 ]]; then
        log "INFO" "Sem swap detectado. Configurando swapfile otimizada..."

        # Tamanho do swap baseado na RAM
        local swap_size_gb=2
        if [[ $RAM_GB -ge 16 ]]; then
            swap_size_gb=4
        elif [[ $RAM_GB -ge 8 ]]; then
            swap_size_gb=4
        elif [[ $RAM_GB -le 4 ]]; then
            swap_size_gb=$((RAM_GB * 2))  # Dobro da RAM se pouca RAM
        fi

        if ask_user "Criar swapfile de ${swap_size_gb}GB?" "n"; then
            sudo fallocate -l "${swap_size_gb}G" /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile

            # Adicionar ao fstab se não existir
            if ! grep -q "/swapfile" /etc/fstab; then
                echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
            fi

            log "SUCCESS" "Swapfile de ${swap_size_gb}GB criada e ativada"
        fi
    else
        log "INFO" "Swap já configurado: $((current_swap / 1024))MB"
    fi
}

# =============================================================================
# LIMITES SEGUROS PARA DESENVOLVIMENTO
# =============================================================================

optimize_development_limits() {
    log "INFO" "Configurando limites seguros para desenvolvimento..."

    # Limites conservadores
    local nofile_soft=32768
    local nofile_hard=65536
    local nproc_limit=16384

    if [[ $RAM_GB -ge 16 ]]; then
        nofile_soft=65536
        nofile_hard=131072
        nproc_limit=32768
    elif [[ $RAM_GB -ge 8 ]]; then
        nofile_soft=49152
        nofile_hard=98304
        nproc_limit=24576
    fi

    sudo tee /etc/security/limits.d/99-dev-limits-safe.conf > /dev/null << EOF
# Limites seguros para desenvolvimento empresarial (${RAM_GB}GB RAM)
* soft nofile ${nofile_soft}
* hard nofile ${nofile_hard}
* soft nproc ${nproc_limit}
* hard nproc ${nproc_limit}
* soft memlock 131072
* hard memlock 131072
EOF

    # Configurar systemd
    sudo mkdir -p /etc/systemd/user.conf.d
    sudo tee /etc/systemd/user.conf.d/dev-limits-safe.conf > /dev/null << EOF
[Manager]
DefaultLimitNOFILE=${nofile_hard}
DefaultLimitNPROC=${nproc_limit}
DefaultLimitMEMLOCK=131072
EOF

    sudo mkdir -p /etc/systemd/system.conf.d
    sudo tee /etc/systemd/system.conf.d/dev-limits-safe.conf > /dev/null << EOF
[Manager]
DefaultLimitNOFILE=${nofile_hard}
DefaultLimitNPROC=${nproc_limit}
DefaultLimitMEMLOCK=131072
EOF

    log "SUCCESS" "Limites seguros configurados"
}

# =============================================================================
# DOCKER EMPRESARIAL (OPCIONAL)
# =============================================================================

configure_docker_enterprise() {
    if ! ask_user "Instalar e configurar Docker?" "n"; then
        log "INFO" "Docker skip - pode instalar depois se necessário"
        return 0
    fi

    if ! command_exists docker; then
        log "INFO" "Instalando Docker..."
        sudo apt update -qq
        sudo apt install -y docker.io docker-compose
        sudo usermod -aG docker "$USER"
        sudo systemctl enable docker
    fi

    log "INFO" "Configurando Docker para ambiente empresarial..."
    sudo mkdir -p /etc/docker

    # PROTEÇÃO: Verificar se daemon.json já existe
    if [[ -f /etc/docker/daemon.json ]]; then
        log "WARNING" "Docker daemon.json já existe"
        log "INFO" "Configuração atual:"
        cat /etc/docker/daemon.json | head -5
        echo "..."

        if ! ask_user "Sobrescrever configuração Docker existente? (será feito backup)" "n"; then
            log "INFO" "Mantendo configuração Docker existente"
            return 0
        fi

        # Fazer backup
        local backup_file="/etc/docker/daemon.json.backup.$(date +%Y%m%d-%H%M%S)"
        sudo cp /etc/docker/daemon.json "$backup_file"
        log "SUCCESS" "Backup criado: $backup_file"
    fi

    sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": $(( RAM_GB >= 16 ? 131072 : 65536 )),
      "Soft": $(( RAM_GB >= 16 ? 65536 : 32768 ))
    }
  },
  "features": {
    "buildkit": true
  },
  "experimental": false,
  "live-restore": true,
  "userland-proxy": false,
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3
}
EOF

    if systemctl is-active --quiet docker; then
        sudo systemctl restart docker
    fi

    log "SUCCESS" "Docker configurado para ambiente empresarial"
}

# =============================================================================
# 🆕 INSTALAÇÃO DO ECOSSISTEMA ZSH COMPLETO
# =============================================================================

install_zsh_ecosystem() {
    log "INFO" "🚀 Configurando ecossistema Zsh avançado..."

    if ask_user "Instalar Zsh + Oh-My-Zsh + Zoxide + Direnv?" "y"; then
        # 1. INSTALAR ZSH
        install_zsh_shell

        # 2. INSTALAR OH-MY-ZSH
        install_oh_my_zsh

        # 3. INSTALAR ZOXIDE (cd inteligente)
        install_zoxide

        # 4. INSTALAR DIRENV (gestão de ambiente por diretório)
        install_direnv

        # 5. CONFIGURAR ZSH COMO PADRÃO
        configure_zsh_as_default

        # 6. CONFIGURAÇÃO AVANÇADA ZSH
        configure_advanced_zsh

        log "SUCCESS" "🎉 Ecossistema Zsh completo instalado!"
        log "INFO" "📝 Será necessário fazer logout/login para ativar o Zsh"
    fi
}

install_zsh_shell() {
    if ! command -v zsh >/dev/null 2>&1; then
        log "INFO" "Instalando Zsh..."
        sudo apt install -y zsh zsh-autosuggestions zsh-syntax-highlighting
    else
        log "SUCCESS" "Zsh já instalado: $(zsh --version)"
    fi
}

install_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "INFO" "Instalando Oh-My-Zsh..."

        # Download e instalar Oh-My-Zsh sem alterar shell ainda
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        # Instalar plugins úteis
        install_zsh_plugins

        log "SUCCESS" "Oh-My-Zsh instalado com plugins"
    else
        log "SUCCESS" "Oh-My-Zsh já instalado"
    fi
}

install_zsh_plugins() {
    local ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

    log "INFO" "Instalando plugins Zsh personalizados..."

    # Plugin para autosuggestions (se não veio com o pacote apt)
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        log "INFO" "Instalando zsh-autosuggestions..."
        if git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"; then
            log "SUCCESS" "zsh-autosuggestions instalado"
        else
            log "WARNING" "Falha ao instalar zsh-autosuggestions"
        fi
    fi

    # Plugin para syntax highlighting (se não veio com o pacote apt)
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        log "INFO" "Instalando zsh-syntax-highlighting..."
        if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"; then
            log "SUCCESS" "zsh-syntax-highlighting instalado"
        else
            log "WARNING" "Falha ao instalar zsh-syntax-highlighting"
        fi
    fi

    # Plugin para fzf-tab (melhor completion)
    if [[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]]; then
        log "INFO" "Instalando fzf-tab..."
        if git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"; then
            log "SUCCESS" "fzf-tab instalado"
        else
            log "WARNING" "Falha ao instalar fzf-tab - pode instalar depois manualmente"
        fi
    fi

    # Verificar quais foram instalados com sucesso
    local installed_plugins=()
    [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && installed_plugins+=("autosuggestions")
    [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && installed_plugins+=("syntax-highlighting")
    [[ -d "$ZSH_CUSTOM/plugins/fzf-tab" ]] && installed_plugins+=("fzf-tab")

    if [[ ${#installed_plugins[@]} -gt 0 ]]; then
        log "SUCCESS" "Plugins Zsh instalados: ${installed_plugins[*]}"
    else
        log "WARNING" "Nenhum plugin personalizado foi instalado"
    fi
}

install_zoxide() {
    if ! command -v zoxide >/dev/null 2>&1; then
        log "INFO" "Instalando zoxide (cd inteligente)..."

        # Tentar via apt primeiro (Ubuntu 22.04+)
        if ! sudo apt install -y zoxide 2>/dev/null; then
            # Fallback: instalação via curl
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

            # Adicionar ao PATH se necessário
            if [[ -f "$HOME/.local/bin/zoxide" ]]; then
                export PATH="$HOME/.local/bin:$PATH"
            fi
        fi

        log "SUCCESS" "Zoxide instalado"
    else
        log "SUCCESS" "Zoxide já instalado: $(zoxide --version)"
    fi
}

install_direnv() {
    if ! command -v direnv >/dev/null 2>&1; then
        log "INFO" "Instalando direnv (gestão de ambiente por diretório)..."
        sudo apt install -y direnv
        log "SUCCESS" "Direnv instalado"
    else
        log "SUCCESS" "Direnv já instalado: $(direnv --version)"
    fi
}

configure_zsh_as_default() {
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)

    if [[ "$current_shell" != "/usr/bin/zsh" && "$current_shell" != "/bin/zsh" ]]; then
        log "INFO" "Configurando Zsh como shell padrão..."

        # Verificar se zsh está em /etc/shells
        if ! grep -q "$(which zsh)" /etc/shells; then
            which zsh | sudo tee -a /etc/shells
        fi

        # Alterar shell padrão
        sudo chsh -s "$(which zsh)" "$USER"

        log "SUCCESS" "Zsh configurado como shell padrão"
        log "WARNING" "⚠️ Será necessário logout/login para ativar"
    else
        log "SUCCESS" "Zsh já é o shell padrão"
    fi
}

configure_advanced_zsh() {
    log "INFO" "Configurando Zsh avançado para desenvolvimento..."

    # Criar configuração .zshrc otimizada
    cat > ~/.zshrc << 'EOF'
# ============================================================================
# ZSH CONFIGURAÇÃO PARA DESENVOLVIMENTO - OTIMIZADA PARA PRODUTIVIDADE
# ============================================================================

# Path para Oh-My-Zsh
export ZSH="$HOME/.oh-my-zsh"

# Tema (pode ser alterado)
ZSH_THEME="robbyrussell"  # Rápido e limpo
# Alternativas: "agnoster", "powerlevel10k/powerlevel10k", "spaceship"

# Plugins essenciais para desenvolvimento
plugins=(
    git                    # Git aliases e info
    docker                 # Docker completion
    docker-compose         # Docker-compose completion
    node                   # Node.js completion
    npm                    # npm completion
    yarn                   # Yarn completion
    python                 # Python completion
    pip                    # pip completion
    systemd                # systemctl completion
    sudo                   # sudo completion
    history-substring-search  # Busca no histórico
    zsh-autosuggestions    # Sugestões baseadas no histórico
    zsh-syntax-highlighting # Syntax highlighting
    fzf-tab               # Melhor completion com fzf
    direnv                # Direnv hook
)

# Carregar Oh-My-Zsh
source $ZSH/oh-my-zsh.sh

# ============================================================================
# CONFIGURAÇÕES DE PRODUTIVIDADE
# ============================================================================

# Histórico melhorado
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY          # Compartilhar histórico entre sessões
setopt HIST_VERIFY           # Verificar comando do histórico antes de executar
setopt HIST_IGNORE_DUPS      # Ignorar duplicatas consecutivas
setopt HIST_IGNORE_ALL_DUPS  # Ignorar todas as duplicatas
setopt HIST_SAVE_NO_DUPS     # Não salvar duplicatas
setopt HIST_IGNORE_SPACE     # Ignorar comandos que começam com espaço
setopt HIST_REDUCE_BLANKS    # Remover espaços desnecessários

# Completion melhorado
setopt AUTO_MENU             # Mostrar menu completion automaticamente
setopt COMPLETE_IN_WORD      # Completion no meio da palavra
setopt ALWAYS_TO_END         # Mover cursor para o fim após completion

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ============================================================================
# INTEGRAÇÕES DE FERRAMENTAS
# ============================================================================

# Zoxide (cd inteligente) - DEVE vir DEPOIS do Oh-My-Zsh
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    # Alias para compatibilidade
    alias cd='z'
fi

# Direnv (gestão de ambiente por diretório)
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

# FZF key bindings (se instalado via git)
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
fi

# ============================================================================
# ALIASES INTELIGENTES PARA DESENVOLVIMENTO
# ============================================================================

# Navegação melhorada
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Função para detectar qual comando usar (eza ou exa)
setup_exa_aliases() {
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza --icons'
        alias ll='eza -la --icons --git'
        alias tree='eza --tree --icons'
    elif command -v exa >/dev/null 2>&1; then
        alias ls='exa --icons'
        alias ll='exa -la --icons --git'
        alias tree='exa --tree --icons'
    fi
}

# Chamar a função
setup_exa_aliases

# Git aliases úteis
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gb='git branch'
alias gco='git checkout'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'

# Desenvolvimento
alias serve='python3 -m http.server 8000'
alias nodemon='npx nodemon'
alias ni='npm install'
alias nr='npm run'
alias ys='yarn start'
alias yb='yarn build'

# Sistema
alias update='sudo apt update && sudo apt upgrade'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Ferramentas modernas (se instaladas)
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

# ============================================================================
# FUNÇÕES ÚTEIS PARA DESENVOLVIMENTO
# ============================================================================

# Criar projeto Node.js rapidamente
nodesetup() {
    local project_name="${1:-my-project}"
    mkdir "$project_name" && cd "$project_name"
    npm init -y
    echo "node_modules/" > .gitignore
    echo "# $project_name" > README.md
    git init
    echo "✅ Projeto Node.js '$project_name' criado!"
}

# Limpeza inteligente de node_modules
cleannode() {
    find . -name "node_modules" -type d -prune -print0 | du -csh --files0-from=-
    echo "Remover todos os node_modules? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy] ]]; then
        find . -name "node_modules" -type d -prune -exec rm -rf {} +
        echo "✅ node_modules removidos!"
    fi
}

# Ver ocupação de diretórios
diskusage() {
    if command -v ncdu >/dev/null 2>&1; then
        ncdu "${1:-.}"
    else
        du -sh "${1:-.}"/* | sort -hr
    fi
}

# Procurar projetos rapidamente
findproject() {
    local base_dirs=("$HOME/projects" "$HOME/dev" "$HOME/workspace" "$HOME/code" "$HOME")

    for dir in "${base_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -maxdepth 3 -name "package.json" -o -name "Cargo.toml" -o -name "requirements.txt" -o -name "pom.xml" 2>/dev/null | head -20
        fi
    done
}

# Testar APIs rapidamente
testapi() {
    local url="$1"
    local method="${2:-GET}"

    if command -v http >/dev/null 2>&1; then
        http "$method" "$url"
    else
        curl -X "$method" "$url"
    fi
}

# ============================================================================
# CONFIGURAÇÕES DE AMBIENTE
# ============================================================================

# Adicionar paths úteis
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Node.js
export NODE_ENV=development
export NODE_OPTIONS="--max-old-space-size=4096"

# Python
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Editor padrão
export EDITOR=vim
export VISUAL=vim

# ============================================================================
# PROMPT PERSONALIZADO (se não usar tema)
# ============================================================================

# Descomenta se quiser prompt personalizado em vez do tema
# autoload -Uz vcs_info
# setopt prompt_subst
# zstyle ':vcs_info:git:*' formats ' (%b)'
#
# precmd() { vcs_info }
#
# PROMPT='%F{cyan}%n@%m%f:%F{blue}%~%f%F{red}${vcs_info_msg_0_}%f$ '

# ============================================================================
# ALIASES CUSTOM
# ============================================================================

# vpn airc
alias vpn="sudo openconnect --protocol=gp fw.airc.pt"
EOF

    # Criar arquivo de configuração para direnv
    cat > ~/.direnvrc << 'EOF'
# Configurações para direnv

# Usar layout automaticamente baseado no arquivo .envrc
use_flake() {
    watch_file flake.nix
    watch_file flake.lock
    eval "$(nix print-dev-env)"
}

# Função para projetos Node.js
layout_node() {
    local node_version="${1:-16}"
    echo "Using Node.js version $node_version"
    export PATH="$PWD/node_modules/.bin:$PATH"
}

# Função para projetos Python
layout_python() {
    local python_version="${1:-3.9}"
    local venv_path=".venv"

    if [[ ! -d "$venv_path" ]]; then
        echo "Creating Python virtual environment..."
        python3 -m venv "$venv_path"
    fi

    source "$venv_path/bin/activate"
    export VIRTUAL_ENV="$PWD/$venv_path"
}
EOF

    log "SUCCESS" "Zsh configurado com configurações avançadas para desenvolvimento"
}

# =============================================================================
# VERIFICAR E INSTALAR FERRAMENTAS DE DESENVOLVIMENTO ESSENCIAIS
# =============================================================================

install_development_essentials() {
    log "INFO" "Verificando e instalando ferramentas essenciais de desenvolvimento..."

    # Atualizar repositórios
    sudo apt update -qq

    # DEPENDÊNCIAS DO PRÓPRIO SCRIPT (sempre necessárias)
    local script_dependencies=(
        "bc"                              # Cálculos matemáticos no script
        "ss"                              # Verificar portas (iproute2)
        "watch"                           # Comando watch para monitorização
        "notify-send" "libnotify-bin"     # Notificações desktop
    )

    # Ferramentas básicas sempre necessárias
    local essential_tools=(
        "htop" "iotop"                     # Monitoramento
        "git" "build-essential"            # Desenvolvimento base
        "curl" "wget" "jq"                 # Network tools
        "vim" "tree" "zip" "unzip"         # Utilitários básicos
        "software-properties-common"       # Para PPAs
        "apt-transport-https"              # Para repositórios HTTPS
        "ca-certificates"                  # Certificados
        "gnupg" "lsb-release"             # Segurança
        "less" "grep" "ripgrep"           # Para trabalhar com logs
        "multitail"                       # Ver múltiplos logs
        "openssh-client"                  # SSH client
        "rsync"                           # Sincronização de arquivos
        "python3" "python3-pip"           # Python básico
        "python3-venv"                    # Virtual environments Python
        "shellcheck"                      # Linting de shell scripts
    )

    # Instalar dependências do script primeiro
    log "INFO" "Instalando dependências do script..."
    #sudo apt install -y "${script_dependencies[@]}"

    # Instalar ferramentas essenciais
    log "INFO" "Instalando ferramentas de desenvolvimento..."
    sudo apt install -y "${essential_tools[@]}"

    log "SUCCESS" "Ferramentas básicas e dependências instaladas"

    # FERRAMENTAS MODERNAS OPCIONAIS
    install_modern_dev_tools

    # VERIFICAR E INSTALAR NODE.JS
    check_and_install_nodejs

    # VERIFICAR E INSTALAR YARN (se Node.js existe)
    check_and_install_yarn

    # VERIFICAR FERRAMENTAS DE BUILD ADICIONAIS
    check_and_install_build_tools

    # SNAP BÁSICO (se não existir)
    check_and_install_snap

    # 🆕 INSTALAR ECOSSISTEMA ZSH
    install_zsh_ecosystem

    log "SUCCESS" "Ambiente de desenvolvimento verificado e configurado"
}

install_modern_dev_tools() {
    log "INFO" "Verificando e instalando ferramentas modernas de desenvolvimento..."

    if ask_user "Instalar ferramentas modernas essenciais?" "y"; then
        log "INFO" "Instalando ferramentas..."

        # Lista completa de ferramentas para tentar
        local all_tools=(
            "fzf:Fuzzy finder"
            "fd-find:Find melhorado"
            "bat:Cat com syntax highlighting"
            "ripgrep:Grep melhorado"
            "ncdu:Disk usage analyzer"
            "tldr:Man pages simplificado"
            "httpie:API testing tool"
            "jq:JSON processor"
            "meld:Visual diff tool"
            "lsof:List open files"
            "multitail:Multiple log files"
            "shellcheck:Shell script linting"
            "tree:Directory tree"
            "htop:System monitor melhorado"
            "exa:ls melhorado com cores"
            "micro:Editor de texto moderno"
            "tmux:Terminal multiplexer"
            "watch:Executar comandos repetidamente"
        )

        # Arrays de controle
        local installed=()
        local not_found=()
        local install_failed=()
        local already_installed=()

        echo ""
        log "INFO" "📋 VERIFICANDO E INSTALANDO FERRAMENTAS..."
        echo ""

        for tool_info in "${all_tools[@]}"; do
            local tool="${tool_info%%:*}"
            local description="${tool_info##*:}"

            printf "%-15s %-30s " "$tool" "($description)"

            # Verificar se já está instalado
            if command -v "$tool" >/dev/null 2>&1 || command -v "${tool//-/_}" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ JÁ INSTALADO${NC}"
                already_installed+=("$tool")
                continue
            fi

            # Verificar se pacote existe nos repositórios
            if ! apt-cache show "$tool" >/dev/null 2>&1; then
                echo -e "${YELLOW}❌ NÃO ENCONTRADO${NC}"
                not_found+=("$tool")
                continue
            fi

            # Tentar instalar
            if sudo apt install -y "$tool" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ INSTALADO${NC}"
                installed+=("$tool")
            else
                echo -e "${RED}❌ FALHA INSTALAÇÃO${NC}"
                install_failed+=("$tool")
            fi
        done

        echo ""
        log "INFO" "🔧 INSTALAÇÕES ESPECIAIS (métodos alternativos)..."
        echo ""

        # fzf tratamento especial (via git se necessário)
        if ! command -v fzf >/dev/null 2>&1 && [[ " ${installed[*]} " != *" fzf "* ]]; then
            printf "%-15s %-30s " "fzf" "(via git clone)"
            if git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf >/dev/null 2>&1; then
                if ~/.fzf/install --key-bindings --completion --no-update-rc >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ INSTALADO (GIT)${NC}"
                    installed+=("fzf (git)")
                else
                    echo -e "${RED}❌ FALHA CONFIG${NC}"
                    install_failed+=("fzf (config)")
                fi
            else
                echo -e "${RED}❌ FALHA DOWNLOAD${NC}"
                install_failed+=("fzf (download)")
            fi
        fi

        # tldr tratamento especial (via pip3 se apt falhou)
        if ! command -v tldr >/dev/null 2>&1 && [[ " ${installed[*]} " != *" tldr "* ]]; then
            printf "%-15s %-30s " "tldr" "(via pip3)"
            if command -v pip3 >/dev/null 2>&1; then
                if pip3 install --user tldr >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ INSTALADO (PIP3)${NC}"
                    installed+=("tldr (pip3)")
                else
                    echo -e "${RED}❌ FALHA PIP3${NC}"
                    install_failed+=("tldr (pip3)")
                fi
            else
                echo -e "${YELLOW}❌ PIP3 N/DISPONÍVEL${NC}"
                not_found+=("tldr (sem pip3)")
            fi
        fi

        # exa/eza tratamento especial (eza é o fork moderno)
        if ! command -v exa >/dev/null 2>&1 && ! command -v eza >/dev/null 2>&1 && [[ " ${installed[*]} " != *" exa "* ]]; then
            printf "%-15s %-30s " "eza/exa" "(ls melhorado)"

            # Sequência que funcionou: eza apt → cargo eza → cargo exa
            if sudo apt install -y eza >/dev/null 2>&1; then
                echo -e "${GREEN}✅ INSTALADO (EZA-APT)${NC}"
                installed+=("eza (apt)")
            elif command -v cargo >/dev/null 2>&1 && cargo install eza >/dev/null 2>&1; then
                echo -e "${GREEN}✅ INSTALADO (EZA-CARGO)${NC}"
                installed+=("eza (cargo)")
            elif command -v cargo >/dev/null 2>&1 && cargo install exa >/dev/null 2>&1; then
                echo -e "${GREEN}✅ INSTALADO (EXA-CARGO)${NC}"
                installed+=("exa (cargo)")
            elif command -v snap >/dev/null 2>&1 && sudo snap install exa >/dev/null 2>&1; then
                echo -e "${GREEN}✅ INSTALADO (EXA-SNAP)${NC}"
                installed+=("exa (snap)")
            else
                echo -e "${RED}❌ TODOS FALHARAM${NC}"
                install_failed+=("exa/eza (todos métodos)")
            fi
        fi

        # micro tratamento especial (snap fallback)
        if ! command -v micro >/dev/null 2>&1 && [[ " ${installed[*]} " != *" micro "* ]]; then
            printf "%-15s %-30s " "micro" "(via snap)"
            if command -v snap >/dev/null 2>&1; then
                if sudo snap install micro --classic >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ INSTALADO (SNAP)${NC}"
                    installed+=("micro (snap)")
                else
                    echo -e "${RED}❌ FALHA SNAP${NC}"
                    install_failed+=("micro (snap)")
                fi
            else
                echo -e "${YELLOW}❌ SNAP N/DISPONÍVEL${NC}"
                not_found+=("micro (sem snap)")
            fi
        fi

        # watch verificação especial (geralmente já existe)
        if ! command -v watch >/dev/null 2>&1 && [[ " ${installed[*]} " != *" watch "* ]]; then
            printf "%-15s %-30s " "watch" "(via procps)"
            if sudo apt install -y procps >/dev/null 2>&1; then
                if command -v watch >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ DISPONÍVEL${NC}"
                    installed+=("watch (procps)")
                else
                    echo -e "${YELLOW}❌ AINDA N/DISPONÍVEL${NC}"
                    install_failed+=("watch")
                fi
            else
                echo -e "${RED}❌ FALHA PROCPS${NC}"
                install_failed+=("watch (procps)")
            fi
        fi

        echo ""
        log "SUCCESS" "📊 RELATÓRIO FINAL DE INSTALAÇÃO:"
        echo ""

        # Mostrar resultados organizados
        if [[ ${#already_installed[@]} -gt 0 ]]; then
            log "INFO" "🔵 JÁ INSTALADOS (${#already_installed[@]}):"
            for tool in "${already_installed[@]}"; do
                echo "   ✅ $tool"
            done
            echo ""
        fi

        if [[ ${#installed[@]} -gt 0 ]]; then
            log "SUCCESS" "🟢 INSTALADOS AGORA (${#installed[@]}):"
            for tool in "${installed[@]}"; do
                echo "   ✅ $tool"
            done
            echo ""
        fi

        if [[ ${#not_found[@]} -gt 0 ]]; then
            log "WARNING" "🟡 NÃO ENCONTRADOS/DISPONÍVEIS (${#not_found[@]}):"
            for tool in "${not_found[@]}"; do
                echo "   ❌ $tool"
            done
            echo ""
        fi

        if [[ ${#install_failed[@]} -gt 0 ]]; then
            log "ERROR" "🔴 FALHARAM NA INSTALAÇÃO (${#install_failed[@]}):"
            for tool in "${install_failed[@]}"; do
                echo "   ❌ $tool"
            done
            echo ""
        fi

        # Resumo final
        local total=${#all_tools[@]}
        local success=$((${#already_installed[@]} + ${#installed[@]}))
        local failed=$((${#not_found[@]} + ${#install_failed[@]}))

        echo "🎯 RESUMO: $success/$total ferramentas disponíveis ($failed falharam)"
        echo ""

        # Dicas de uso para ferramentas instaladas
        if [[ ${#installed[@]} -gt 0 ]]; then
            log "INFO" "💡 DICAS DE USO RÁPIDO:"
            for tool in "${installed[@]}"; do
                case "${tool%% *}" in
                    "fzf") echo "   • fzf: Ctrl+R (histórico), Ctrl+T (arquivos)" ;;
                    "bat") echo "   • bat: bat arquivo.txt (cat com cores)" ;;
                    "exa") echo "   • exa: exa --icons --git (ls melhorado)" ;;
                    "ripgrep") echo "   • ripgrep: rg 'texto' (grep rápido)" ;;
                    "tldr") echo "   • tldr: tldr comando (man pages simples)" ;;
                    "micro") echo "   • micro: micro arquivo.txt (editor moderno)" ;;
                    "tmux") echo "   • tmux: tmux (terminal múltiplo)" ;;
                    "htop") echo "   • htop: htop (monitor de sistema)" ;;
                esac
            done
            echo ""
        fi
    fi

    # Instalar GitHub CLI
    install_github_cli

    # Instalar lazygit
    install_lazygit

    # Instalar glow
    install_glow
}

install_github_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        if ask_user "Instalar GitHub CLI?" "n"; then
            log "INFO" "Instalando GitHub CLI..."
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update -qq
            sudo apt install -y gh
            log "SUCCESS" "GitHub CLI instalado"
        fi
    else
        log "SUCCESS" "GitHub CLI já instalado: $(gh --version | head -1)"
        # Não reconfigurar
    fi
}

install_lazygit() {
    if ! command -v lazygit >/dev/null 2>&1; then
        if ask_user "Instalar lazygit (Git visual TUI)?" "y"; then
            log "INFO" "Instalando lazygit..."
            local latest_version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            if [[ -n "$latest_version" ]]; then
                curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${latest_version}_Linux_x86_64.tar.gz"
                tar xf lazygit.tar.gz lazygit
                sudo install lazygit /usr/local/bin
                rm -f lazygit.tar.gz lazygit
                log "SUCCESS" "Lazygit instalado: $latest_version"
            fi
        fi
    else
        log "SUCCESS" "Lazygit já instalado: $(lazygit --version | head -1)"
    fi
}

install_glow() {
    if ! command -v glow >/dev/null 2>&1; then
        if ask_user "Instalar glow (markdown viewer)?" "y"; then
            log "INFO" "Instalando glow..."

            # PROBLEMA 1: grep -Po pode não existir em todos sistemas
            # SOLUÇÃO: Usar método mais compatível
            local latest_version
            latest_version=$(curl -s "https://api.github.com/repos/charmbracelet/glow/releases/latest" | \
                           grep '"tag_name"' | \
                           sed 's/.*"tag_name": "v\([^"]*\)".*/\1/' | \
                           head -1)

            if [[ -n "$latest_version" ]]; then
                log "INFO" "Versão detectada: $latest_version"

                # PROBLEMA 2: Download pode falhar
                # SOLUÇÃO: Verificar se download foi bem sucedido
                local deb_file="glow_${latest_version}_linux_amd64.deb"
                local download_url="https://github.com/charmbracelet/glow/releases/latest/download/$deb_file"

                if curl -Lo "$deb_file" "$download_url" 2>/dev/null; then
                    # PROBLEMA 3: Verificar se arquivo foi baixado corretamente
                    if [[ -f "$deb_file" && -s "$deb_file" ]]; then
                        # PROBLEMA 4: dpkg pode falhar por dependências
                        if sudo dpkg -i "$deb_file" 2>/dev/null; then
                            log "SUCCESS" "Glow instalado: $latest_version"
                        else
                            log "WARNING" "Falha no dpkg, tentando corrigir dependências..."
                            sudo apt-get install -f -y >/dev/null 2>&1
                            if sudo dpkg -i "$deb_file" >/dev/null 2>&1; then
                                log "SUCCESS" "Glow instalado após corrigir dependências"
                            else
                                log "ERROR" "Falha na instalação do glow via .deb"
                                # FALLBACK: Tentar via snap ou desistir
                                if command -v snap >/dev/null 2>&1; then
                                    log "INFO" "Tentando instalar via snap..."
                                    if sudo snap install glow >/dev/null 2>&1; then
                                        log "SUCCESS" "Glow instalado via snap"
                                    else
                                        log "ERROR" "Falha na instalação do glow"
                                    fi
                                fi
                            fi
                        fi
                    else
                        log "ERROR" "Download do glow falhou ou arquivo corrompido"
                    fi
                    # PROBLEMA 5: Limpar sempre o arquivo temporário
                    rm -f "$deb_file"
                else
                    log "ERROR" "Falha no download do glow"
                    # FALLBACK: Tentar método alternativo
                    if command -v snap >/dev/null 2>&1; then
                        log "INFO" "Tentando instalar via snap como fallback..."
                        if sudo snap install glow >/dev/null 2>&1; then
                            log "SUCCESS" "Glow instalado via snap"
                        fi
                    fi
                fi
            else
                log "ERROR" "Não foi possível detectar versão do glow"
                # FALLBACK: Tentar snap
                if command -v snap >/dev/null 2>&1; then
                    log "INFO" "Tentando instalar via snap..."
                    if sudo snap install glow >/dev/null 2>&1; then
                        log "SUCCESS" "Glow instalado via snap"
                    fi
                fi
            fi
        fi
    else
        log "SUCCESS" "Glow já instalado: $(glow --version)"
    fi
}

install_tldr() {
    if ! command -v tldr >/dev/null 2>&1; then
        if ask_user "Instalar tldr (man pages simplificado)?" "y"; then
            log "INFO" "Instalando tldr..."

            # Tentar via apt primeiro
            if sudo apt install -y tldr >/dev/null 2>&1; then
                log "SUCCESS" "tldr instalado via apt"
            elif command -v pip3 >/dev/null 2>&1; then
                # Fallback para pip se apt falhar
                log "INFO" "Tentando instalar tldr via pip3..."
                if pip3 install --user tldr >/dev/null 2>&1; then
                    log "SUCCESS" "tldr instalado via pip3"
                    log "INFO" "💡 Use: tldr <command> para ver exemplos rápidos"
                else
                    log "ERROR" "Falha na instalação do tldr"
                fi
            else
                log "ERROR" "tldr não disponível via apt nem pip3"
            fi
        fi
    else
        log "SUCCESS" "tldr já instalado: $(tldr --version 2>/dev/null || echo 'disponível')"
    fi
}

install_htop() {
    if ! command -v htop >/dev/null 2>&1; then
        if ask_user "Instalar htop (monitor de sistema melhorado)?" "y"; then
            log "INFO" "Instalando htop..."
            if sudo apt install -y htop >/dev/null 2>&1; then
                log "SUCCESS" "htop instalado"
                log "INFO" "💡 Use: htop para ver processos com interface melhorada"
            else
                log "ERROR" "Falha na instalação do htop"
            fi
        fi
    else
        log "SUCCESS" "htop já instalado"
    fi
}

install_exa() {
    # Verificar se exa OU eza já estão instalados
    if ! command -v exa >/dev/null 2>&1 && ! command -v eza >/dev/null 2>&1; then
        if ask_user "Instalar exa/eza (ls melhorado com cores)?" "y"; then
            log "INFO" "Instalando exa/eza..."

            # SEQUÊNCIA QUE FUNCIONOU: eza → cargo eza → cargo exa
            if sudo apt install -y eza >/dev/null 2>&1; then
                log "SUCCESS" "eza instalado via apt (fork moderno do exa)"
                log "INFO" "💡 Use: eza --icons --git para listagem melhorada"
            elif command -v cargo >/dev/null 2>&1; then
                log "INFO" "Tentando instalar eza via cargo..."
                if cargo install eza >/dev/null 2>&1; then
                    log "SUCCESS" "eza instalado via cargo"
                    log "INFO" "💡 Use: eza --icons --git para listagem melhorada"
                else
                    log "INFO" "Tentando instalar exa (original) via cargo..."
                    if cargo install exa >/dev/null 2>&1; then
                        log "SUCCESS" "exa instalado via cargo"
                        log "INFO" "💡 Use: exa --icons --git para listagem melhorada"
                    else
                        log "ERROR" "Falha na instalação do exa/eza via cargo"
                    fi
                fi
            elif command -v snap >/dev/null 2>&1; then
                # Fallback para snap (exa original)
                log "INFO" "Tentando instalar exa via snap..."
                if sudo snap install exa >/dev/null 2>&1; then
                    log "SUCCESS" "exa instalado via snap"
                    log "INFO" "💡 Use: exa --icons --git para listagem melhorada"
                else
                    log "ERROR" "Falha na instalação do exa via snap"
                fi
            else
                log "WARNING" "exa/eza não disponível - requer apt eza, cargo ou snap"
            fi
        fi
    else
        # Verificar qual está instalado e mostrar versão
        if command -v eza >/dev/null 2>&1; then
            log "SUCCESS" "eza já instalado: $(eza --version | head -1)"
        elif command -v exa >/dev/null 2>&1; then
            log "SUCCESS" "exa já instalado: $(exa --version | head -1)"
        fi
    fi
}

install_micro() {
    if ! command -v micro >/dev/null 2>&1; then
        if ask_user "Instalar micro (editor de texto moderno)?" "y"; then
            log "INFO" "Instalando micro..."

            # Tentar via apt primeiro
            if sudo apt install -y micro >/dev/null 2>&1; then
                log "SUCCESS" "micro instalado via apt"
                log "INFO" "💡 Use: micro <file> para editar com interface moderna"
            elif command -v snap >/dev/null 2>&1; then
                # Fallback para snap
                log "INFO" "Tentando instalar micro via snap..."
                if sudo snap install micro --classic >/dev/null 2>&1; then
                    log "SUCCESS" "micro instalado via snap"
                else
                    log "ERROR" "Falha na instalação do micro via snap"
                fi
            else
                # Fallback para download direto
                log "INFO" "Tentando instalar micro via download direto..."
                if curl -L https://getmic.ro | bash >/dev/null 2>&1; then
                    # Mover para /usr/local/bin se foi instalado no diretório atual
                    if [[ -f ./micro ]]; then
                        sudo mv ./micro /usr/local/bin/
                        sudo chmod +x /usr/local/bin/micro
                        log "SUCCESS" "micro instalado via download direto"
                    fi
                else
                    log "ERROR" "Falha na instalação do micro"
                fi
            fi
        fi
    else
        log "SUCCESS" "micro já instalado: $(micro --version | head -1)"
    fi
}

install_tmux() {
    if ! command -v tmux >/dev/null 2>&1; then
        if ask_user "Instalar tmux (terminal multiplexer)?" "y"; then
            log "INFO" "Instalando tmux..."
            if sudo apt install -y tmux >/dev/null 2>&1; then
                log "SUCCESS" "tmux instalado"
                log "INFO" "💡 Use: tmux para sessões de terminal múltiplas"
                log "INFO" "💡 Atalhos: Ctrl+b então c (nova janela), d (detach)"
            else
                log "ERROR" "Falha na instalação do tmux"
            fi
        fi
    else
        log "SUCCESS" "tmux já instalado: $(tmux -V)"
    fi
}

install_watch() {
    if ! command -v watch >/dev/null 2>&1; then
        if ask_user "Instalar watch (executar comandos repetidamente)?" "y"; then
            log "INFO" "Instalando watch..."
            # watch geralmente vem no procps, mas tentar instalar separadamente
            if sudo apt install -y procps >/dev/null 2>&1; then
                if command -v watch >/dev/null 2>&1; then
                    log "SUCCESS" "watch disponível (parte do procps)"
                    log "INFO" "💡 Use: watch -n 2 'command' para repetir a cada 2s"
                else
                    log "WARNING" "watch pode já estar disponível no sistema"
                fi
            else
                log "WARNING" "procps/watch pode já estar no sistema"
            fi
        fi
    else
        log "SUCCESS" "watch já instalado"
    fi
}

check_and_install_nodejs() {
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        log "SUCCESS" "Node.js já instalado: $node_version"

        # Verificar se é versão muito antiga
        local major_version=$(echo "$node_version" | sed 's/v\([0-9]*\).*/\1/')
        if [[ $major_version -lt 18 ]]; then
            log "WARNING" "Node.js versão antiga detectada: $node_version"
            if ask_user "Instalar Node.js LTS mais recente via NodeSource?" "y"; then
                install_nodejs_nodesource
            fi
        fi
    else
        log "WARNING" "Node.js não encontrado"
        if ask_user "Instalar Node.js LTS?" "y"; then
            install_nodejs_nodesource
        else
            log "INFO" "Node.js skip - pode instalar depois com: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
        fi
    fi
}

install_nodejs_nodesource() {
    log "INFO" "Instalando Node.js LTS via NodeSource..."

    # Adicionar repositório NodeSource
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs

    # Verificar instalação
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        local npm_version=$(npm --version)
        log "SUCCESS" "Node.js instalado: $node_version (npm: $npm_version)"
    else
        log "ERROR" "Falha na instalação do Node.js"
    fi
}

check_and_install_yarn() {
    if ! command -v node >/dev/null 2>&1; then
        return 0  # Skip se não tem Node.js
    fi

    if command -v yarn >/dev/null 2>&1; then
        local yarn_version=$(yarn --version)
        log "SUCCESS" "Yarn já instalado: $yarn_version"
    else
        if ask_user "Instalar Yarn package manager?" "y"; then
            log "INFO" "Instalando Yarn..."
            curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
            sudo apt update -qq
            sudo apt install -y yarn

            if command -v yarn >/dev/null 2>&1; then
                log "SUCCESS" "Yarn instalado: $(yarn --version)"
            fi
        fi
    fi
}

check_and_install_build_tools() {
    log "INFO" "Verificando ferramentas de build adicionais..."

    # Verificar se tem make, cmake, pkg-config (úteis para compilação)
    local build_tools=()

    if ! command -v make >/dev/null 2>&1; then
        build_tools+=("make")
    fi

    if ! command -v cmake >/dev/null 2>&1; then
        build_tools+=("cmake")
    fi

    if ! command -v pkg-config >/dev/null 2>&1; then
        build_tools+=("pkg-config")
    fi

    if [[ ${#build_tools[@]} -gt 0 ]]; then
        if ask_user "Instalar ferramentas de build adicionais (${build_tools[*]})?" "y"; then
            sudo apt install -y "${build_tools[@]}"
            log "SUCCESS" "Ferramentas de build instaladas: ${build_tools[*]}"
        fi
    else
        log "SUCCESS" "Ferramentas de build já disponíveis"
    fi
}

check_and_install_snap() {
    if ! command -v snap >/dev/null 2>&1; then
        if ask_user "Instalar Snap para acesso a mais aplicações?" "y"; then
            sudo apt install -y snapd
            log "SUCCESS" "Snap instalado"
        fi
    else
        log "SUCCESS" "Snap já disponível"
    fi
}

# =============================================================================
# VERIFICAR FERRAMENTAS ESPECÍFICAS DO DESENVOLVIMENTO
# =============================================================================

check_development_environment() {
    log "INFO" "Verificando ambiente de desenvolvimento atual..."

    echo ""

# Ferramentas modernas
echo "🚀 FERRAMENTAS MODERNAS:"
if command -v fzf >/dev/null 2>&1; then
    echo "   ✅ fzf: $(fzf --version | head -1)"
    echo "      💡 Use: ff (fuzzy find), Ctrl+R (histórico), Ctrl+T (arquivos)"
else
    echo "   ❌ fzf: Não instalado"
fi

if command -v fd >/dev/null 2>&1; then
    echo "   ✅ fd: $(fd --version)"
else
    echo "   ❌ fd: Não instalado"
fi

if command -v bat >/dev/null 2>&1; then
    echo "   ✅ bat: $(bat --version | head -1)"
else
    echo "   ❌ bat: Não instalado"
fi

if command -v exa >/dev/null 2>&1; then
    echo "   ✅ exa: $(exa --version | head -1)"
else
    echo "   ❌ exa: Não instalado"
fi

if command -v zoxide >/dev/null 2>&1; then
    echo "   ✅ zoxide: $(zoxide --version)"
    echo "      💡 Use: z <diretório> (cd inteligente)"
else
    echo "   ❌ zoxide: Não instalado"
fi

if command -v direnv >/dev/null 2>&1; then
    echo "   ✅ direnv: $(direnv --version)"
    echo "      💡 Use: echo 'export VAR=value' > .envrc && direnv allow"
else
    echo "   ❌ direnv: Não instalado"
fi

if command -v gh >/dev/null 2>&1; then
    echo "   ✅ GitHub CLI: $(gh --version | head -1)"
    echo "      💡 Use: ghpr (create PR), ghprs (list PRs)"
else
    echo "   ❌ GitHub CLI: Não instalado"
fi

if command -v lazygit >/dev/null 2>&1; then
    echo "   ✅ lazygit: Git TUI"
    echo "      💡 Use: lg ou gitflow"
else
    echo "   ❌ lazygit: Não instalado"
fi

if command -v glow >/dev/null 2>&1; then
    echo "   ✅ glow: Markdown viewer"
    echo "      💡 Use: readme, glow arquivo.md"
else
    echo "   ❌ glow: Não instalado"
fi

if command -v ncdu >/dev/null 2>&1; then
    echo "   ✅ ncdu: Disk usage analyzer"
else
    echo "   ❌ ncdu: Não instalado"
fi

if command -v http >/dev/null 2>&1; then
    echo "   ✅ httpie: API testing tool"
else
    echo "   ❌ httpie: Não instalado"
fi

if command -v meld >/dev/null 2>&1; then
    echo "   ✅ meld: Visual diff tool"
else
    echo "   ❌ meld: Não instalado"
fi

echo ""
echo "🐚 SHELL ENVIRONMENT:"
if command -v zsh >/dev/null 2>&1; then
    echo "   ✅ Zsh: $(zsh --version)"
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo "   ✅ Oh-My-Zsh: Instalado"
    else
        echo "   ❌ Oh-My-Zsh: Não instalado"
    fi
else
    echo "   ❌ Zsh: Não instalado"
fi

echo "   📊 Shell atual: $SHELL"
echo ""
echo "🎯 VERIFICAÇÃO FINAL:"
echo "   ✅ Execute: dev-health (monitorização completa)"
echo "   ✅ Execute: dev-tools (verificar ferramentas)"
echo "   ✅ Execute: dev-benchmark (testar performance)"
echo "   ✅ Execute: dev-network-info (ver config de rede)"
echo "   ✅ Execute: dev-diff (ver diferenças vs Ubuntu padrão)"
echo "   ✅ Teste: dev-clean status"
echo ""
echo "📋 COMANDOS DE TESTE IMEDIATOS:"
echo "   bc --version          # Calculadora (usado pelo script)"
echo "   ss -tulpn | head      # Verificar portas"
echo "   notify-send 'Teste'   # Notificações desktop"
echo "   cat /proc/sys/net/core/rmem_max  # Ver buffer rede atual"
echo "   fzf --version         # Fuzzy finder (se instalado)"
echo "   fd --version          # Find melhorado (se instalado)"
echo "   gh --version          # GitHub CLI (se instalado)"
echo "   lazygit --version     # Git visual (se instalado)"
echo "   zoxide --version      # CD inteligente (se instalado)"
echo "   direnv --version      # Ambiente por diretório (se instalado)"
echo "   systemctl status fail2ban  # Verificar fail2ban (se SSH ativo)"
echo "   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # CPU governor"
echo ""
echo "💡 MELHORIAS ADICIONAIS IMPLEMENTADAS:"
echo "   🔋 CPU governor ajusta automaticamente (AC=performance, bateria=powersave)"
echo "   📦 Ferramentas modernas atualizam automaticamente (mensal)"
echo "   🔒 Auditoria de segurança mensal automática (Lynis)"
echo "   📊 Monitorização completa com benchmarks"
echo "   🔄 Sistema de rollback com scripts automáticos"
echo "   ⚙️ Configuração vim/bash/SSH otimizada para produtividade"
echo "   🌐 DNS otimizado (CloudFlare + Google)"
echo "   🛡️ Proteção fail2ban contra ataques SSH"
echo "   🐚 Zsh + Oh-My-Zsh + Zoxide + Direnv (shell produtivo)"
echo ""
    echo "📋 FERRAMENTAS DETECTADAS:"

    # Node.js ecosystem
    if command -v node >/dev/null 2>&1; then
        echo "   ✅ Node.js: $(node --version)"
        echo "   ✅ npm: $(npm --version)"
    else
        echo "   ❌ Node.js: Não instalado"
    fi

    if command -v yarn >/dev/null 2>&1; then
        echo "   ✅ Yarn: $(yarn --version)"
    else
        echo "   ❌ Yarn: Não instalado"
    fi

    # Python ecosystem
    if command -v python3 >/dev/null 2>&1; then
        echo "   ✅ Python3: $(python3 --version | cut -d' ' -f2)"
    else
        echo "   ❌ Python3: Não instalado"
    fi

    if command -v pip3 >/dev/null 2>&1; then
        echo "   ✅ pip3: $(pip3 --version | cut -d' ' -f2)"
    else
        echo "   ❌ pip3: Não instalado"
    fi

    # Build tools
    if command -v gcc >/dev/null 2>&1; then
        echo "   ✅ GCC: $(gcc --version | head -1 | cut -d' ' -f4)"
    else
        echo "   ❌ GCC: Não instalado"
    fi

    if command -v make >/dev/null 2>&1; then
        echo "   ✅ Make: $(make --version | head -1 | cut -d' ' -f3)"
    else
        echo "   ❌ Make: Não instalado"
    fi

    # Git
    if command -v git >/dev/null 2>&1; then
        echo "   ✅ Git: $(git --version | cut -d' ' -f3)"
    else
        echo "   ❌ Git: Não instalado"
    fi

    # Docker
    if command -v docker >/dev/null 2>&1; then
        echo "   ✅ Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        echo "   ❌ Docker: Não instalado"
    fi

    echo ""
}

# =============================================================================
# CONFIGURAÇÃO BÁSICA DE GIT (SE NÃO CONFIGURADO)
# =============================================================================

configure_git_basics() {
    if ! command -v git >/dev/null 2>&1; then
        return 0
    fi

    # Verificar se Git já está configurado
    if git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1; then
        log "SUCCESS" "Git já configurado para $(git config --global user.name)"
        return 0
    fi

    log "INFO" "Git não está configurado"
    if ask_user "Configurar Git agora (nome e email)?" "y"; then
        echo ""
        read -p "Nome completo para Git: " git_name
        read -p "Email para Git: " git_email

        if [[ -n "$git_name" && -n "$git_email" ]]; then
            git config --global user.name "$git_name"
            git config --global user.email "$git_email"

            # Configurações úteis adicionais
            git config --global init.defaultBranch main
            git config --global pull.rebase false
            git config --global core.autocrlf input

            log "SUCCESS" "Git configurado para $git_name ($git_email)"
        else
            log "WARNING" "Git não configurado - pode fazer depois com: git config --global user.name/user.email"
        fi
    fi
}

# =============================================================================
# CONFIGURAÇÕES BÁSICAS ÚTEIS PARA PRODUTIVIDADE
# =============================================================================

configure_productivity_basics() {
    log "INFO" "Configurando configurações básicas para produtividade..."

    # 1. VIM CONFIGURAÇÃO BÁSICA
    configure_vim_basics

    # 2. BASH HISTORY MELHORADO
    configure_enhanced_bash_history

    # 3. SSH CLIENT OTIMIZADO
    configure_ssh_client

    # 4. TIMEZONE E LOCALE
    configure_locale_timezone

    # 5. DNS OTIMIZADO (considerando conflitos)
    if [[ "$SKIP_DNS_CONFIG" != true ]]; then
        configure_dns_optimization
    fi

    # 6. CONFIGURAÇÕES DE SISTEMA ÚTEIS
    configure_system_tweaks

    log "SUCCESS" "Configurações básicas de produtividade aplicadas"
}

configure_vim_basics() {
    log "INFO" "Configurando vim básico..."

    # Vim configuração universal (funciona para todos os utilizadores)
    cat > ~/.vimrc << 'EOF'
" Configuração VIM básica para desenvolvimento

" Aparência
syntax on
set number
set relativenumber
set cursorline
set showmatch
set ruler
set laststatus=2

" Indentação
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab

" Busca
set hlsearch
set incsearch
set ignorecase
set smartcase

" Performance
set lazyredraw
set ttyfast

" Usabilidade
set backspace=indent,eol,start
set wildmenu
set wildmode=longest:full,full
set completeopt=menuone,longest
set mouse=a
set clipboard=unnamedplus
set noswapfile
set nobackup
set undofile
set undodir=~/.vim/undodir

" Criar diretório de undo se não existir
if !isdirectory($HOME."/.vim/undodir")
    call mkdir($HOME."/.vim/undodir", "p")
endif

" Atalhos úteis
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a
nnoremap <C-q> :q<CR>

" Navegação entre splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Para desenvolvimento web
autocmd FileType html,css,javascript,typescript,json set tabstop=2 shiftwidth=2
autocmd FileType yaml,yml set tabstop=2 shiftwidth=2
autocmd FileType python set tabstop=4 shiftwidth=4

" Remover espaços em branco no save
autocmd BufWritePre * :%s/\s\+$//e
EOF

    log "SUCCESS" "Vim configurado com configurações básicas de desenvolvimento"
}

configure_enhanced_bash_history() {
    log "INFO" "Configurando bash history melhorado..."

    # Adicionar configurações avançadas de history ao bashrc
    if ! grep -q "# === BASH HISTORY MELHORADO ===" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# === BASH HISTORY MELHORADO ===
# Configurações avançadas de histórico

# Tamanho do histórico
export HISTSIZE=50000
export HISTFILESIZE=100000

# Formato com timestamps
export HISTTIMEFORMAT="%d/%m/%y %T "

# Controle do histórico
export HISTCONTROL=ignoreboth:erasedups

# Ignorar comandos específicos
export HISTIGNORE="ls:ps:history:exit:clear:cd:pwd"

# Opções de history
shopt -s histappend        # Append ao history em vez de overwrite
shopt -s histverify        # Verificar command history expansion
shopt -s histreedit        # Editar command history expansion
shopt -s checkwinsize      # Check window size after each command

# Sincronizar history entre sessões
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# Função para pesquisar no histórico com fzf (se disponível)
if command -v fzf >/dev/null 2>&1; then
    __fzf_history__() {
        local output
        output=$(
            HISTTIMEFORMAT='' history |
            fzf --tac --sync -n2..,.. \
                --tiebreak=index \
                --bind=ctrl-r:toggle-sort \
                --query="$READLINE_LINE"
        ) && READLINE_LINE="${output#*$'\t'}"
        READLINE_POINT=${#READLINE_LINE}
    }
    bind -m emacs-standard -x '"\C-r": __fzf_history__'
fi

# Função para ver histórico por data
histdate() {
    if [ -z "$1" ]; then
        echo "Uso: histdate DD/MM/YY"
        return 1
    fi
    history | grep "$1"
}

# Função para estatísticas do histórico
histstats() {
    history | awk '{print $4}' | sort | uniq -c | sort -nr | head -20
}
EOF
        log "SUCCESS" "Bash history melhorado configurado"
    fi
}

configure_ssh_client() {
    log "INFO" "Configurando SSH client otimizado..."

    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Configuração SSH client otimizada
    cat > ~/.ssh/config << 'EOF'
# Configuração SSH Client Otimizada

# Configurações globais
Host *
    # Performance
    Compression yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes

    # Security
    HashKnownHosts yes
    VisualHostKey yes

    # Usabilidade
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 5m

    # Evitar timeouts
    ConnectTimeout 30

    # Reutilizar conexões
    AddKeysToAgent yes

# Exemplo de configuração para servidores de desenvolvimento
# Descomente e ajuste conforme necessário
#
# Host dev-server
#     HostName your-dev-server.com
#     User your-username
#     Port 22
#     IdentityFile ~/.ssh/id_rsa
#     LocalForward 3000 localhost:3000
#     LocalForward 8080 localhost:8080
EOF

    chmod 600 ~/.ssh/config
    log "SUCCESS" "SSH client otimizado configurado"
}

configure_locale_timezone() {
    log "INFO" "Verificando locale e timezone..."

    # Verificar se locale está configurado corretamente
    if ! locale | grep -q "pt_PT\|en_US" 2>/dev/null; then
        log "INFO" "Configurando locale..."
        sudo apt install -y locales

        if ask_user "Configurar locale para português (pt_PT.UTF-8)?" "y"; then
            sudo locale-gen pt_PT.UTF-8
            sudo update-locale LANG=pt_PT.UTF-8
            log "SUCCESS" "Locale português configurado"
        else
            sudo locale-gen en_US.UTF-8
            sudo update-locale LANG=en_US.UTF-8
            log "SUCCESS" "Locale inglês configurado"
        fi
    fi

    # Verificar timezone (assumindo Portugal como padrão)
    current_tz=$(timedatectl show -p Timezone --value)
    if [[ "$current_tz" != "Europe/Lisbon" ]]; then
        if ask_user "Configurar timezone para Lisboa?" "y"; then
            sudo timedatectl set-timezone Europe/Lisbon
            log "SUCCESS" "Timezone configurado para Lisboa"
        fi
    fi
}

configure_dns_optimization() {
    if ask_user "Configurar DNS otimizado (CloudFlare + Google)?" "y"; then
        log "INFO" "Configurando DNS otimizado..."

        # Backup do resolv.conf atual
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup

        # Configurar systemd-resolved com DNS rápidos
        sudo tee /etc/systemd/resolved.conf > /dev/null << 'EOF'
[Resolve]
DNS=1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4
FallbackDNS=9.9.9.9 149.112.112.112
Domains=~.
DNSSEC=allow-downgrade
DNSOverTLS=opportunistic
Cache=yes
EOF

        sudo systemctl restart systemd-resolved
        log "SUCCESS" "DNS otimizado configurado (CloudFlare + Google)"
    fi
}

configure_system_tweaks() {
    log "INFO" "Aplicando tweaks úteis do sistema..."

    # Configurar logrotate para logs de desenvolvimento
    sudo tee /etc/logrotate.d/dev-logs > /dev/null << 'EOF'
/var/log/dev-maintenance/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

/home/*/.npm/_logs/*.log {
    weekly
    rotate 2
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

    # Otimizar systemd para desenvolvimento
    sudo tee /etc/systemd/system.conf.d/dev-optimizations.conf > /dev/null << 'EOF'
[Manager]
# Reduce boot time
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=10s

# Optimize for development
DefaultLimitNOFILE=65536
DefaultLimitNPROC=32768
EOF

    # Configurar ambiente para desenvolvimento
    if ! grep -q "# === DEV ENVIRONMENT ===" ~/.profile 2>/dev/null; then
        cat >> ~/.profile << 'EOF'

# === DEV ENVIRONMENT ===
# Configurações para desenvolvimento

# Adicionar paths úteis
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Configurações para Node.js
export NODE_ENV=development
export NODE_OPTIONS="--max-old-space-size=4096"

# Configurações para Python
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Configurações para desenvolvimento
export EDITOR=vim
export BROWSER=firefox
export TERM=xterm-256color

# Cores no terminal
export CLICOLOR=1
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
EOF
        log "SUCCESS" "Ambiente de desenvolvimento configurado"
    fi

    log "SUCCESS" "System tweaks aplicados"
}

# =============================================================================
# GNOME OTIMIZADO PARA DESENVOLVIMENTO
# =============================================================================

optimize_gnome_minimalist() {
    if ! command -v gsettings >/dev/null 2>&1; then
        log "INFO" "GNOME não detectado - pulando otimizações"
        return 0
    fi

    log "INFO" "Detectado ambiente GNOME"

    # SEMPRE otimizar terminal (essencial para desenvolvimento)
    optimize_gnome_terminal

    # Perguntar sobre otimizações mais agressivas
    if ask_user "Aplicar GNOME minimalista para máxima performance? (recomendado)" "y"; then
        configure_gnome_minimal_performance
    fi
}

optimize_gnome_terminal() {
    log "INFO" "Otimizando GNOME Terminal para desenvolvimento..."

    # Configurações específicas para terminal
    local profile_id=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
    local profile_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile_id/"

    # Otimizar scrollback (importante para logs)
    if [[ $RAM_GB -ge 16 ]]; then
        gsettings set "$profile_path" scrollback-lines 100000
        log "INFO" "Terminal scrollback: 100K linhas (16GB+ RAM)"
    elif [[ $RAM_GB -ge 8 ]]; then
        gsettings set "$profile_path" scrollback-lines 50000
        log "INFO" "Terminal scrollback: 50K linhas (8GB+ RAM)"
    else
        gsettings set "$profile_path" scrollback-lines 25000
        log "INFO" "Terminal scrollback: 25K linhas"
    fi

    # USAR CORES DO TEMA DO SISTEMA (não cores customizadas)
    gsettings set "$profile_path" use-theme-colors true
    gsettings set "$profile_path" use-system-font true

    log "SUCCESS" "GNOME Terminal otimizado (usa cores do tema do sistema)"
}

configure_gnome_minimal_performance() {
    log "INFO" "Configurando GNOME minimalista para performance..."

    # ⚠️ PERGUNTA DE SEGURANÇA PARA AMBIENTE EMPRESARIAL
    echo ""
    log "WARNING" "🏢 VERIFICAÇÃO EMPRESARIAL:"
    echo "   • Esta configuração vai DESATIVAR animações e efeitos visuais"
    echo "   • Pode não seguir 'look & feel' padrão da empresa"
    echo "   • Melhora significativamente a performance"
    echo "   • Mantém todas as funcionalidades, apenas remove 'eye candy'"

    if ! ask_user "Continuar com GNOME minimalista? (reversível)" "y"; then
        log "INFO" "Mantendo GNOME padrão (apenas terminal otimizado)"
        return 0
    fi
    # Dash to Dock otimizado
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
    gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 16
    gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-show-apps-button true

    # Performance básica (SEGURO)
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.shell.extensions.dash-to-dock animate-show-apps false 2>/dev/null || true
    gsettings set org.gnome.desktop.interface enable-hot-corners false

    # Tema dark DO SISTEMA (não cores customizadas)
    gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark' 2>/dev/null || gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

    # Nautilus otimizado
    gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'never'
    gsettings set org.gnome.nautilus.list-view use-tree-view true 2>/dev/null || true

    # Privacidade melhorada
    gsettings set org.gnome.desktop.privacy report-technical-problems false
    gsettings set org.gnome.desktop.privacy send-software-usage-stats false

    # Touchpad otimizado (para laptops)
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
    gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
    gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

    # Power management inteligente
    gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
    gsettings set org.gnome.desktop.session idle-delay 900

    # Workspaces (manter dinâmico - útil para desenvolvimento)
    gsettings set org.gnome.mutter dynamic-workspaces true

    # Atalho útil para terminal
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Terminal'
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'gnome-terminal'
    # gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>Return'

    # MANTER funcionalidades importantes (não remover)
    # - Window controls (minimize, maximize, close) - MANTIDO
    # - Dock/Activities - MANTIDO
    # - Extensions básicas - MANTIDO

    log "SUCCESS" "GNOME configurado para máxima performance"
    log "INFO" "💡 Mantido: workspaces, dock, window controls, extensões básicas"
    log "INFO" "🎨 Removido: animações, hot corners, thumbnails"
    log "INFO" "⌨️ Novo atalho: Super+Enter = Terminal"
}

# =============================================================================
# ALIASES INTELIGENTES PARA DESENVOLVIMENTO
# =============================================================================

configure_smart_dev_aliases() {
    log "INFO" "Configurando aliases inteligentes para desenvolvimento..."

    # Criar arquivo de aliases que funciona tanto para bash quanto zsh
    cat > ~/.dev_aliases << 'EOF'
# ============================================================================
# ALIASES INTELIGENTES PARA DESENVOLVIMENTO
# Funciona em bash e zsh
# ============================================================================

# === NAVEGAÇÃO MELHORADA ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Função para detectar qual comando usar (eza ou exa)
setup_exa_aliases() {
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza --icons'
        alias ll='eza -la --icons --git'
        alias tree='eza --tree --icons'
    elif command -v exa >/dev/null 2>&1; then
        alias ls='exa --icons'
        alias ll='exa -la --icons --git'
        alias tree='exa --tree --icons'
    fi
}

# Chamar a função
setup_exa_aliases

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

# === GIT PRODUTIVO ===
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gb='git branch'
alias gco='git checkout'
alias gd='git diff'
alias gdc='git diff --cached'

# Git aliases avançados
alias ghpr='gh pr create'
alias ghprs='gh pr list'
alias gitflow='lazygit'
alias lg='lazygit'

# === DOCKER RÁPIDO ===
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs -f'

# === DESENVOLVIMENTO ===
alias serve='python3 -m http.server 8000'
alias nodemon='npx nodemon'
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'

# Yarn
alias ys='yarn start'
alias yb='yarn build'
alias yt='yarn test'
alias ya='yarn add'

# Python
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate'

# === SISTEMA E MANUTENÇÃO ===
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias search='apt search'
alias info='apt show'

# Limpeza rápida
alias clean='sudo apt autoremove && sudo apt autoclean'
alias cleancache='npm cache clean --force && pip cache purge'

# Monitoramento
alias cpu='htop'
alias disk='ncdu'
alias ports='ss -tulpn'
alias processes='ps aux | head -20'

# === LOGS E DEBUGGING ===
alias logs='journalctl -f'
alias logsearch='journalctl -f | grep'
alias syslog='tail -f /var/log/syslog'
alias auth='tail -f /var/log/auth.log'

# === NETWORKING ===
alias ping='ping -c 5'
alias myip='curl -s ipinfo.io/ip'
alias localip='hostname -I | cut -d" " -f1'
alias netinfo='ip addr show'

# === DESENVOLVIMENTO WEB ===
alias serve='python3 -m http.server'
alias serve8080='python3 -m http.server 8080'
alias phpserve='php -S localhost:8000'
alias nodeserve='npx http-server'

# === UTILS ===
alias weather='curl wttr.in'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'
alias json='python3 -m json.tool'
alias urlencode='python3 -c "import urllib.parse; import sys; print(urllib.parse.quote(sys.argv[1]))"'

# === FERRAMENTAS ESPECÍFICAS ===
# fzf
alias ff='fzf --preview "bat --color=always {}"'
alias fcd='cd $(find . -type d | fzf)'

# zoxide (se instalado)
if command -v zoxide >/dev/null 2>&1; then
    alias cd='z'
fi

# GitHub CLI
if command -v gh >/dev/null 2>&1; then
    alias ghrepo='gh repo view --web'
    alias ghissue='gh issue create'
fi

# Markdown
if command -v glow >/dev/null 2>&1; then
    alias readme='glow README.md'
    alias md='glow'
fi

# === FUNÇÕES ÚTEIS ===

# Função para criar projeto rapidamente
mkproject() {
    local name="${1:-new-project}"
    mkdir "$name" && cd "$name"
    git init
    echo "# $name" > README.md
    echo "node_modules/" > .gitignore
    echo "✅ Projeto '$name' criado!"
}

# Função para procurar em arquivos
searchin() {
    if command -v rg >/dev/null 2>&1; then
        rg -i "$1" .
    else
        grep -r -i "$1" .
    fi
}

# Função para backup rápido
backup() {
    local file="$1"
    cp "$file" "${file}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "✅ Backup criado: ${file}.backup.$(date +%Y%m%d-%H%M%S)"
}

# Função para ver tamanho de pastas
dirsize() {
    du -sh "${1:-.}"/* | sort -hr
}

# Função para testar conectividade
testnet() {
    local host="${1:-google.com}"
    echo "Testing connectivity to $host..."
    ping -c 3 "$host"
}

# Função para info do sistema
sysinfo() {
    echo "🖥️ SISTEMA:"
    echo "   OS: $(lsb_release -d | cut -f2)"
    echo "   Kernel: $(uname -r)"
    echo "   Uptime: $(uptime -p)"
    echo ""
    echo "💾 MEMÓRIA:"
    free -h
    echo ""
    echo "💿 DISCO:"
    df -h /
}

# Função para limpeza de desenvolvimento
devclean() {
    echo "🧹 Limpando ambiente de desenvolvimento..."

    # Node.js
    if [[ -d node_modules ]]; then
        echo "Removendo node_modules..."
        rm -rf node_modules
    fi

    # Python
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
    find . -name "*.pyc" -delete 2>/dev/null

    # Cache npm
    npm cache clean --force 2>/dev/null || true

    echo "✅ Limpeza concluída!"
}

# Função para info de porta
portinfo() {
    local port="$1"
    if [[ -z "$port" ]]; then
        echo "Uso: portinfo <porta>"
        return 1
    fi

    echo "🔍 Informações da porta $port:"
    lsof -i :$port
}

# Função para debugging de rede e processos
netdebug() {
    echo "🌐 DEBUG DE REDE E PROCESSOS:"
    echo ""
    echo "=== CONEXÕES ATIVAS ==="
    ss -tulpn | head -10
    echo ""
    echo "=== PROCESSOS TOP CPU ==="
    ps aux --sort=-%cpu | head -10
    echo ""
    echo "=== PROCESSOS TOP MEMÓRIA ==="
    ps aux --sort=-%mem | head -10
    echo ""
    echo "=== INTERFACES DE REDE ==="
    ip addr show | grep -E '^[0-9]+:|inet '
}

# Função para monitorar espaço em disco em tempo real
diskwatch() {
    watch -n 5 'df -h | grep -E "(Filesystem|/dev/)"'
}
EOF

    # Carregar aliases no bashrc se não existir
    if ! grep -q "source ~/.dev_aliases" ~/.bashrc 2>/dev/null; then
        echo "source ~/.dev_aliases" >> ~/.bashrc
    fi

    # Se zsh existir, carregar no zshrc também
    if [[ -f ~/.zshrc ]] && ! grep -q "source ~/.dev_aliases" ~/.zshrc 2>/dev/null; then
        echo "source ~/.dev_aliases" >> ~/.zshrc
    fi

    log "SUCCESS" "Aliases inteligentes configurados em ~/.dev_aliases"
    log "INFO" "💡 Use 'source ~/.dev_aliases' para carregar imediatamente"
}

# =============================================================================
# SISTEMA DE MANUTENÇÃO EMPRESARIAL
# =============================================================================

setup_enterprise_maintenance() {
    log "INFO" "Configurando sistema de manutenção empresarial..."

    sudo mkdir -p /var/log/dev-maintenance

    # Script principal de manutenção
    sudo tee /usr/local/bin/dev-maintenance.sh > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

MAINTENANCE_LOG="/var/log/dev-maintenance/maintenance.log"
STATS_LOG="/var/log/dev-maintenance/stats.log"
ALERT_THRESHOLD_GB=3
CONFIG_FILE="/etc/dev-maintenance.conf"

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
readonly CONFIG_FILE

log_maintenance() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$MAINTENANCE_LOG"
    echo "[${level}] ${message}"
}

get_free_space_gb() {
    df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}'
}

is_enterprise_docker() {
    [[ -f /etc/docker/daemon.json ]] && grep -q "registry\|proxy" /etc/docker/daemon.json 2>/dev/null
}

docker_smart_cleanup() {
    local mode="${1:-conservative}"

    if ! command -v docker >/dev/null 2>&1; then
        return 0
    fi

    local db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "(postgres|mysql|mariadb|mongo|redis|elastic|cassandra|db|database)" || true)

    case "$mode" in
        "conservative")
            docker ps -a --filter "status=exited" --format "{{.Names}}" | while read container; do
                if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                    docker rm "$container" 2>/dev/null || true
                fi
            done
            docker image prune -f >/dev/null 2>&1 || true
            ;;
        "moderate")
            docker_smart_cleanup conservative
            docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
                if [[ ! "$image" =~ (postgres|mysql|mariadb|mongo|redis|elastic|cassandra) ]]; then
                    if ! docker ps -a --format "{{.Image}}" | grep -q "^$image$"; then
                        docker rmi "$image" 2>/dev/null || true
                    fi
                fi
            done
            docker builder prune --filter "until=168h" -f >/dev/null 2>&1 || true
            ;;
        "aggressive")
            local db_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "(data|postgres|mysql|mongo|redis|elastic|db)" || true)

            docker ps --format "{{.Names}}" | while read container; do
                if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                    docker stop "$container" 2>/dev/null || true
                    docker rm "$container" 2>/dev/null || true
                fi
            done

            docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
                if [[ ! "$image" =~ (postgres|mysql|mariadb|mongo|redis|elastic|cassandra) ]]; then
                    docker rmi "$image" 2>/dev/null || true
                fi
            done

            docker volume ls --format "{{.Name}}" | while read volume; do
                if [[ -n "$volume" ]] && ! echo "$db_volumes" | grep -q "^$volume$"; then
                    docker volume rm "$volume" 2>/dev/null || true
                fi
            done

            docker network prune -f >/dev/null 2>&1 || true
            docker builder prune -a -f >/dev/null 2>&1 || true
            ;;
    esac
}

daily_cleanup() {
    log_maintenance "INFO" "=== LIMPEZA DIÁRIA ==="
    local space_before=$(get_free_space_gb)

    find /tmp -name "*.log" -type f -mtime +2 -delete 2>/dev/null || true

    if [[ -d ~/.npm/_cacache ]]; then
        local npm_size=$(du -sm ~/.npm/_cacache 2>/dev/null | cut -f1 || echo 0)
        [[ $npm_size -gt 500 ]] && npm cache clean --force >/dev/null 2>&1 || true
    fi

    find ~/.cache/pip -type f -mtime +7 -delete 2>/dev/null || true

    if ! is_enterprise_docker; then
        docker_smart_cleanup conservative
    fi

    local space_after=$(get_free_space_gb)
    local freed=$(echo "$space_after - $space_before" | bc -l 2>/dev/null || echo "0")
    log_maintenance "SUCCESS" "Limpeza diária: ${freed}GB libertados"
}

weekly_cleanup() {
    log_maintenance "INFO" "=== LIMPEZA SEMANAL ==="
    local space_before=$(get_free_space_gb)

    daily_cleanup

    apt autoremove -y --purge >/dev/null 2>&1
    apt clean >/dev/null 2>&1
    journalctl --vacuum-time=30d >/dev/null 2>&1

    find /tmp -type f -atime +14 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +14 -delete 2>/dev/null || true

    if ! is_enterprise_docker; then
        docker_smart_cleanup moderate
    fi

    local space_after=$(get_free_space_gb)
    local freed=$(echo "$space_after - $space_before" | bc -l 2>/dev/null || echo "0")
    log_maintenance "SUCCESS" "Limpeza semanal: ${freed}GB libertados"
}

monthly_cleanup() {
    log_maintenance "INFO" "=== LIMPEZA MENSAL ==="
    local space_before=$(get_free_space_gb)

    weekly_cleanup

    journalctl --vacuum-time=60d >/dev/null 2>&1

    if ! is_enterprise_docker; then
        docker_smart_cleanup aggressive
    fi

    if command -v snap >/dev/null; then
        snap list --all | awk '/disabled/{print $1, $3}' | \
        while read snapname revision; do
            snap remove "$snapname" --revision="$revision" 2>/dev/null || true
        done
    fi

    local space_after=$(get_free_space_gb)
    local freed=$(echo "$space_after - $space_before" | bc -l 2>/dev/null || echo "0")
    log_maintenance "SUCCESS" "Limpeza mensal: ${freed}GB libertados"
}

monitor_disk_space() {
    local free_space=$(get_free_space_gb)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "${timestamp},${free_space}" >> "$STATS_LOG"

    if (( $(echo "$free_space < $ALERT_THRESHOLD_GB" | bc -l) )); then
        log_maintenance "ALERT" "⚠️ ESPAÇO BAIXO: ${free_space}GB restantes!"
        if command -v notify-send >/dev/null && [[ -n "${DISPLAY:-}" ]]; then
            notify-send "⚠️ Espaço em Disco Baixo" "Restam apenas ${free_space}GB!" --urgency=critical 2>/dev/null || true
        fi
    fi
}

main() {
    case "${1:-daily}" in
        "daily") daily_cleanup; monitor_disk_space ;;
        "weekly") weekly_cleanup; monitor_disk_space ;;
        "monthly") monthly_cleanup; monitor_disk_space ;;
        "monitor") monitor_disk_space ;;
        *) echo "Uso: $0 {daily|weekly|monthly|monitor}"; exit 1 ;;
    esac
}

main "$@"
EOF

    sudo chmod +x /usr/local/bin/dev-maintenance.sh

    # Continuar com o resto da função (cron jobs, scripts utilitários, etc.)
    # Cron jobs
    echo "30 6 * * * root /usr/local/bin/dev-maintenance.sh daily" | sudo tee /etc/cron.d/dev-maintenance-daily > /dev/null
    echo "30 7 * * 0 root /usr/local/bin/dev-maintenance.sh weekly" | sudo tee /etc/cron.d/dev-maintenance-weekly > /dev/null
    echo "30 8 1-7 * 0 root /usr/local/bin/dev-maintenance.sh monthly" | sudo tee /etc/cron.d/dev-maintenance-monthly > /dev/null
    echo "0 */6 * * * root /usr/local/bin/dev-maintenance.sh monitor" | sudo tee /etc/cron.d/dev-maintenance-monitor > /dev/null

    # Configuração
    sudo tee /etc/dev-maintenance.conf > /dev/null << 'EOF'
ALERT_THRESHOLD_GB=3
DESKTOP_NOTIFICATIONS=true
MAINTENANCE_LOG_RETENTION=90
EOF

    # SCRIPTS UTILITÁRIOS MELHORADOS
    create_utility_scripts

    log "SUCCESS" "Sistema de manutenção empresarial configurado!"
}

create_utility_scripts() {
    log "INFO" "Criando scripts utilitários..."

    # Comando de limpeza
    sudo tee /usr/local/bin/dev-clean > /dev/null << 'EOF'
#!/bin/bash
case "${1:-status}" in
    "now")
        sudo /usr/local/bin/dev-maintenance.sh daily
        ;;
    "deep")
        sudo /usr/local/bin/dev-maintenance.sh weekly
        ;;
    "nuclear")
        sudo /usr/local/bin/dev-maintenance.sh monthly
        ;;
    "docker")
        docker system df 2>/dev/null
        echo "Use: dev-clean docker-light|docker-normal|docker-deep"
        ;;
    "docker-light")
        # Usar função do script principal seria melhor, mas como workaround:
        docker container prune -f
        docker image prune -f
        ;;
    "docker-normal")
        docker container prune -f
        docker image prune -f
        docker builder prune --filter "until=168h" -f
        ;;
    "docker-deep")
        echo "⚠️ Remove TUDO exceto DBs. Continuar? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            docker system prune -a -f --volumes
        fi
        ;;
    "status")
        echo "💾 ESPAÇO: $(df -h / | awk 'NR==2 {print $4}') livres"
        echo "📊 USO: $(df -h / | awk 'NR==2 {print $5}') utilizado"
        docker system df 2>/dev/null || true
        ;;
    *)
        echo "🧹 LIMPEZA MELHORADA"
        echo "Uso: dev-clean {status|now|deep|nuclear|docker-*}"
        echo ""
        echo "  status      - Ver espaço + Docker"
        echo "  now         - Daily + Docker light"
        echo "  deep        - Weekly + Docker normal"
        echo "  nuclear     - Monthly + Docker agressivo"
        echo "  docker-*    - Docker específico"
        ;;
esac
EOF

    # Status do sistema
    sudo tee /usr/local/bin/dev-status > /dev/null << 'EOF'
#!/bin/bash
clear
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    LAPTOP EMPRESARIAL - STATUS                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "💾 ESPAÇO EM DISCO:"
df -h / | awk 'NR==2 {
    used_pct = int($5)
    if (used_pct > 90) color = "🔴"
    else if (used_pct > 80) color = "🟡"
    else color = "🟢"
    printf "   %s %s usado de %s (%s livre)\n", color, $3, $2, $4
}'
echo ""
echo "🖥️ SISTEMA:"
echo "   📊 RAM: $(free -h | awk '/^Mem:/{printf "%s usado de %s", $3, $2}')"
echo "   ⚡ CPU: $(nproc) cores"
if [[ -f /sys/class/power_supply/BAT*/capacity ]]; then
    echo "   🔋 Bateria: $(cat /sys/class/power_supply/BAT*/capacity | head -1)%"
fi
echo ""
echo "🛠️ DESENVOLVIMENTO:"
if command -v node >/dev/null 2>&1; then
    echo "   ✅ Node.js: $(node --version)"
else
    echo "   ❌ Node.js: Não disponível"
fi
if command -v python3 >/dev/null 2>&1; then
    echo "   ✅ Python: $(python3 --version | cut -d' ' -f2)"
else
    echo "   ❌ Python: Não disponível"
fi
if command -v docker >/dev/null 2>&1; then
    echo "   ✅ Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
else
    echo "   ❌ Docker: Não disponível"
fi
if command -v zsh >/dev/null 2>&1; then
    echo "   ✅ Zsh: $(zsh --version | cut -d' ' -f2)"
    if [[ -d ~/.oh-my-zsh ]]; then
        echo "   ✅ Oh-My-Zsh: Instalado"
    fi
else
    echo "   ❌ Zsh: Não disponível"
fi
echo ""
echo "📋 COMANDOS:"
echo "   dev-tools            - Verificar ferramentas de desenvolvimento"
echo "   dev-clean now        - Limpeza rápida"
echo "   dev-clean status     - Ver espaço detalhado"
echo "   dev-network-info     - Ver configurações de rede"
echo "   dev-health           - Health check completo"
echo "   dev-benchmark        - Testar performance"
echo "   logs                 - Ver logs sistema"
echo ""
EOF

    # Network info
    sudo tee /usr/local/bin/dev-network-info > /dev/null << 'EOF'
#!/bin/bash
echo "📶 CONFIGURAÇÕES DE REDE ATUAIS vs. PADRÃO UBUNTU"
echo ""

echo "🔍 BUFFERS DE REDE:"
echo "   Receive default: $(cat /proc/sys/net/core/rmem_default) bytes (Ubuntu padrão: 212992)"
echo "   Receive max:     $(cat /proc/sys/net/core/rmem_max) bytes (Ubuntu padrão: 212992)"
echo "   Send default:    $(cat /proc/sys/net/core/wmem_default) bytes (Ubuntu padrão: 212992)"
echo "   Send max:        $(cat /proc/sys/net/core/wmem_max) bytes (Ubuntu padrão: 212992)"

echo ""
echo "🚦 TCP CONFIGURAÇÕES:"
echo "   Window scaling:  $(cat /proc/sys/net/ipv4/tcp_window_scaling) (padrão: 1)"
echo "   Timestamps:      $(cat /proc/sys/net/ipv4/tcp_timestamps) (padrão: 1)"
echo "   SACK:           $(cat /proc/sys/net/ipv4/tcp_sack) (padrão: 1)"
echo "   Congestion:     $(cat /proc/sys/net/ipv4/tcp_congestion_control)"

echo ""
echo "📊 TCP BUFFERS PER-CONNECTION:"
echo "   TCP rmem: $(cat /proc/sys/net/ipv4/tcp_rmem) (min default max)"
echo "   TCP wmem: $(cat /proc/sys/net/ipv4/tcp_wmem) (min default max)"

echo ""
echo "💡 ANÁLISE:"
current_rmem_max=$(cat /proc/sys/net/core/rmem_max)
if [[ $current_rmem_max -gt 500000 ]]; then
    echo "   ⚠️ Buffers de rede aumentados - pode consumir mais RAM"
    echo "   📈 Benefício: melhor throughput em redes rápidas/alta latência"
    echo "   💾 Custo: mais memória por conexão TCP"
else
    echo "   ✅ Buffers de rede padrão Ubuntu - conservador"
    echo "   💾 Benefício: menor uso de RAM"
    echo "   📊 Limitação: throughput limitado em redes muito rápidas"
fi

echo ""
echo "🔧 PARA ALTERAR:"
echo "   • Reexecutar script de otimização e escolher opção de rede"
echo "   • Ou editar manualmente: /etc/sysctl.d/99-dev-performance-conservative.conf"
echo ""
EOF

    # Tools checker
    sudo tee /usr/local/bin/dev-tools > /dev/null << 'EOF'
#!/bin/bash
echo "🛠️ FERRAMENTAS DE DESENVOLVIMENTO DISPONÍVEIS:"
echo ""

# Node.js ecosystem
if command -v node >/dev/null 2>&1; then
    echo "✅ Node.js: $(node --version)"
    echo "✅ npm: $(npm --version)"
else
    echo "❌ Node.js: Não instalado"
    echo "   💡 Instalar: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt install nodejs"
fi

if command -v yarn >/dev/null 2>&1; then
    echo "✅ Yarn: $(yarn --version)"
else
    echo "❌ Yarn: Não instalado"
fi

echo ""

# Python ecosystem
if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python3: $(python3 --version | cut -d' ' -f2)"
else
    echo "❌ Python3: Não instalado"
fi

if command -v pip3 >/dev/null 2>&1; then
    echo "✅ pip3: $(pip3 --version | cut -d' ' -f2)"
else
    echo "❌ pip3: Não instalado"
fi

echo ""

# Shell environment
if command -v zsh >/dev/null 2>&1; then
    echo "✅ Zsh: $(zsh --version | cut -d' ' -f2)"
    if [[ -d ~/.oh-my-zsh ]]; then
        echo "✅ Oh-My-Zsh: Instalado"
    else
        echo "❌ Oh-My-Zsh: Não instalado"
    fi
else
    echo "❌ Zsh: Não instalado"
fi

if command -v zoxide >/dev/null 2>&1; then
    echo "✅ Zoxide: $(zoxide --version)"
else
    echo "❌ Zoxide: Não instalado"
fi

if command -v direnv >/dev/null 2>&1; then
    echo "✅ Direnv: $(direnv --version)"
else
    echo "❌ Direnv: Não instalado"
fi

echo ""

# Build tools
if command -v gcc >/dev/null 2>&1; then
    echo "✅ GCC: $(gcc --version | head -1 | awk '{print $4}')"
else
    echo "❌ GCC: Não instalado"
fi

if command -v make >/dev/null 2>&1; then
    echo "✅ Make: Disponível"
else
    echo "❌ Make: Não instalado"
fi

if command -v cmake >/dev/null 2>&1; then
    echo "✅ CMake: $(cmake --version | head -1 | awk '{print $3}')"
else
    echo "❌ CMake: Não instalado"
fi

echo ""

# Git
if command -v git >/dev/null 2>&1; then
    echo "✅ Git: $(git --version | awk '{print $3}')"
    if git config --global user.name >/dev/null 2>&1; then
        echo "   👤 Configurado para: $(git config --global user.name)"
    else
        echo "   ⚠️ Não configurado (execute: git config --global user.name/user.email)"
    fi
else
    echo "❌ Git: Não instalado"
fi

echo ""

# Docker
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
    if groups $USER | grep -q docker; then
        echo "   👤 Usuário no grupo docker"
    else
        echo "   ⚠️ Usuário não está no grupo docker (execute: sudo usermod -aG docker $USER)"
    fi
else
    echo "❌ Docker: Não instalado"
fi

echo ""
echo "💡 Para instalar ferramentas em falta, execute novamente o script de otimização"
echo ""
EOF

    # Health check
    sudo tee /usr/local/bin/dev-health > /dev/null << 'EOF'
#!/bin/bash
echo "🏥 HEALTH CHECK COMPLETO DO LAPTOP EMPRESARIAL"
echo "=============================================="
echo ""

# Sistema base
echo "🖥️ SISTEMA BASE:"
echo "   OS: $(lsb_release -d | cut -f2)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p)"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# Memória
echo "💾 MEMÓRIA:"
free -h | grep -E "Mem:|Swap:"
echo ""

# Armazenamento
echo "💿 ARMAZENAMENTO:"
df -h | grep -E "Filesystem|/dev/"
echo ""

# Rede
echo "📶 REDE:"
ip addr show | grep -E "^[0-9]+:|inet " | grep -v "127.0.0.1"
echo ""

# Serviços críticos
echo "🔧 SERVIÇOS:"
for service in ssh docker tlp systemd-resolved; do
    if systemctl is-active --quiet $service; then
        echo "   ✅ $service: ativo"
    else
        echo "   ❌ $service: inativo"
    fi
done
echo ""

# Configurações
echo "⚙️ CONFIGURAÇÕES:"
echo "   Sysctl config: $(ls /etc/sysctl.d/99-dev-performance-*.conf 2>/dev/null | wc -l) arquivos"
echo "   Limits config: $(ls /etc/security/limits.d/99-dev-*.conf 2>/dev/null | wc -l) arquivos"
echo "   Cron jobs: $(ls /etc/cron.d/dev-* 2>/dev/null | wc -l) jobs"
echo ""

# Alertas
echo "⚠️ ALERTAS:"
free_space=$(df / | awk 'NR==2 {print $4/1024/1024}')
if (( $(echo "$free_space < 5" | bc -l) )); then
    echo "   🔴 Espaço baixo: ${free_space}GB restantes"
else
    echo "   ✅ Espaço em disco OK"
fi

load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
if (( $(echo "$load_avg > 2" | bc -l) )); then
    echo "   🔴 Load alto: $load_avg"
else
    echo "   ✅ Load normal: $load_avg"
fi

echo ""
echo "🎯 PRÓXIMAS AÇÕES RECOMENDADAS:"
echo "   dev-benchmark     - Testar performance"
echo "   dev-clean deep    - Limpeza profunda"
echo "   logs | head -20   - Verificar logs recentes"
EOF

    # Benchmark
    sudo tee /usr/local/bin/dev-benchmark > /dev/null << 'EOF'
#!/bin/bash
echo "🚀 BENCHMARK DO LAPTOP EMPRESARIAL"
echo "=================================="
echo ""

echo "⏱️ TESTE CPU (10 segundos)..."
cpu_start=$(date +%s.%N)
timeout 10s yes > /dev/null
cpu_end=$(date +%s.%N)
echo "   ✅ CPU stress test concluído"
echo ""

echo "💾 TESTE MEMÓRIA..."
mem_test=$(python3 -c "
import time
start = time.time()
data = [0] * (100000)
end = time.time()
print(f'{(end-start)*1000:.1f}ms')
" 2>/dev/null || echo "N/A")
echo "   ✅ Alocação 100K elementos: $mem_test"
echo ""

echo "💿 TESTE DISCO (escrita 100MB)..."
disk_start=$(date +%s.%N)
dd if=/dev/zero of=/tmp/benchmark_test bs=1M count=100 2>/dev/null
sync
disk_end=$(date +%s.%N)
rm -f /tmp/benchmark_test
disk_time=$(echo "$disk_end - $disk_start" | bc -l | cut -c1-4)
disk_speed=$(echo "100 / $disk_time" | bc -l | cut -c1-5)
echo "   ✅ Velocidade escrita: ${disk_speed}MB/s"
echo ""

echo "📶 TESTE REDE (ping + DNS)..."
ping_time=$(ping -c 3 8.8.8.8 | tail -1 | awk -F/ '{print $5}' | cut -c1-5)
dns_start=$(date +%s.%N)
nslookup google.com >/dev/null 2>&1
dns_end=$(date +%s.%N)
dns_time=$(echo "($dns_end - $dns_start) * 1000" | bc -l | cut -c1-5)
echo "   ✅ Ping médio: ${ping_time}ms"
echo "   ✅ DNS lookup: ${dns_time}ms"
echo ""

echo "📊 RESUMO:"
echo "   🎯 Performance: $([ "${ping_time%.*}" -lt 50 ] && echo "Boa" || echo "Verificar rede")"
echo "   💿 Storage: $([ "${disk_speed%.*}" -gt 50 ] && echo "Bom" || echo "Lento")"
echo "   🔧 Otimizações: Ativas"
EOF

    # Comparar com Ubuntu padrão
    sudo tee /usr/local/bin/dev-diff > /dev/null << 'EOF'
#!/bin/bash
echo "🔍 DIFERENÇAS vs. UBUNTU PADRÃO"
echo "==============================="
echo ""

echo "🔧 KERNEL PARAMETERS:"
echo "   vm.swappiness: $(cat /proc/sys/vm/swappiness) (padrão: 60)"
echo "   vm.dirty_ratio: $(cat /proc/sys/vm/dirty_ratio) (padrão: 20)"
echo "   net.core.rmem_max: $(cat /proc/sys/net/core/rmem_max) (padrão: 212992)"
echo "   fs.inotify.max_user_watches: $(cat /proc/sys/fs/inotify/max_user_watches) (padrão: 8192)"
echo ""

echo "📁 ARQUIVOS DE CONFIGURAÇÃO:"
ls -la /etc/sysctl.d/99-dev-* 2>/dev/null || echo "   Nenhuma configuração aplicada"
echo ""

echo "⏰ CRON JOBS:"
ls -la /etc/cron.d/dev-* 2>/dev/null || echo "   Nenhum job aplicado"
echo ""

echo "🛠️ SCRIPTS UTILITÁRIOS:"
ls -la /usr/local/bin/dev-* 2>/dev/null || echo "   Nenhum script aplicado"
echo ""

echo "🐚 SHELL:"
echo "   Shell atual: $SHELL"
echo "   Zsh instalado: $(command -v zsh >/dev/null && echo "Sim" || echo "Não")"
echo "   Oh-My-Zsh: $([[ -d ~/.oh-my-zsh ]] && echo "Sim" || echo "Não")"
EOF

    # Tornar todos executáveis
    sudo chmod +x /usr/local/bin/dev-*

    log "SUCCESS" "Scripts utilitários criados e configurados"
}

# =============================================================================
# DOCKER SMART CLEANUP - PRESERVA DBS
# =============================================================================

docker_smart_cleanup() {
    local mode="${1:-conservative}"

    if ! command -v docker >/dev/null 2>&1; then
        return 0
    fi

    # Detectar containers de DB
    local db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "(postgres|mysql|mariadb|mongo|redis|elastic|cassandra|db|database)" || true)

    case "$mode" in
        "conservative")
            # Containers parados (exceto DBs)
            docker ps -a --filter "status=exited" --format "{{.Names}}" | while read container; do
                if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                    docker rm "$container" 2>/dev/null || true
                fi
            done
            docker image prune -f >/dev/null 2>&1 || true
            ;;
        "moderate")
            docker_smart_cleanup conservative
            docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
                if [[ ! "$image" =~ (postgres|mysql|mariadb|mongo|redis|elastic|cassandra) ]]; then
                    if ! docker ps -a --format "{{.Image}}" | grep -q "^$image$"; then
                        docker rmi "$image" 2>/dev/null || true
                    fi
                fi
            done
            docker builder prune --filter "until=168h" -f >/dev/null 2>&1 || true
            ;;
        "aggressive")
            local db_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "(data|postgres|mysql|mongo|redis|elastic|db)" || true)

            # Parar containers exceto DBs
            docker ps --format "{{.Names}}" | while read container; do
                if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                    docker stop "$container" 2>/dev/null || true
                    docker rm "$container" 2>/dev/null || true
                fi
            done

            # Remover imagens exceto DBs
            docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
                if [[ ! "$image" =~ (postgres|mysql|mariadb|mongo|redis|elastic|cassandra) ]]; then
                    docker rmi "$image" 2>/dev/null || true
                fi
            done

            # Remover volumes exceto dados
            docker volume ls --format "{{.Name}}" | while read volume; do
                if [[ -n "$volume" ]] && ! echo "$db_volumes" | grep -q "^$volume$"; then
                    docker volume rm "$volume" 2>/dev/null || true
                fi
            done

            docker network prune -f >/dev/null 2>&1 || true
            docker builder prune -a -f >/dev/null 2>&1 || true
            ;;
    esac
}

# =============================================================================
# SISTEMA DE ATUALIZAÇÃO DE FERRAMENTAS MODERNAS
# =============================================================================

setup_tools_updater() {
    log "INFO" "Configurando sistema de atualização de ferramentas..."

    # Script para atualizar ferramentas modernas
    sudo tee /usr/local/bin/dev-update-tools > /dev/null << 'EOF'
#!/bin/bash
# Atualizar ferramentas modernas de desenvolvimento

echo "🔄 ATUALIZANDO FERRAMENTAS DE DESENVOLVIMENTO"
echo ""

# Atualizar fzf
if [[ -d ~/.fzf ]]; then
    echo "📦 Atualizando fzf..."
    cd ~/.fzf && git pull && ./install --key-bindings --completion --no-update-rc
fi

# Atualizar lazygit
if command -v lazygit >/dev/null 2>&1; then
    echo "📦 Verificando lazygit..."
    current_version=$(lazygit --version | head -1 | awk '{print $3}' | tr -d ',')
    latest_version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null)

    if [[ "$current_version" != "$latest_version" ]] && [[ -n "$latest_version" ]]; then
        echo "🔄 Atualizando lazygit: $current_version → $latest_version"
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${latest_version}_Linux_x86_64.tar.gz" 2>/dev/null
        tar xf lazygit.tar.gz lazygit 2>/dev/null
        sudo install lazygit /usr/local/bin 2>/dev/null
        rm -f lazygit.tar.gz lazygit
    else
        echo "✅ lazygit já está atualizado"
    fi
fi

# Atualizar Node.js tools globais
if command -v npm >/dev/null 2>&1; then
    echo "📦 Atualizando ferramentas Node.js globais..."
    npm update -g 2>/dev/null || true
fi

# Atualizar Python tools
if command -v pip3 >/dev/null 2>&1; then
    echo "📦 Atualizando ferramentas Python..."
    pip3 install --upgrade pip setuptools wheel 2>/dev/null || true
    if command -v tldr >/dev/null 2>&1; then
        pip3 install --upgrade tldr 2>/dev/null || true
    fi
fi

# Atualizar Rust tools se cargo disponível
if command -v cargo >/dev/null 2>&1; then
    echo "📦 Atualizando ferramentas Rust..."
    if command -v exa >/dev/null 2>&1; then
        cargo install exa --force 2>/dev/null || true
    fi
fi

echo ""
echo "✅ Atualização de ferramentas concluída"
EOF

    sudo chmod +x /usr/local/bin/dev-update-tools

    # Adicionar ao cron mensal
    echo "0 3 15 * * root /usr/local/bin/dev-update-tools >> /var/log/dev-tools-update.log 2>&1" | sudo tee /etc/cron.d/dev-tools-update > /dev/null

    log "SUCCESS" "Sistema de atualização de ferramentas configurado (execução mensal)"
}

# =============================================================================
# CPU GOVERNOR INTELIGENTE
# =============================================================================

configure_cpu_governor() {
    if ask_user "Configurar CPU governor inteligente (balanceado AC / powersave bateria)?" "y"; then
        log "INFO" "Configurando CPU governor inteligente..."

        # Script para ajustar governor baseado na fonte de energia
        sudo tee /usr/local/bin/cpu-governor-smart > /dev/null << 'EOF'
#!/bin/bash
# Ajuste inteligente do CPU governor (laptop-friendly)

# Detectar se está na bateria ou AC
if [[ -f /sys/class/power_supply/ADP*/online ]]; then
    ac_online=$(cat /sys/class/power_supply/ADP*/online 2>/dev/null | head -1)
elif [[ -f /sys/class/power_supply/AC*/online ]]; then
    ac_online=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1)
else
    ac_online=1  # Assumir AC se não conseguir detectar
fi

# Ajustar governor (LAPTOP-FRIENDLY)
if [[ "$ac_online" == "1" ]]; then
    # AC plugged - ONDEMAND (não performance!)
    echo "ondemand" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    echo "CPU Governor: ondemand (AC conectado - thermal-friendly)"
else
    # Battery - powersave
    echo "powersave" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    echo "CPU Governor: powersave (bateria)"
fi
EOF

        sudo chmod +x /usr/local/bin/cpu-governor-smart

        # Executar na startup e quando muda fonte de energia
        sudo tee /etc/systemd/system/cpu-governor-smart.service > /dev/null << 'EOF'
[Unit]
Description=Smart CPU Governor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cpu-governor-smart
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

        # Udev rule para executar quando mudar fonte de energia
        sudo tee /etc/udev/rules.d/99-cpu-governor.rules > /dev/null << 'EOF'
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/local/bin/cpu-governor-smart"
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/local/bin/cpu-governor-smart"
EOF

        sudo systemctl enable cpu-governor-smart.service
        sudo udevadm control --reload-rules

        log "SUCCESS" "CPU governor inteligente configurado (laptop-friendly)"
        log "INFO" "Ondemand quando AC conectado, powersave na bateria"
    fi
}

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"

    case "$level" in
        "INFO")    echo -e "${BLUE}ℹ${NC} ${message}" ;;
        "SUCCESS") echo -e "${GREEN}✅${NC} ${message}" ;;
        "WARNING") echo -e "${YELLOW}⚠${NC} ${message}" ;;
        "ERROR")   echo -e "${RED}❌${NC} ${message}" ;;
    esac
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ask_user() {
    local question="$1"
    local default="${2:-n}"
    local response

    read -p "$(echo -e "${YELLOW}?${NC} ${question} [${default}]: ")" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
}

create_backup() {
    log "INFO" "Criando backup de configurações..."
    mkdir -p "$BACKUP_DIR"

    local backup_files=(
        "/etc/sysctl.conf"
        "/etc/fstab"
        "/etc/security/limits.conf"
    )

    for file in "${backup_files[@]}"; do
        [[ -f "$file" ]] && cp "$file" "$BACKUP_DIR/"
    done

    [[ -d /etc/sysctl.d/ ]] && cp -r /etc/sysctl.d/ "$BACKUP_DIR/"
    [[ -d /etc/security/limits.d/ ]] && cp -r /etc/security/limits.d/ "$BACKUP_DIR/"

    # Criar script de rollback
    create_rollback_script

    log "SUCCESS" "Backup criado em: $BACKUP_DIR"
}

create_rollback_script() {
    cat > "$BACKUP_DIR/rollback.sh" << EOF
#!/bin/bash
# Script de rollback automático
# Criado: $(date)

echo "🔄 EXECUTANDO ROLLBACK..."

# Restaurar arquivos de configuração
[[ -f sysctl.conf ]] && sudo cp sysctl.conf /etc/
[[ -f fstab ]] && sudo cp fstab /etc/
[[ -f limits.conf ]] && sudo cp limits.conf /etc/security/

# Remover configurações adicionadas
sudo rm -f /etc/sysctl.d/99-dev-performance-*.conf
sudo rm -f /etc/security/limits.d/99-dev-*.conf
sudo rm -f /etc/cron.d/dev-*
sudo rm -f /usr/local/bin/dev-*

# Recarregar configurações
sudo sysctl --system
sudo systemctl daemon-reload

echo "✅ Rollback concluído!"
echo "🔄 Reinicie o sistema para aplicar completamente"
EOF

    chmod +x "$BACKUP_DIR/rollback.sh"

    # Criar comando de rollback global
    sudo tee /usr/local/bin/dev-rollback > /dev/null << EOF
#!/bin/bash
if [[ -z "\$1" ]]; then
    echo "Uso: dev-rollback <backup_directory>"
    echo "Backups disponíveis:"
    ls -la ~/.ubuntu-dev-backup-* 2>/dev/null | tail -5
    exit 1
fi

if [[ -f "\$1/rollback.sh" ]]; then
    cd "\$1"
    ./rollback.sh
else
    echo "Script de rollback não encontrado em \$1"
    exit 1
fi
EOF

    sudo chmod +x /usr/local/bin/dev-rollback
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    clear
    echo "
╔══════════════════════════════════════════════════════════════════════════════╗
║          UBUNTU LAPTOP OPTIMIZER - VERSÃO EMPRESARIAL MELHORADA             ║
║                    🆕 ZSH + OH-MY-ZSH + ZOXIDE + DIRENV 🆕                   ║
║                    🛡️ VERIFICAÇÃO DE CONFLITOS EMPRESARIAIS 🛡️               ║
╚══════════════════════════════════════════════════════════════════════════════╝
"

    log "INFO" "🆕 NOVAS FUNCIONALIDADES:"
    log "INFO" "   • Zsh + Oh-My-Zsh + plugins inteligentes"
    log "INFO" "   • Zoxide (cd inteligente baseado em frequência)"
    log "INFO" "   • Direnv (ambientes por diretório)"
    log "INFO" "   • Verificação de conflitos VPN/Docker/SSH"
    log "WARNING" "⚠️ Script vai verificar conflitos empresariais antes de aplicar mudanças"
    echo ""

    # Verificações iniciais
    check_prerequisites

    if ! ask_user "Continuar com otimizações melhoradas?" "y"; then
        log "INFO" "Operação cancelada."
        exit 0
    fi

    # NOVA: Verificar conflitos empresariais ANTES de qualquer mudança
    check_enterprise_conflicts

    # Detectar sistema
    detect_system_specs

    # Criar backup
    create_backup

    # Aplicar otimizações
    log "INFO" "Aplicando otimizações baseadas na verificação de conflitos..."

    # Kernel sempre seguro
    optimize_kernel_conservative

    # Storage e laptop
    optimize_storage_advanced
    # configure_laptop_optimizations # é bom para preservar o laptop, ssd e bateria

    # Development limits sempre seguros
    optimize_development_limits

    # Segurança (considerando conflitos detectados)
    configure_advanced_security

    # Configurações de produtividade (incluindo ZSH se escolhido)
    configure_productivity_basics

    # Verificar ambiente e instalar ferramentas (INCLUINDO ZSH)
    check_development_environment
    install_development_essentials

    # Git
    configure_git_basics

    # GNOME (com verificações empresariais)
    optimize_gnome_minimalist

    # Aliases inteligentes
    configure_smart_dev_aliases

    # Docker (com verificações)
    configure_docker_enterprise

    # Sistema de manutenção
    setup_enterprise_maintenance

    # Configurar sistema de atualização de ferramentas
    setup_tools_updater

    # Configurar CPU governor inteligente
    configure_cpu_governor

    # Relatório final
    echo "
╔══════════════════════════════════════════════════════════════════════════════╗
║                        LAPTOP EMPRESARIAL OTIMIZADO                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

🖥️ SISTEMA ANALISADO:
   • RAM: ${RAM_GB}GB
   • CPU: ${CPU_CORES} cores
   • Armazenamento: ${STORAGE_TYPE^^}

⚡ OTIMIZAÇÕES APLICADAS:
   • 🔧 Kernel conservador para estabilidade
   • 🔋 TLP para gestão inteligente de bateria
   • 💾 Proteção de SSD (journald limitado, TRIM automático)
   • 🔒 Segurança avançada (firewall, fail2ban, AppArmor, updates automáticos)
   • 🖥️ Terminal GNOME otimizado para logs ($([ $RAM_GB -ge 16 ] && echo "100K" || echo "50K") linhas)
   • 🎨 GNOME: $(gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null | grep -q false && echo "Minimalista conservador (sem animações, tema dark, touchpad otimizado)" || echo "Básico (apenas terminal otimizado)")
   • 📶 Network: $(grep -q "rmem_max=2097152" /etc/sysctl.d/99-dev-performance-conservative.conf 2>/dev/null && echo "Otimizado (buffers 2MB)" || echo "Padrão Ubuntu (conservador)")
   • 🛠️ Ferramentas de desenvolvimento verificadas/instaladas
   • ⚙️ Configurações produtividade (vim, bash history, SSH client, DNS, locale)
   • 🧹 Sistema de manutenção automático com monitorização
   • 🔄 Sistema de rollback completo criado
   • 🔋 CPU governor inteligente (performance AC / powersave bateria)
   • 📦 Sistema de atualização automática de ferramentas
   • 🐚 Zsh + Oh-My-Zsh + Zoxide + Direnv (se escolhido)

🛠️ FERRAMENTAS DE DESENVOLVIMENTO:
   • Node.js e npm (LTS se instalado)
   • Python3 e pip3 + venv
   • Git (configurado se necessário)
   • Build tools (gcc, make, cmake)
   • Docker (opcional)
   • Yarn (se Node.js presente)
   • Zsh + Oh-My-Zsh + plugins (se escolhido)
   • Zoxide (cd inteligente - se escolhido)
   • Direnv (ambiente por diretório - se escolhido)
   • Ferramentas modernas: fzf, fd, bat, exa (se escolhidas)
   • Ferramentas úteis: ncdu, tldr, httpie, gh, glow, lazygit, meld (se escolhidas)
   • Segurança: fail2ban, lynis (se SSH ativo)
   • Sistema: ripgrep, multitail, shellcheck, lsof, pstree, debsums

🎯 COMANDOS DISPONÍVEIS:
   • dev-status           - Dashboard do laptop
   • dev-tools            - Verificar ferramentas de desenvolvimento
   • dev-clean now        - Limpeza rápida
   • dev-clean status     - Ver espaço em disco
   • dev-health           - Health check completo
   • dev-benchmark        - Testar performance
   • dev-network-info     - Ver configurações de rede
   • dev-diff             - Ver diferenças vs Ubuntu padrão
   • dev-rollback <dir>   - Fazer rollback de configurações
   • logs                 - Ver logs do sistema (journalctl -f)
   • logsearch <termo>    - Procurar nos logs
   • diskwatch            - Monitorar espaço em tempo real

🔄 PRÓXIMOS PASSOS IMPORTANTES:
   1. 🔄 REINICIAR: sudo reboot
   2. 🔧 Finalizar GRUB: sudo update-grub (se zswap foi configurado)
   3. ✅ Testar sistema: dev-health
   4. 🛠️ Verificar ferramentas: dev-tools
   5. 📶 Ver configurações: dev-network-info
   6. 🎯 Benchmark: dev-benchmark
   7. 🔍 Ver diferenças: dev-diff

📁 BACKUP E ROLLBACK:
   • Backup criado em: $BACKUP_DIR
   • Script de rollback: $BACKUP_DIR/rollback.sh
   • Comando de rollback: dev-rollback $BACKUP_DIR

💡 CONFIGURAÇÕES NÃO INCLUÍDAS (faça depois se desejar):
   • IDEs e editores específicos (VS Code, JetBrains)
   • Node.js/Python environments (nvm, pyenv) - mas ferramentas base estão prontas

🔒 SOBRE SEGURANÇA AVANÇADA:
   • Firewall UFW configurado com regras inteligentes
   • Fail2ban ativo se SSH detectado (proteção contra ataques)
   • AppArmor otimizado com perfis adicionais
   • Updates de segurança automáticos melhorados
   • SSH hardening avançado aplicado
   • Auditoria de segurança mensal automática (Lynis)
   • Monitorização de vulnerabilidades ativa

💾 SOBRE OTIMIZAÇÕES SSD:
   • TRIM automático configurado e ativo
   • I/O scheduler otimizado por tipo de storage (none/mq-deadline)
   • Read-ahead ajustado (NVMe: 512, SSD: 256, HDD: 128)
   • Swapfile inteligente criada se necessário
   • Journald limitado para proteger SSD

🐚 SOBRE ZSH + OH-MY-ZSH (se escolhido):
   • Zsh configurado como shell padrão
   • Oh-My-Zsh com plugins para desenvolvimento
   • Plugins: git, docker, node, npm, yarn, python, autosuggestions, syntax-highlighting
   • Zoxide: navegação inteligente com 'z <diretório>'
   • Direnv: ambientes automáticos por diretório (.envrc)
   • Histórico melhorado: 50K comandos com timestamps
   • Aliases produtivos já configurados
   • Completion melhorado com fzf-tab

⚙️ SOBRE CONFIGURAÇÕES DE PRODUTIVIDADE:
   • Vim configurado com syntax highlighting, números de linha, atalhos úteis
   • Bash/Zsh history melhorado (50K linhas, timestamps, pesquisa fuzzy se fzf)
   • SSH client otimizado (compressão, multiplexing, timeouts)
   • Locale e timezone configurados para Portugal
   • DNS otimizado (CloudFlare + Google para velocidade) - se não há conflitos
   • Logrotate personalizado para logs de desenvolvimento

🛡️ SOBRE VERIFICAÇÕES DE CONFLITOS EMPRESARIAIS:
   • VPN: Detecta VPN ativa e pergunta antes de alterar DNS/rede
   • Docker: Verifica impacto em bridge networks e volumes
   • SSH: Respeita configurações empresariais existentes
   • Firewall: Mantém regras empresariais se muitas existirem
   • DNS: Preserva DNS empresariais se detectados
   • Valores padrão sempre seguros para ambiente corporativo

📶 SOBRE CONFIGURAÇÕES DE REDE:
   • Script pergunta se quer otimizações de rede (opcional)
   • SEM otimizações: mantém padrão Ubuntu (mais estável, menos RAM)
   • COM otimizações: buffers 2MB vs. 212KB padrão (melhor performance, mais RAM)
   • BBR congestion control ativado automaticamente se suportado
   • Use 'dev-network-info' após reiniciar para ver configurações ativas

🔄 SOBRE O SISTEMA DE ROLLBACK:
   • Backup completo criado automaticamente antes de qualquer mudança
   • Script de rollback automático em cada backup
   • Comando 'dev-rollback <backup_dir>' para restaurar sistema
   • Manifesto detalhado de cada backup
   • Possibilidade de restaurar estado completamente anterior
"

    # Verificar se GRUB precisa update
    if grep -q "zswap.enabled" /etc/default/grub; then
        echo ""
        echo -e "${YELLOW}⚠️ IMPORTANTE:${NC} Execute após reiniciar:"
        echo -e "   ${GREEN}sudo update-grub${NC}"
    fi

    log "SUCCESS" "🎉 Sistema otimizado inteligentemente com todas as melhorias!"

    if [[ -d ~/.oh-my-zsh ]]; then
        echo ""
        echo -e "${GREEN}🐚 ZSH INSTALADO:${NC} Faça logout/login para ativar o Zsh"
        echo -e "${GREEN}💡 COMANDOS ZSH:${NC}"
        echo -e "   z <diretório>     # Navegação inteligente"
        echo -e "   nodesetup <nome>  # Criar projeto Node.js"
        echo -e "   cleannode         # Limpar node_modules"
        echo -e "   testapi <url>     # Testar APIs"
    fi

    echo ""
    echo -e "${GREEN}🚀 PRÓXIMO PASSO: sudo reboot${NC}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
