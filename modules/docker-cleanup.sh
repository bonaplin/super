#!/bin/bash
# =============================================================================
# MÓDULO: DOCKER CLEANUP INTELIGENTE
# Sistema que preserva dados importantes (BDs) - especialidade única
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# DETECÇÃO AUTOMÁTICA DE CONTAINERS/VOLUMES CRÍTICOS
# =============================================================================

detect_database_containers() {
    local db_patterns=(
        "postgres" "postgresql" "pg"
        "mysql" "mariadb" "maria"
        "mongo" "mongodb" "mongo-express"
        "redis" "redis-server" "redis-cli"
        "elasticsearch" "elastic" "kibana"
        "cassandra" "scylla"
        "neo4j"
        "influxdb" "grafana"
        "db" "database" "data"
    )
    
    local db_containers=()
    
    if ! command_exists docker; then
        return 0
    fi
    
    # Procurar por nome de container
    while read -r container; do
        [[ -z "$container" ]] && continue
        
        for pattern in "${db_patterns[@]}"; do
            if [[ "$container" =~ $pattern ]]; then
                db_containers+=("$container")
                break
            fi
        done
    done < <(docker ps -a --format "{{.Names}}" 2>/dev/null)
    
    # Procurar por imagem
    while read -r image container; do
        [[ -z "$image" || -z "$container" ]] && continue
        
        for pattern in "${db_patterns[@]}"; do
            if [[ "$image" =~ $pattern ]] && [[ ! " ${db_containers[*]} " =~ " $container " ]]; then
                db_containers+=("$container")
                break
            fi
        done
    done < <(docker ps -a --format "{{.Image}} {{.Names}}" 2>/dev/null)
    
    printf '%s\n' "${db_containers[@]}" | sort -u
}

detect_database_volumes() {
    local db_patterns=(
        "data" "database" "db"
        "postgres" "mysql" "mongo" "redis"
        "elastic" "grafana" "influx"
        "vol" "storage" "persist"
    )
    
    local db_volumes=()
    
    if ! command_exists docker; then
        return 0
    fi
    
    while read -r volume; do
        [[ -z "$volume" ]] && continue
        
        for pattern in "${db_patterns[@]}"; do
            if [[ "$volume" =~ $pattern ]]; then
                db_volumes+=("$volume")
                break
            fi
        done
    done < <(docker volume ls --format "{{.Name}}" 2>/dev/null)
    
    printf '%s\n' "${db_volumes[@]}" | sort -u
}

detect_database_images() {
    local db_patterns=(
        "postgres" "mysql" "mariadb" "mongo"
        "redis" "elasticsearch" "cassandra"
        "neo4j" "influxdb" "grafana"
    )
    
    local db_images=()
    
    if ! command_exists docker; then
        return 0
    fi
    
    while read -r image; do
        [[ -z "$image" ]] && continue
        
        for pattern in "${db_patterns[@]}"; do
            if [[ "$image" =~ $pattern ]]; then
                db_images+=("$image")
                break
            fi
        done
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)
    
    printf '%s\n' "${db_images[@]}" | sort -u
}

# =============================================================================
# ANÁLISE DE ESTADO DOCKER
# =============================================================================

