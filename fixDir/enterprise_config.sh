# =============================================================================
# CONFIGURAÇÃO EMPRESARIAL - OVERRIDE SEGURO
# Sobrescreve configurações para máxima compatibilidade empresarial
# =============================================================================

# === MODO CONSERVADOR OBRIGATÓRIO ===
AUTO_ENTERPRISE_MODE="true"
ENTERPRISE_SCORE_THRESHOLD=3
SKIP_CONFLICTS_AUTO="true"

# === CONFIGURAÇÕES DE REDE SEGURAS ===
APPLY_NETWORK_TWEAKS="no"
RMEM_MAX_DEFAULT=212992  # Manter padrão Ubuntu
WMEM_MAX_DEFAULT=212992  # Manter padrão Ubuntu

# === DNS CONSERVADOR ===
# Não alterar DNS por padrão em ambiente empresarial
CONFIGURE_DNS="no"

# === SEGURANÇA CONSERVADORA ===
INSTALL_FAIL2BAN="no"    # Pode gerar alertas SOC
SSH_HARDENING="no"       # Manter políticas empresariais
CONFIGURE_FIREWALL="no"  # Não alterar firewall existente

# === DOCKER SEGURO ===
DOCKER_CLEANUP_MODE="conservative"  # Sempre conservador

# === BACKUP OBRIGATÓRIO ===
AUTO_BACKUP="true"
MAX_BACKUPS=20  # Mais backups em ambiente empresarial

# === FERRAMENTAS SEGURAS ===
INSTALL_MODERN_TOOLS="ask"  # Perguntar sempre
DEFAULT_ANSWER="n"          # Padrão conservador

# === OTIMIZAÇÕES MÍNIMAS ===
# Apenas otimizações comprovadamente seguras
SWAPPINESS_DEFAULT=10
DIRTY_RATIO_DEFAULT=15
VFS_CACHE_PRESSURE=80

# inotify sempre seguro (crítico para IDEs)
INOTIFY_WATCHES_8GB=262144
INOTIFY_WATCHES_16GB=524288

# === LIMITES CONSERVADORES ===
NOFILE_SOFT_DEFAULT=16384
NOFILE_HARD_DEFAULT=32768

# === MANUTENÇÃO CONSERVADORA ===
MAINTENANCE_LOG_RETENTION=30  # Logs mais curtos
ENABLE_DESKTOP_NOTIFICATIONS="false"  # Pode interferir

# === VALIDAÇÃO RIGOROSA ===
CHECK_CONNECTIVITY="true"
DETAILED_LOGGING="true"
PAUSE_AFTER_OPERATIONS="true"

# === MÓDULOS SEGUROS ===
MODULE_ENTERPRISE_CONFLICTS="true"   # Sempre ativo
MODULE_DEVELOPMENT_CONFIG="true"     # Seguro
MODULE_ESSENTIAL_TWEAKS="true"       # Apenas essenciais
MODULE_UTILITY_SCRIPTS="true"        # Sempre úteis
MODULE_SMART_MAINTENANCE="true"      # Conservador
MODULE_DOCKER_CLEANUP="true"         # Com proteções

# === ALERTAS E LOGS ===
LOG_LEVEL="INFO"
ENABLE_NOTIFICATIONS="false"
VERBOSE_PROGRESS="true"

# === PERSONALIZAÇÃO EMPRESARIAL ===
# Estas configurações garantem que mesmo em ambiente empresarial
# o sistema funciona de forma segura e compatível

# Verificação de conflitos mais rigorosa
ENTERPRISE_VPN_CHECK="true"
ENTERPRISE_DNS_CHECK="true"
ENTERPRISE_SSH_CHECK="true"
ENTERPRISE_FIREWALL_CHECK="true"

# Não instalar ferramentas que podem gerar alertas
INSTALL_MONITORING_TOOLS="false"
INSTALL_NETWORK_TOOLS="false"

# Configurações de horário para não interferir com trabalho
DAILY_MAINTENANCE_TIME="30 22"    # 22:30 (fora do horário)
WEEKLY_MAINTENANCE_TIME="30 23"   # 23:30 domingos
MONTHLY_MAINTENANCE_TIME="30 2"   # 02:30 sábados