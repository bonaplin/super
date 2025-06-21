#!/bin/bash
# =============================================================================
# MÓDULO: VERIFICAÇÃO DE CONFLITOS EMPRESARIAIS
# Esta é a especialidade única - deteta e adapta-se a ambientes empresariais
# =============================================================================

# Carregar dependências
[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# Variáveis de controlo de conflitos
declare -g SKIP_DNS_CONFIG=false
declare -g SKIP_NETWORK_CONFIG=false  
declare -g SKIP_SSH_HARDENING=false
declare -g SKIP_FIREWALL_CONFIG=false
declare -g ENTERPRISE_MODE=false

# =============================================================================
# DETECÇÃO AVANÇADA DE AMBIENTE EMPRESARIAL
# =============================================================================

detect_enterprise_environment() {
    section_header "Detecção de Ambiente Empresarial" "$SYMBOL_ENTERPRISE"
    
    local enterprise_indicators=0
    local findings=()
    
    # 1. VPN empresarial
    if detect_vpn_active; then
        enterprise_indicators=$((enterprise_indicators + 2))
        findings+=("VPN ativo detectado")
    fi
    
    # 2. Docker empresarial
    if detect_enterprise_docker; then
        enterprise_indicators=$((enterprise_indicators + 2))
        findings+=("Docker com configurações empresariais")
    fi
    
    # 3. SSH empresarial
    if detect_enterprise_ssh; then
        enterprise_indicators=$((enterprise_indicators + 2))
        findings+=("SSH com políticas empresariais")
    fi
    
    # 4. DNS empresarial
    if detect_enterprise_dns; then
        enterprise_indicators=$((enterprise_indicators + 1))
        findings+=("DNS não-padrão (possivelmente empresarial)")
    fi
    
    # 5. Domínio empresarial
    local hostname=$(hostname -f 2>/dev/null || hostname)
    if [[ "$hostname" =~ \.(corp|company|enterprise|local)$ ]]; then
        enterprise_indicators=$((enterprise_indicators + 1))
        findings+=("Hostname empresarial: $hostname")
    fi
    
    # 6. Firewall com muitas regras
    if command_exists ufw && ufw status numbered 2>/dev/null | wc -l | awk '{if($1>20) exit 0; else exit 1}'; then
        enterprise_indicators=$((enterprise_indicators + 1))
        findings+=("Firewall com muitas regras (possivelmente empresarial)")
    fi
    
    # 7. Certificados empresariais
    if [[ -d /usr/local/share/ca-certificates ]] && [[ $(find /usr/local/share/ca-certificates -name "*.crt" | wc -l) -gt 0 ]]; then
        enterprise_indicators=$((enterprise_indicators + 1))
        findings+=("Certificados empresariais instalados")
    fi
    
    # 8. Proxy configurado
    if [[ -n "${http_proxy:-}${https_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}" ]]; then
        enterprise_indicators=$((enterprise_indicators + 2))
        findings+=("Proxy configurado")
    fi
    
    # Avaliação
    echo ""
    echo -e "${BLUE}📊 ANÁLISE DO AMBIENTE:${NC}"
    echo ""
    
    if [[ ${#findings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔍 Indicadores empresariais encontrados:${NC}"
        for finding in "${findings[@]}"; do
            echo -e "   ${SYMBOL_BULLET} $finding"
        done
        echo ""
    fi
    
    # Classificação do ambiente
    if [[ $enterprise_indicators -ge 5 ]]; then
        ENTERPRISE_MODE=true
        status_message "warning" "AMBIENTE ALTAMENTE EMPRESARIAL (score: $enterprise_indicators)"
        echo -e "${YELLOW}   → Modo conservador obrigatório${NC}"
    elif [[ $enterprise_indicators -ge 3 ]]; then
        status_message "info" "AMBIENTE POSSIVELMENTE EMPRESARIAL (score: $enterprise_indicators)"
        echo -e "${BLUE}   → Verificações adicionais recomendadas${NC}"
    else
        status_message "success" "AMBIENTE PESSOAL/PADRÃO (score: $enterprise_indicators)"
        echo -e "${GREEN}   → Otimizações completas seguras${NC}"
    fi
    
    echo ""
    return $enterprise_indicators
}

# =============================================================================
# VERIFICAÇÃO DE CONFLITOS VPN
# =============================================================================

check_vpn_conflicts() {
    section_header "Verificação de Conflitos VPN" "$SYMBOL_NETWORK"
    
    local vpn_active=false
    local vpn_type="desconhecido"
    
    # Detectar tipo de VPN
    if ip route | grep -q "tun"; then
        vpn_active=true
        vpn_type="OpenVPN/túnel"
    elif pgrep -f "openconnect" >/dev/null 2>&1; then
        vpn_active=true
        vpn_type="OpenConnect (Cisco AnyConnect)"
    elif pgrep -f "strongswan" >/dev/null 2>&1; then
        vpn_active=true
        vpn_type="StrongSwan (IPSec)"
    elif ip route | grep -qE "ppp|tap"; then
        vpn_active=true
        vpn_type="PPP/TAP"
    fi
    
    if [[ "$vpn_active" == true ]]; then
        status_message "warning" "VPN ATIVO DETECTADO: $vpn_type"
        echo ""
        
        # Mostrar configuração atual
        echo -e "${BLUE}📊 Configuração atual de rede:${NC}"
        bullet_list \
            "Interfaces: $(ip route | grep -E 'tun|tap|ppp' | awk '{print $3}' | sort -u | tr '\n' ' ')" \
            "DNS atual: $(systemd-resolve --status 2>/dev/null | grep 'DNS Servers' | head -1 | awk -F: '{print $2}' | xargs || echo "não detectado")" \
            "Gateway VPN: $(ip route | grep tun | awk '/default/ {print $3}' | head -1 || echo "não detectado")"
        
        echo ""
        important_warning "VPN empresarial pode conflitar com certas otimizações"
        
        # CONFLITO 1: DNS
        echo -e "${YELLOW}🔍 CONFLITO POTENCIAL: DNS${NC}"
        bullet_list \
            "VPN empresarial força DNS interno da empresa" \
            "Otimização DNS (CloudFlare + Google) pode quebrar acesso interno" \
            "RECOMENDAÇÃO: Manter DNS atual da VPN"
        
        if ! confirm "Aplicar DNS otimizado mesmo com VPN? (pode causar problemas)" "n"; then
            SKIP_DNS_CONFIG=true
            status_message "success" "DNS: Mantendo configuração VPN"
        else
            status_message "warning" "DNS: Aplicando otimização (monitorizar problemas)"
        fi
        
        echo ""
        
        # CONFLITO 2: Configurações de rede
        echo -e "${YELLOW}🔍 CONFLITO POTENCIAL: Buffers de Rede${NC}"
        bullet_list \
            "VPN pode ser afetada por buffers de rede aumentados" \
            "Padrão Ubuntu: rmem_max=212KB, wmem_max=212KB" \
            "Otimizado: rmem_max=2MB, wmem_max=2MB (10x maior)" \
            "RISCO: Pode causar instabilidade na VPN"
        
        if ! confirm "Aplicar otimizações de rede com VPN ativa? (pode afetar estabilidade)" "n"; then
            SKIP_NETWORK_CONFIG=true
            status_message "success" "Rede: Mantendo configuração padrão Ubuntu"
        else
            status_message "warning" "Rede: Aplicando otimização (testar conectividade VPN)"
        fi
        
    else
        status_message "success" "Sem VPN detectado - otimizações de rede seguras"
    fi
    
    echo ""
}

# =============================================================================
# VERIFICAÇÃO DE CONFLITOS DOCKER
# =============================================================================

check_docker_conflicts() {
    section_header "Verificação de Conflitos Docker" "$SYMBOL_GEAR"
    
    if ! command_exists docker; then
        status_message "info" "Docker não instalado - sem conflitos"
        return 0
    fi
    
    # Verificar se é Docker empresarial
    local is_enterprise=$(detect_enterprise_docker && echo "true" || echo "false")
    local docker_size="desconhecido"
    local container_count=0
    
    if [[ -d /var/lib/docker ]]; then
        docker_size=$(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo "erro")
        container_count=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l || echo 0)
    fi
    
    status_message "info" "Docker detectado: $container_count containers, $docker_size usado"
    
    if [[ "$is_enterprise" == "true" ]]; then
        status_message "warning" "DOCKER EMPRESARIAL DETECTADO"
        echo ""
        
        # Mostrar configurações empresariais
        echo -e "${BLUE}📊 Configurações empresariais detectadas:${NC}"
        if [[ -f /etc/docker/daemon.json ]]; then
            local configs=$(grep -E "registry|proxy|insecure" /etc/docker/daemon.json 2>/dev/null | head -3 | sed 's/^/   /')
            echo "$configs"
        fi
        echo ""
        
        important_warning "Docker empresarial tem configurações mandatórias que não devem ser alteradas"
        
        bullet_list \
            "Registries internos podem estar configurados" \
            "Proxies corporativos podem estar em uso" \
            "Políticas de segurança podem estar ativas" \
            "Limpeza automática pode remover recursos críticos"
    fi
    
    # CONFLITO 1: Bridge networks
    echo -e "${YELLOW}🔍 CONFLITO POTENCIAL: Configurações de Rede${NC}"
    bullet_list \
        "Docker usa bridge network 172.17.0.0/16 por padrão" \
        "Otimizações de rede podem afetar comunicação entre containers" \
        "RISCO: Baixo, mas pode causar issues em setups complexos"
    
    if ! confirm "Aplicar otimizações de rede com Docker presente?" "y"; then
        SKIP_NETWORK_CONFIG=true
        status_message "success" "Rede: Mantendo configuração padrão para Docker"
    else
        status_message "info" "Rede: Aplicando otimização (testado com Docker)"
    fi
    
    echo ""
    
    # CONFLITO 2: Limpeza Docker
    echo -e "${YELLOW}🔍 CONFIGURAÇÃO: Sistema de Limpeza Docker${NC}"
    
    # Detectar containers de base de dados
    local db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "(postgres|mysql|mariadb|mongo|redis|elastic|cassandra|db|database)" || true)
    
    if [[ -n "$db_containers" ]]; then
        echo -e "${BLUE}📊 Containers de BD detectados:${NC}"
        echo "$db_containers" | sed 's/^/   • /'
        echo ""
        
        bullet_list \
            "Sistema de limpeza VAI PRESERVAR containers/volumes de BD" \
            "Limpeza apenas remove containers de desenvolvimento" \
            "Três modos: conservador, moderado, agressivo"
        
        status_message "success" "Limpeza Docker inteligente será configurada"
    else
        bullet_list \
            "Nenhum container de BD detectado" \
            "Limpeza pode ser mais agressiva" \
            "Sistema detecta automaticamente BDs no futuro"
    fi
    
    echo ""
}

# =============================================================================
# VERIFICAÇÃO DE CONFLITOS SSH
# =============================================================================

check_ssh_conflicts() {
    section_header "Verificação de Conflitos SSH" "$SYMBOL_SECURITY"
    
    if ! systemctl is-active --quiet ssh 2>/dev/null; then
        status_message "info" "SSH server não ativo - sem conflitos"
        return 0
    fi
    
    status_message "info" "SSH server ativo - verificando configurações..."
    
    # Verificar configurações empresariais
    local enterprise_ssh=false
    local ssh_configs=()
    
    if [[ -f /etc/ssh/sshd_config ]]; then
        if grep -qE "# Company|# Enterprise|# Corporate|AuthorizedKeysCommand" /etc/ssh/sshd_config 2>/dev/null; then
            enterprise_ssh=true
            ssh_configs+=($(grep -E "# Company|# Enterprise|# Corporate" /etc/ssh/sshd_config 2>/dev/null | head -3))
        fi
        
        # Verificar configurações críticas
        local key_configs=$(grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AuthorizedKeysCommand)" /etc/ssh/sshd_config 2>/dev/null || true)
        if [[ -n "$key_configs" ]]; then
            ssh_configs+=("Configurações críticas encontradas")
        fi
    fi
    
    if [[ "$enterprise_ssh" == true ]]; then
        status_message "warning" "SSH EMPRESARIAL DETECTADO"
        echo ""
        
        echo -e "${BLUE}📊 Configurações empresariais:${NC}"
        for config in "${ssh_configs[@]}"; do
            echo "   $config"
        done
        echo ""
        
        important_warning "SSH pode ter configurações mandatórias da empresa"
        
        bullet_list \
            "AuthorizedKeysCommand pode estar em uso" \
            "Políticas de autenticação podem ser obrigatórias" \
            "Hardening adicional pode conflitar" \
            "RECOMENDAÇÃO: Não alterar configurações SSH"
        
        if ! confirm "Aplicar hardening SSH adicional? (pode conflitar com políticas)" "n"; then
            SKIP_SSH_HARDENING=true
            status_message "success" "SSH: Mantendo configurações empresariais"
        else
            status_message "warning" "SSH: Aplicando hardening (verificar após alterações)"
        fi
    else
        status_message "success" "SSH padrão detectado - hardening seguro"
    fi
    
    # Fail2ban
    echo ""
    echo -e "${YELLOW}🔍 PROTEÇÃO ADICIONAL: Fail2ban${NC}"
    bullet_list \
        "Protege contra ataques de força bruta SSH" \
        "Pode gerar alertas no SOC da empresa" \
        "Configuração conservadora por padrão"
    
    if ! confirm "Instalar fail2ban? (pode gerar alertas de segurança)" "y"; then
        echo -e "${BLUE}   → Fail2ban não será instalado${NC}"
    else
        echo -e "${BLUE}   → Fail2ban será configurado conservadoramente${NC}"
    fi
    
    echo ""
}

# =============================================================================
# VERIFICAÇÃO DE CONFLITOS DNS
# =============================================================================

check_dns_conflicts() {
    section_header "Verificação de Conflitos DNS" "$SYMBOL_NETWORK"
    
    local current_dns=""
    local dns_method="systemd-resolved"
    
    # Detectar configuração DNS atual
    if [[ -f /etc/systemd/resolved.conf ]]; then
        current_dns=$(grep "^DNS=" /etc/systemd/resolved.conf 2>/dev/null | cut -d= -f2 || echo "")
    fi
    
    # DNS alternativo se systemd-resolved não configurado
    if [[ -z "$current_dns" ]] && [[ -f /etc/resolv.conf ]]; then
        current_dns=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | head -2 | tr '\n' ' ' || echo "")
        dns_method="resolv.conf"
    fi
    
    echo -e "${BLUE}📊 Configuração DNS atual:${NC}"
    bullet_list \
        "Método: $dns_method" \
        "Servidores: ${current_dns:-"auto/DHCP"}" \
        "Status systemd-resolved: $(systemctl is-active systemd-resolved 2>/dev/null || echo "inativo")"
    
    echo ""
    
    # Verificar se é DNS empresarial
    local is_enterprise_dns=false
    if [[ -n "$current_dns" ]]; then
        # DNS empresariais comuns (ranges privados)
        if [[ "$current_dns" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
            is_enterprise_dns=true
        # DNS conhecidos empresariais
        elif [[ "$current_dns" =~ (8\.8\.8\.8|1\.1\.1\.1|9\.9\.9\.9) ]]; then
            is_enterprise_dns=false
        else
            # DNS não-padrão pode ser empresarial
            is_enterprise_dns=true
        fi
    fi
    
    if [[ "$is_enterprise_dns" == true ]]; then
        status_message "warning" "DNS EMPRESARIAL DETECTADO"
        echo ""
        
        important_warning "DNS atual pode ser mandatório da empresa"
        
        bullet_list \
            "DNS interno pode ser necessário para recursos empresariais" \
            "Mudança pode quebrar acesso a sistemas internos" \
            "VPN pode forçar DNS específico" \
            "RECOMENDAÇÃO: Manter DNS atual"
        
        if ! confirm "Substituir por DNS otimizado (CloudFlare + Google)?" "n"; then
            SKIP_DNS_CONFIG=true
            status_message "success" "DNS: Mantendo configuração empresarial"
        else
            status_message "warning" "DNS: Substituindo (monitorizar acesso a recursos internos)"
        fi
    else
        status_message "info" "DNS padrão/público detectado"
        
        echo -e "${YELLOW}🔍 OTIMIZAÇÃO DISPONÍVEL: DNS Rápido${NC}"
        bullet_list \
            "CloudFlare (1.1.1.1) + Google (8.8.8.8)" \
            "Resolução DNS mais rápida" \
            "Melhor privacidade que ISP" \
            "Configuração via systemd-resolved"
        
        if confirm "Aplicar DNS otimizado?" "y"; then
            status_message "success" "DNS: Será otimizado para CloudFlare + Google"
        else
            SKIP_DNS_CONFIG=true
            status_message "info" "DNS: Mantendo configuração atual"
        fi
    fi
    
    echo ""
}

# =============================================================================
# VERIFICAÇÃO DE CONFLITOS FIREWALL
# =============================================================================

check_firewall_conflicts() {
    section_header "Verificação de Conflitos Firewall" "$SYMBOL_SHIELD"
    
    local firewall_active=false
    local rule_count=0
    local firewall_type=""
    
    # Verificar UFW
    if command_exists ufw; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            firewall_active=true
            firewall_type="UFW"
            rule_count=$(ufw status numbered 2>/dev/null | grep -E "^\[" | wc -l)
        fi
    fi
    
    # Verificar iptables direto
    if [[ "$firewall_active" == false ]] && command_exists iptables; then
        local iptables_rules=$(iptables -L | wc -l)
        if [[ $iptables_rules -gt 10 ]]; then
            firewall_active=true
            firewall_type="iptables"
            rule_count=$iptables_rules
        fi
    fi
    
    if [[ "$firewall_active" == false ]]; then
        status_message "info" "Firewall não ativo - configuração segura disponível"
        return 0
    fi
    
    status_message "info" "Firewall ativo: $firewall_type com $rule_count regras"
    
    # Analisar se é empresarial
    local is_enterprise_firewall=false
    if [[ $rule_count -gt 20 ]]; then
        is_enterprise_firewall=true
    fi
    
    # Verificar regras suspeitas de serem empresariais
    if [[ "$firewall_type" == "UFW" ]]; then
        local complex_rules=$(ufw status 2>/dev/null | grep -E "(DENY|REJECT)" | wc -l)
        if [[ $complex_rules -gt 5 ]]; then
            is_enterprise_firewall=true
        fi
    fi
    
    if [[ "$is_enterprise_firewall" == true ]]; then
        status_message "warning" "FIREWALL EMPRESARIAL DETECTADO"
        echo ""
        
        echo -e "${BLUE}📊 Estatísticas do firewall:${NC}"
        bullet_list \
            "Tipo: $firewall_type" \
            "Regras totais: $rule_count" \
            "Regras DENY/REJECT: $(ufw status 2>/dev/null | grep -E "(DENY|REJECT)" | wc -l || echo "N/A")"
        
        echo ""
        important_warning "Firewall com muitas regras pode ser mandatório da empresa"
        
        bullet_list \
            "Reset pode quebrar conectividade empresarial" \
            "Regras podem ser obrigatórias por política" \
            "RECOMENDAÇÃO: Não alterar firewall existente" \
            "Apenas adicionar regras de desenvolvimento se necessário"
        
        if ! confirm "Resetar e aplicar configuração padrão?" "n"; then
            SKIP_FIREWALL_CONFIG=true
            status_message "success" "Firewall: Mantendo configuração empresarial"
        else
            status_message "warning" "Firewall: Reset agendado (verificar conectividade após)"
        fi
    else
        status_message "info" "Firewall simples detectado - otimização segura"
        
        echo -e "${YELLOW}🔍 OTIMIZAÇÃO DISPONÍVEL: Firewall para Desenvolvimento${NC}"
        bullet_list \
            "Configuração UFW básica e segura" \
            "Permite SSH se ativo" \
            "Permite portas de desenvolvimento (3000-3999, 8000-8999)" \
            "Logging ativado para monitorização"
        
        if confirm "Aplicar configuração de firewall para desenvolvimento?" "y"; then
            status_message "success" "Firewall: Será otimizado para desenvolvimento"
        else
            SKIP_FIREWALL_CONFIG=true
            status_message "info" "Firewall: Mantendo configuração atual"
        fi
    fi
    
    echo ""
}

# =============================================================================
# VERIFICAÇÃO EXTENSIVA PARA MODO EMPRESARIAL
# =============================================================================

check_enterprise_conflicts_extensive() {
    log_header "🏢 VERIFICAÇÃO EXTENSIVA DE CONFLITOS EMPRESARIAIS"
    
    echo ""
    echo -e "${BLUE}Esta verificação vai analisar em detalhe:${NC}"
    bullet_list \
        "Ambiente de rede (VPN, proxy, DNS)" \
        "Configurações Docker empresariais" \
        "Políticas SSH e certificados" \
        "Firewall e regras de segurança" \
        "Indicadores de gestão empresarial"
    
    echo ""
    
    # Executar todas as verificações
    local enterprise_score
    enterprise_score=$(detect_enterprise_environment)
    
    check_vpn_conflicts
    check_docker_conflicts  
    check_ssh_conflicts
    check_dns_conflicts
    check_firewall_conflicts
    
    # Verificações adicionais para modo empresarial
    check_certificate_management
    check_system_monitoring
    check_package_management
    
    # Resumo final
    show_enterprise_summary "$enterprise_score"
}

check_certificate_management() {
    section_header "Verificação de Gestão de Certificados" "$SYMBOL_SECURITY"
    
    local cert_paths=(
        "/usr/local/share/ca-certificates"
        "/etc/ssl/certs/ca-certificates.crt"
        "/etc/ca-certificates"
    )
    
    local enterprise_certs=false
    
    for path in "${cert_paths[@]}"; do
        if [[ -d "$path" ]] && [[ $(find "$path" -name "*.crt" -o -name "*.pem" 2>/dev/null | wc -l) -gt 10 ]]; then
            enterprise_certs=true
            break
        fi
    done
    
    if [[ "$enterprise_certs" == true ]]; then
        status_message "warning" "Certificados empresariais detectados"
        bullet_list \
            "CA certificates customizados instalados" \
            "Pode indicar proxy SSL empresarial" \
            "HTTPS pode ser inspecionado pela empresa"
    else
        status_message "success" "Gestão de certificados padrão"
    fi
    
    echo ""
}

check_system_monitoring() {
    section_header "Verificação de Monitorização do Sistema" "$SYMBOL_GEAR"
    
    local monitoring_tools=(
        "ossec"
        "wazuh"
        "auditd"
        "aide"
        "rkhunter"
        "chkrootkit"
    )
    
    local found_monitoring=()
    
    for tool in "${monitoring_tools[@]}"; do
        if command_exists "$tool" || package_is_installed "$tool"; then
            found_monitoring+=("$tool")
        fi
    done
    
    if [[ ${#found_monitoring[@]} -gt 0 ]]; then
        status_message "warning" "Ferramentas de monitorização detectadas: ${found_monitoring[*]}"
        bullet_list \
            "Sistema pode estar sob monitorização empresarial" \
            "Alterações podem gerar alertas" \
            "RECOMENDAÇÃO: Modo conservador obrigatório"
    else
        status_message "success" "Sem ferramentas de monitorização empresarial detectadas"
    fi
    
    echo ""
}

check_package_management() {
    section_header "Verificação de Gestão de Pacotes" "$SYMBOL_GEAR"
    
    local enterprise_repos=false
    
    # Verificar repositórios customizados
    if [[ -d /etc/apt/sources.list.d ]]; then
        local custom_repos=$(find /etc/apt/sources.list.d -name "*.list" -exec grep -l "corp\|company\|enterprise\|internal" {} \; 2>/dev/null | wc -l)
        if [[ $custom_repos -gt 0 ]]; then
            enterprise_repos=true
        fi
    fi
    
    # Verificar configurações apt empresariais
    if [[ -f /etc/apt/apt.conf ]] && grep -qE "Proxy|proxy" /etc/apt/apt.conf 2>/dev/null; then
        enterprise_repos=true
    fi
    
    if [[ "$enterprise_repos" == true ]]; then
        status_message "warning" "Repositórios empresariais detectados"
        bullet_list \
            "Repositórios internos podem estar configurados" \
            "Proxy apt pode estar em uso" \
            "Instalação de pacotes pode ser restrita"
    else
        status_message "success" "Gestão de pacotes padrão Ubuntu"
    fi
    
    echo ""
}

# =============================================================================
# RELATÓRIO FINAL DE CONFLITOS
# =============================================================================

show_enterprise_summary() {
    local enterprise_score="$1"
    
    log_header "📊 RESUMO DA VERIFICAÇÃO EMPRESARIAL"
    
    echo -e "${BLUE}🎯 SCORE EMPRESARIAL: $enterprise_score${NC}"
    echo ""
    
    # Classificação
    if [[ $enterprise_score -ge 5 ]]; then
        status_message "warning" "AMBIENTE ALTAMENTE EMPRESARIAL"
        echo -e "${YELLOW}   → Modo conservador OBRIGATÓRIO${NC}"
        echo -e "${YELLOW}   → Apenas mudanças essenciais e seguras${NC}"
    elif [[ $enterprise_score -ge 3 ]]; then
        status_message "info" "AMBIENTE POSSIVELMENTE EMPRESARIAL"
        echo -e "${BLUE}   → Verificações adicionais aplicadas${NC}"
        echo -e "${BLUE}   → Otimizações conservadoras recomendadas${NC}"
    else
        status_message "success" "AMBIENTE PESSOAL/PADRÃO"
        echo -e "${GREEN}   → Otimizações completas seguras${NC}"
    fi
    
    echo ""
    
    # Resumo de skips
    echo -e "${BLUE}🔧 CONFIGURAÇÕES A APLICAR:${NC}"
    echo ""
    
    if [[ "$SKIP_DNS_CONFIG" == true ]]; then
        status_message "info" "DNS: Mantendo configuração atual (conflito detectado)"
    else
        status_message "success" "DNS: Aplicando otimização CloudFlare + Google"
    fi
    
    if [[ "$SKIP_NETWORK_CONFIG" == true ]]; then
        status_message "info" "Rede: Mantendo buffers padrão Ubuntu (conflito detectado)"
    else
        status_message "success" "Rede: Aplicando buffers otimizados"
    fi
    
    if [[ "$SKIP_SSH_HARDENING" == true ]]; then
        status_message "info" "SSH: Mantendo configuração atual (políticas empresariais)"
    else
        status_message "success" "SSH: Aplicando hardening de segurança"
    fi
    
    if [[ "$SKIP_FIREWALL_CONFIG" == true ]]; then
        status_message "info" "Firewall: Mantendo configuração atual (regras empresariais)"
    else
        status_message "success" "Firewall: Aplicando configuração para desenvolvimento"
    fi
    
    echo ""
    
    # Recomendações finais
    echo -e "${GREEN}💡 RECOMENDAÇÕES FINAIS:${NC}"
    echo ""
    
    if [[ "$ENTERPRISE_MODE" == true ]]; then
        bullet_list \
            "Usar apenas ferramentas da comunidade (TLP, auto-cpufreq)" \
            "Evitar alterações de rede e DNS" \
            "Manter configurações SSH/firewall existentes" \
            "Focar em otimizações de desenvolvimento (inotify, limits)" \
            "Criar backup completo antes de qualquer alteração"
    else
        bullet_list \
            "Otimizações completas são seguras" \
            "Monitorizar sistema após alterações" \
            "Testar conectividade VPN se aplicável" \
            "Backup criado automaticamente"
    fi
    
    echo ""
}

# =============================================================================
# APLICAR CONFIGURAÇÕES SEGURAS EMPRESARIAIS
# =============================================================================

apply_safe_enterprise_configs() {
    section_header "Aplicando Configurações Seguras" "$SYMBOL_GEAR"
    
    echo ""
    echo -e "${BLUE}Configurações seguras para ambiente empresarial:${NC}"
    bullet_list \
        "Apenas inotify watches (crítico para IDEs)" \
        "Limites conservadores de file descriptors" \
        "Configurações básicas de desenvolvimento" \
        "Scripts utilitários (sempre seguros)"
    
    echo ""
    
    if ! confirm "Aplicar configurações seguras?" "y"; then
        return 0
    fi
    
    # inotify watches (sempre seguro e crítico)
    local watches=262144
    [[ $(get_ram_gb) -ge 8 ]] && watches=524288
    
    safe_write_config "/etc/sysctl.d/99-dev-inotify-safe.conf" \
        "# inotify watches para desenvolvimento (configuração empresarial segura)
fs.inotify.max_user_watches=$watches
fs.inotify.max_user_instances=512"
    
    sudo sysctl -p /etc/sysctl.d/99-dev-inotify-safe.conf >/dev/null 2>&1
    
    # Limites conservadores
    safe_write_config "/etc/security/limits.d/99-dev-enterprise-safe.conf" \
        "# Limites seguros para desenvolvimento empresarial
* soft nofile 32768
* hard nofile 65536
* soft nproc 16384
* hard nproc 32768"
    
    log_success "Configurações empresariais seguras aplicadas"
}

export_enterprise_settings() {
    # Exportar configurações para outros módulos
    export ENTERPRISE_MODE
    export SKIP_DNS_CONFIG
    export SKIP_NETWORK_CONFIG
    export SKIP_SSH_HARDENING
    export SKIP_FIREWALL_CONFIG
    
    # Criar ficheiro de estado para outros scripts
    sudo tee /tmp/enterprise-mode-settings > /dev/null << EOF
ENTERPRISE_MODE=$ENTERPRISE_MODE
SKIP_DNS_CONFIG=$SKIP_DNS_CONFIG
SKIP_NETWORK_CONFIG=$SKIP_NETWORK_CONFIG
SKIP_SSH_HARDENING=$SKIP_SSH_HARDENING
SKIP_FIREWALL_CONFIG=$SKIP_FIREWALL_CONFIG
EOF
}

# =============================================================================
# FUNÇÃO PRINCIPAL DO MÓDULO
# =============================================================================

check_enterprise_conflicts() {
    if ! confirm "Executar verificação de conflitos empresariais?" "y"; then
        log_info "Verificação empresarial ignorada"
        return 0
    fi
    
    check_enterprise_conflicts_extensive
    
    # Exportar configurações para outros módulos
    export_enterprise_settings
    
    echo ""
    if [[ "$ENTERPRISE_MODE" == true ]]; then
        important_warning "Modo empresarial ativado - apenas otimizações conservadoras serão aplicadas"
        
        if confirm "Aplicar configurações seguras agora?" "y"; then
            apply_safe_enterprise_configs
        fi
    else
        log_success "Verificação completa - otimizações seguras identificadas"
    fi
    
    pause_and_return
}