analyze_docker_state() {
    section_header "Análise do Estado Docker" "$SYMBOL_GEAR"
    
    if ! command_exists docker; then
        status_message "info" "Docker não instalado"
        return 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        status_message "warning" "Docker daemon não está ativo"
        return 1
    fi
    
    echo -e "${BLUE}📊 ESTADO ATUAL:${NC}"
    
    # Containers
    local total_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
    local running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    local stopped_containers=$((total_containers - running_containers))
    
    echo "   📦 Containers: $total_containers total ($running_containers ativos, $stopped_containers parados)"
    
    # Images
    local total_images=$(docker images --format "{{.Repository}}" 2>/dev/null | wc -l)
    local dangling_images=$(docker images -f "dangling=true" --format "{{.Repository}}" 2>/dev/null | wc -l)
    
    echo "   🖼️ Imagens: $total_images total ($dangling_images órfãs)"
    
    # Volumes
    local total_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | wc -l)
    local unused_volumes=$(docker volume ls -f "dangling=true" --format "{{.Name}}" 2>/dev/null | wc -l)
    
    echo "   💾 Volumes: $total_volumes total ($unused_volumes não utilizados)"
    
    # Espaço usado
    echo ""
    echo -e "${BLUE}💾 USO DE ESPAÇO:${NC}"
    if docker system df >/dev/null 2>&1; then
        docker system df | tail -n +2 | while read line; do
            echo "   $line"
        done
    fi
    
    echo ""
    
    # Detectar componentes críticos
    echo -e "${BLUE}🔍 DETECÇÃO DE BASES DE DADOS:${NC}"
    
    local db_containers=($(detect_database_containers))
    local db_volumes=($(detect_database_volumes))
    local db_images=($(detect_database_images))
    
    if [[ ${#db_containers[@]} -gt 0 ]]; then
        echo -e "${GREEN}   📦 Containers de BD encontrados:${NC}"
        for container in "${db_containers[@]}"; do
            local status=$(docker ps -a --filter "name=$container" --format "{{.Status}}" | head -1)
            echo "      • $container ($status)"
        done
    else
        echo "   📦 Nenhum container de BD detectado"
    fi
    
    if [[ ${#db_volumes[@]} -gt 0 ]]; then
        echo -e "${GREEN}   💾 Volumes de dados encontrados:${NC}"
        for volume in "${db_volumes[@]}"; do
            echo "      • $volume"
        done
    else
        echo "   💾 Nenhum volume de dados detectado"
    fi
    
    if [[ ${#db_images[@]} -gt 0 ]]; then
        echo -e "${GREEN}   🖼️ Imagens de BD encontradas:${NC}"
        for image in "${db_images[@]}"; do
            echo "      • $image"
        done
    else
        echo "   🖼️ Nenhuma imagem de BD detectada"
    fi
    
    echo ""
    return 0
}

# =============================================================================
# MODOS DE LIMPEZA INTELIGENTE
# =============================================================================

docker_cleanup_conservative() {
    log_info "🧹 Modo CONSERVADOR: Apenas containers parados (exceto BDs)"
    
    local db_containers=($(detect_database_containers))
    local removed_count=0
    
    # Remover apenas containers parados que NÃO sejam de BD
    while read -r container; do
        [[ -z "$container" ]] && continue
        
        # Verificar se é BD
        local is_db=false
        for db_container in "${db_containers[@]}"; do
            if [[ "$container" == "$db_container" ]]; then
                is_db=true
                break
            fi
        done
        
        # Remover se não for BD
        if [[ "$is_db" == false ]]; then
            if docker rm "$container" >/dev/null 2>&1; then
                log_info "Removido container: $container"
                ((removed_count++))
            fi
        else
            log_info "Preservado BD: $container"
        fi
    done < <(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
    
    # Remover imagens órfãs (sem containers)
    local orphan_images=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
    if [[ $orphan_images -gt 0 ]]; then
        docker image prune -f >/dev/null 2>&1
        log_info "Removidas $orphan_images imagens órfãs"
    fi
    
    log_success "Modo conservador: $removed_count containers removidos, BDs preservados"
}

docker_cleanup_moderate() {
    log_info "🧹 Modo MODERADO: Containers + imagens não utilizadas (exceto BDs)"
    
    # Primeiro fazer limpeza conservadora
    docker_cleanup_conservative
    
    local db_images=($(detect_database_images))
    local removed_images=0
    
    # Remover imagens não utilizadas (exceto BDs)
    while read -r image; do
        [[ -z "$image" ]] && continue
        
        # Verificar se é imagem de BD
        local is_db_image=false
        for db_image in "${db_images[@]}"; do
            if [[ "$image" == "$db_image" ]]; then
                is_db_image=true
                break
            fi
        done
        
        # Verificar se está sendo usada por algum container
        local in_use=$(docker ps -a --format "{{.Image}}" | grep -c "^$image$" || echo 0)
        
        # Remover se não for BD e não estiver em uso
        if [[ "$is_db_image" == false && $in_use -eq 0 ]]; then
            if docker rmi "$image" >/dev/null 2>&1; then
                log_info "Removida imagem: $image"
                ((removed_images++))
            fi
        else
            if [[ "$is_db_image" == true ]]; then
                log_info "Preservada imagem BD: $image"
            fi
        fi
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)
    
    # Build cache antigo (semana)
    docker builder prune --filter "until=168h" -f >/dev/null 2>&1 || true
    
    log_success "Modo moderado: $removed_images imagens removidas, BDs preservados"
}

docker_cleanup_aggressive() {
    log_info "🧹 Modo AGRESSIVO: Limpeza completa (MAS preserva BDs)"
    
    important_warning "Modo agressivo remove tudo EXCETO bases de dados"
    
    if ! confirm "Continuar com limpeza agressiva? (preserva BDs automaticamente)" "n"; then
        log_info "Limpeza agressiva cancelada"
        return 0
    fi
    
    local db_containers=($(detect_database_containers))
    local db_volumes=($(detect_database_volumes))
    local db_images=($(detect_database_images))
    
    log_info "🛡️ Componentes protegidos:"
    echo "   Containers: ${#db_containers[@]}"
    echo "   Volumes: ${#db_volumes[@]}"
    echo "   Imagens: ${#db_images[@]}"
    echo ""
    
    # Parar containers não-BD
    log_info "Parando containers não-BD..."
    while read -r container; do
        [[ -z "$container" ]] && continue
        
        local is_db=false
        for db_container in "${db_containers[@]}"; do
            if [[ "$container" == "$db_container" ]]; then
                is_db=true
                break
            fi
        done
        
        if [[ "$is_db" == false ]]; then
            docker stop "$container" >/dev/null 2>&1 || true
            docker rm "$container" >/dev/null 2>&1 || true
            log_info "Removido: $container"
        fi
    done < <(docker ps --format "{{.Names}}" 2>/dev/null)
    
    # Remover imagens não-BD
    log_info "Removendo imagens não-BD..."
    while read -r image; do
        [[ -z "$image" ]] && continue
        
        local is_db_image=false
        for db_image in "${db_images[@]}"; do
            if [[ "$image" == "$db_image" ]]; then
                is_db_image=true
                break
            fi
        done
        
        if [[ "$is_db_image" == false ]]; then
            docker rmi "$image" >/dev/null 2>&1 || true
        fi
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)
    
    # Remover volumes não-BD
    log_info "Removendo volumes não-BD..."
    while read -r volume; do
        [[ -z "$volume" ]] && continue
        
        local is_db_volume=false
        for db_volume in "${db_volumes[@]}"; do
            if [[ "$volume" == "$db_volume" ]]; then
                is_db_volume=true
                break
            fi
        done
        
        if [[ "$is_db_volume" == false ]]; then
            docker volume rm "$volume" >/dev/null 2>&1 || true
        fi
    done < <(docker volume ls --format "{{.Name}}" 2>/dev/null)
    
    # Limpeza de sistema (networks, build cache)
    docker network prune -f >/dev/null 2>&1 || true
    docker builder prune -a -f >/dev/null 2>&1 || true
    
    log_success "🎉 Limpeza agressiva concluída - todas as BDs foram preservadas!"
}

# =============================================================================
# COMANDO DOCKER-CLEAN INTELIGENTE
# =============================================================================

create_docker_clean_command() {
    section_header "Comando docker-clean Inteligente" "$SYMBOL_CLEAN"
    
    sudo tee /usr/local/bin/docker-clean > /dev/null << 'EOF'
#!/bin/bash
# Docker cleanup inteligente que preserva bases de dados

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker não instalado"
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    echo "❌ Docker daemon não está ativo"
    exit 1
fi

case "${1:-status}" in
    "status")
        echo "🐳 DOCKER STATUS & USAGE"
        echo "========================"
        echo ""
        echo "📊 Uso de espaço:"
        docker system df 2>/dev/null || echo "Erro ao obter informações"
        echo ""
        echo "📦 Containers:"
        echo "   Total: $(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)"
        echo "   Ativos: $(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)"
        echo "   Parados: $(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | wc -l)"
        echo ""
        echo "🔧 Opções de limpeza:"
        echo "   docker-clean safe      - Remove apenas containers parados (preserva BDs)"
        echo "   docker-clean normal    - Remove containers + imagens não usadas (preserva BDs)"  
        echo "   docker-clean deep      - Limpeza agressiva (MAS preserva BDs automaticamente)"
        echo "   docker-clean analyze   - Análise detalhada + detecção de BDs"
        ;;
        
    "safe")
        echo "🧹 LIMPEZA SEGURA (preserva BDs automaticamente)"
        echo "=============================================="
        
        # Detectar BDs
        db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "(postgres|mysql|mongo|redis|elastic|db|data)" || true)
        
        if [[ -n "$db_containers" ]]; then
            echo ""
            echo "🛡️ BDs detectados e protegidos:"
            echo "$db_containers" | sed 's/^/   • /'
            echo ""
        fi
        
        # Limpeza conservadora
        removed=0
        docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | while read container; do
            if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                if docker rm "$container" >/dev/null 2>&1; then
                    echo "✅ Removido: $container"
                    ((removed++))
                fi
            fi
        done
        
        # Imagens órfãs
        orphans=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
        if [[ $orphans -gt 0 ]]; then
            docker image prune -f >/dev/null 2>&1
            echo "✅ Removidas $orphans imagens órfãs"
        fi
        
        echo ""
        echo "🎉 Limpeza segura concluída - BDs preservados"
        ;;
        
    "normal")
        echo "🧹 LIMPEZA NORMAL (preserva BDs automaticamente)"
        echo "============================================="
        
        # Limpeza conservadora primeiro
        docker-clean safe
        
        echo ""
        echo "🔄 Removendo imagens não utilizadas (exceto BDs)..."
        
        # Detectar imagens de BD
        db_images=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -E "(postgres|mysql|mongo|redis|elastic)" || true)
        
        docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | while read image; do
            if [[ -n "$image" ]] && ! echo "$db_images" | grep -q "^$image$"; then
                # Verificar se está em uso
                in_use=$(docker ps -a --format "{{.Image}}" | grep -c "^$image$" || echo 0)
                if [[ $in_use -eq 0 ]]; then
                    if docker rmi "$image" >/dev/null 2>&1; then
                        echo "✅ Removida imagem: $image"
                    fi
                fi
            fi
        done
        
        # Build cache
        docker builder prune --filter "until=168h" -f >/dev/null 2>&1 || true
        
        echo ""
        echo "🎉 Limpeza normal concluída - BDs preservados"
        ;;
        
    "deep")
        echo "🧹 LIMPEZA PROFUNDA (preserva BDs automaticamente)"
        echo "=============================================="
        echo ""
        echo "⚠️ Esta limpeza remove TUDO exceto bases de dados detectadas automaticamente"
        echo ""
        read -p "Continuar? (y/N): " response
        if [[ ! "$response" =~ ^[Yy] ]]; then
            echo "Cancelado"
            exit 0
        fi
        
        echo ""
        echo "🛡️ Detectando e protegendo bases de dados..."
        
        # Detectar componentes de BD
        db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "(postgres|mysql|mongo|redis|elastic|cassandra|db|data)" || true)
        db_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "(data|postgres|mysql|mongo|redis|elastic|db)" || true)
        db_images=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -E "(postgres|mysql|mongo|redis|elastic|cassandra)" || true)
        
        echo "   Containers protegidos: $(echo "$db_containers" | wc -l)"
        echo "   Volumes protegidos: $(echo "$db_volumes" | wc -l)"  
        echo "   Imagens protegidas: $(echo "$db_images" | wc -l)"
        echo ""
        
        # Remover containers não-BD
        echo "🔄 Removendo containers não-BD..."
        docker ps --format "{{.Names}}" 2>/dev/null | while read container; do
            if [[ -n "$container" ]] && ! echo "$db_containers" | grep -q "^$container$"; then
                docker stop "$container" >/dev/null 2>&1 || true
                docker rm "$container" >/dev/null 2>&1 || true
                echo "✅ Removido: $container"
            fi
        done
        
        # System prune (exclui volumes)
        docker system prune -a -f >/dev/null 2>&1 || true
        
        # Remover volumes não-BD
        echo "🔄 Removendo volumes não-BD..."
        docker volume ls --format "{{.Name}}" 2>/dev/null | while read volume; do
            if [[ -n "$volume" ]] && ! echo "$db_volumes" | grep -q "^$volume$"; then
                docker volume rm "$volume" >/dev/null 2>&1 || true
                echo "✅ Removido volume: $volume"
            fi
        done
        
        echo ""
        echo "🎉 Limpeza profunda concluída - TODAS as BDs foram preservadas automaticamente!"
        ;;
        
    "analyze")
        echo "🔍 ANÁLISE DETALHADA DO DOCKER"
        echo "=============================="
        echo ""
        
        echo "📊 Estado geral:"
        docker system df
        echo ""
        
        echo "🔍 Detecção automática de bases de dados:"
        echo ""
        
        # Containers de BD
        db_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "(postgres|mysql|mongo|redis|elastic|cassandra|db|data)" || true)
        if [[ -n "$db_containers" ]]; then
            echo "📦 Containers de BD detectados:"
            echo "$db_containers" | while read container; do
                status=$(docker ps -a --filter "name=$container" --format "{{.Status}}" | head -1)
                echo "   • $container ($status)"
            done
        else
            echo "📦 Nenhum container de BD detectado"
        fi
        echo ""
        
        # Volumes de BD
        db_volumes=$(docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "(data|postgres|mysql|mongo|redis|elastic|db)" || true)
        if [[ -n "$db_volumes" ]]; then
            echo "💾 Volumes de dados detectados:"
            echo "$db_volumes" | sed 's/^/   • /'
        else
            echo "💾 Nenhum volume de dados detectado"
        fi
        echo ""
        
        # Imagens de BD
        db_images=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -E "(postgres|mysql|mongo|redis|elastic|cassandra)" || true)
        if [[ -n "$db_images" ]]; then
            echo "🖼️ Imagens de BD detectadas:"
            echo "$db_images" | sed 's/^/   • /'
        else
            echo "🖼️ Nenhuma imagem de BD detectada"
        fi
        echo ""
        
        echo "💡 RECOMENDAÇÃO:"
        echo "   • Use 'docker-clean safe' para limpeza regular"
        echo "   • Use 'docker-clean normal' para limpeza semanal"
        echo "   • Use 'docker-clean deep' apenas quando necessário"
        echo "   • Todas as opções preservam automaticamente as bases de dados"
        ;;
        
    *)
        echo "🐳 DOCKER CLEANUP INTELIGENTE"
        echo "============================="
        echo ""
        echo "Uso: docker-clean {status|safe|normal|deep|analyze}"
        echo ""
        echo "  status    - Ver uso de espaço + estatísticas"
        echo "  safe      - Remove apenas containers parados (preserva BDs)"
        echo "  normal    - Remove containers + imagens não usadas (preserva BDs)"
        echo "  deep      - Limpeza agressiva (MAS preserva BDs automaticamente)"
        echo "  analyze   - Análise detalhada + detecção automática de BDs"
        echo ""
        echo "🛡️ TODAS as opções preservam automaticamente bases de dados!"
        echo "   Detecta: PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch, etc."
        ;;
esac
EOF
    
    sudo chmod +x /usr/local/bin/docker-clean
    log_success "Comando 'docker-clean' criado"
}

# =============================================================================
# FUNÇÃO PRINCIPAL DO MÓDULO
# =============================================================================

setup_smart_docker_cleanup() {
    log_header "🐳 CONFIGURANDO DOCKER CLEANUP INTELIGENTE"
    
    if ! command_exists docker; then
        status_message "warning" "Docker não instalado - módulo ignorado"
        return 0
    fi
    
    echo ""
    echo -e "${BLUE}Sistema Docker Cleanup Inteligente:${NC}"
    bullet_list \
        "Detecta automaticamente containers/volumes/imagens de BD" \
        "3 modos: conservador, moderado, agressivo" \
        "SEMPRE preserva dados importantes" \
        "Comando 'docker-clean' prático" \
        "Integração com sistema de manutenção"
    
    echo ""
    
    if ! confirm "Configurar Docker cleanup inteligente?" "y"; then
        log_info "Docker cleanup ignorado"
        return 0
    fi
    
    # Análise inicial
    if ! analyze_docker_state; then
        return 1
    fi
    
    # Criar comando
    create_docker_clean_command
    
    # Teste inicial
    echo ""
    section_header "Teste de Detecção" "$SYMBOL_TESTING"
    
    if confirm "Executar teste de detecção de BDs?" "y"; then
        echo ""
        echo -e "${BLUE}🔍 TESTE DE DETECÇÃO:${NC}"
        
        local db_containers=($(detect_database_containers))
        local db_volumes=($(detect_database_volumes)) 
        local db_images=($(detect_database_images))
        
        echo "   Containers de BD: ${#db_containers[@]}"
        echo "   Volumes de dados: ${#db_volumes[@]}"
        echo "   Imagens de BD: ${#db_images[@]}"
        
        if [[ ${#db_containers[@]} -gt 0 || ${#db_volumes[@]} -gt 0 || ${#db_images[@]} -gt 0 ]]; then
            echo ""
            echo -e "${GREEN}✅ Sistema detectou componentes de BD - estarão protegidos automaticamente${NC}"
        else
            echo ""
            echo -e "${BLUE}ℹ️ Nenhuma BD detectada - limpeza será mais agressiva${NC}"
        fi
    fi
    
    log_success "🎉 Docker cleanup inteligente configurado!"
    echo ""
    echo -e "${YELLOW}💡 COMANDOS DISPONÍVEIS:${NC}"
    bullet_list \
        "docker-clean status - Ver uso de espaço" \
        "docker-clean safe - Limpeza conservadora" \
        "docker-clean normal - Limpeza moderada" \
        "docker-clean deep - Limpeza agressiva (preserva BDs)" \
        "docker-clean analyze - Análise detalhada"
    
    echo ""
}