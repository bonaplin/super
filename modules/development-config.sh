#!/bin/bash
# =============================================================================
# MÓDULO: CONFIGURAÇÕES PARA DESENVOLVIMENTO
# Foca apenas nas configurações que realmente importam para developers
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# INOTIFY WATCHES - CRÍTICO PARA IDES MODERNAS
# =============================================================================

configure_inotify_watches() {
    section_header "inotify Watches - Crítico para IDEs" "$SYMBOL_DEVELOPMENT"
    
    local current_watches=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo 8192)
    local recommended_watches=524288
    
    # Ajustar baseado na RAM
    if [[ $(get_ram_gb) -ge 16 ]]; then
        recommended_watches=1048576
    elif [[ $(get_ram_gb) -ge 8 ]]; then
        recommended_watches=524288
    else
        recommended_watches=262144
    fi
    
    echo -e "${BLUE}📊 Estado atual:${NC}"
    bullet_list \
        "Atual: $current_watches watches" \
        "Recomendado: $recommended_watches watches" \
        "Necessário para: VS Code, WebStorm, Eclipse, etc."
    
    echo ""
    
    if [[ $current_watches -lt $recommended_watches ]]; then
        if confirm "Aumentar inotify watches para $recommended_watches?" "y"; then
            safe_write_config "/etc/sysctl.d/99-dev-inotify.conf" \
                "# inotify watches para desenvolvimento
fs.inotify.max_user_watches=$recommended_watches
fs.inotify.max_user_instances=512"
            
            # Aplicar imediatamente
            sudo sysctl -p /etc/sysctl.d/99-dev-inotify.conf >/dev/null 2>&1
            
            log_success "inotify watches aumentado para $recommended_watches"
        fi
    else
        log_success "inotify watches já otimizado ($current_watches)"
    fi
    
    echo ""
}

# =============================================================================
# LIMITES DE FILE DESCRIPTORS
# =============================================================================

configure_file_limits() {
    section_header "Limites de File Descriptors" "$SYMBOL_GEAR"
    
    local current_soft=$(ulimit -n 2>/dev/null || echo 1024)
    local recommended_soft=65536
    local recommended_hard=131072
    
    # Ajustar baseado no sistema
    if [[ $(get_ram_gb) -ge 16 ]]; then
        recommended_hard=262144
    fi
    
    echo -e "${BLUE}📊 Limites atuais:${NC}"
    bullet_list \
        "Soft limit: $current_soft" \
        "Recomendado soft: $recommended_soft" \
        "Recomendado hard: $recommended_hard"
    
    echo ""
    
    if [[ $current_soft -lt $recommended_soft ]]; then
        if confirm "Configurar limites de file descriptors?" "y"; then
            # Configurar limits.conf
            safe_write_config "/etc/security/limits.d/99-dev-limits.conf" \
                "# Limites para desenvolvimento
* soft nofile $recommended_soft
* hard nofile $recommended_hard
* soft nproc 32768
* hard nproc 65536"
            
            # Configurar systemd
            sudo mkdir -p /etc/systemd/{user,system}.conf.d
            
            echo "[Manager]
DefaultLimitNOFILE=$recommended_hard" | sudo tee /etc/systemd/system.conf.d/dev-limits.conf >/dev/null
            
            echo "[Manager]  
DefaultLimitNOFILE=$recommended_hard" | sudo tee /etc/systemd/user.conf.d/dev-limits.conf >/dev/null
            
            log_success "Limites configurados (aplicados após logout/login)"
        fi
    else
        log_success "Limites já otimizados"
    fi
    
    echo ""
}

# =============================================================================
# CONFIGURAÇÃO GIT BÁSICA
# =============================================================================

configure_git_basics() {
    section_header "Configuração Git Básica" "$SYMBOL_GEAR"
    
    if git config --global user.name >/dev/null 2>&1; then
        local git_user=$(git config --global user.name)
        local git_email=$(git config --global user.email)
        log_success "Git já configurado para: $git_user ($git_email)"
        return 0
    fi
    
    if ! confirm "Configurar Git (nome e email)?" "y"; then
        return 0
    fi
    
    echo ""
    read -p "Nome completo: " git_name
    read -p "Email: " git_email
    
    if [[ -n "$git_name" && -n "$git_email" ]]; then
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        
        # Configurações úteis
        git config --global init.defaultBranch main
        git config --global pull.rebase false
        git config --global core.autocrlf input
        git config --global core.editor vim
        
        log_success "Git configurado: $git_name ($git_email)"
    fi
    
    echo ""
}

# =============================================================================
# ALIASES INTELIGENTES PARA DESENVOLVIMENTO
# =============================================================================

configure_dev_aliases() {
    section_header "Aliases para Desenvolvimento" "$SYMBOL_WRENCH"
    
    local aliases_file="$HOME/.dev_aliases"
    
    if [[ -f "$aliases_file" ]]; then
        if ! confirm "Aliases já existem. Atualizar?" "y"; then
            return 0
        fi
    fi
    
    cat > "$aliases_file" << 'EOF'
# ============================================================================
# ALIASES PARA DESENVOLVIMENTO - FOCADOS E PRÁTICOS
# ============================================================================

# === GIT PRODUTIVO ===
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gb='git branch'
alias gco='git checkout'
alias gd='git diff'

# === DOCKER RÁPIDO ===
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'

# === NODE.JS ===
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'

# === PYTHON ===
alias py='python3'
alias pip='pip3'
alias activate='source venv/bin/activate'

# === SISTEMA ===
alias ll='ls -alF'
alias ..='cd ..'
alias ...='cd ../..'

# === DESENVOLVIMENTO ===
alias serve='python3 -m http.server 8000'
alias ports='ss -tulpn'
alias logs='journalctl -f'

# === FERRAMENTAS MODERNAS ===
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi

if command -v exa >/dev/null 2>&1; then
    alias ls='exa --icons'
    alias ll='exa -la --icons --git'
elif command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -la --icons --git'
fi

# === FUNÇÕES ÚTEIS ===
mkproject() {
    local name="${1:-new-project}"
    mkdir "$name" && cd "$name"
    git init
    echo "# $name" > README.md
    echo "node_modules/" > .gitignore
    echo "✅ Projeto '$name' criado!"
}

portinfo() {
    local port="$1"
    [[ -z "$port" ]] && { echo "Uso: portinfo <porta>"; return 1; }
    lsof -i :$port
}

findproject() {
    find . -name "package.json" -o -name "pom.xml" -o -name "requirements.txt" 2>/dev/null | head -10
}
EOF
    
    # Carregar no bashrc se não existir
    if ! grep -q "source.*\.dev_aliases" ~/.bashrc 2>/dev/null; then
        echo "source ~/.dev_aliases" >> ~/.bashrc
    fi
    
    # Se zsh existir, carregar também
    if [[ -f ~/.zshrc ]] && ! grep -q "source.*\.dev_aliases" ~/.zshrc 2>/dev/null; then
        echo "source ~/.dev_aliases" >> ~/.zshrc
    fi
    
    log_success "Aliases configurados em ~/.dev_aliases"
    echo ""
}

# =============================================================================
# BASH/ZSH HISTORY MELHORADO
# =============================================================================

configure_enhanced_history() {
    section_header "History Melhorado" "$SYMBOL_GEAR"
    
    if grep -q "HISTSIZE=50000" ~/.bashrc 2>/dev/null; then
        log_success "History já otimizado"
        return 0
    fi
    
    if ! confirm "Configurar history melhorado?" "y"; then
        return 0
    fi
    
    # Adicionar ao bashrc
    cat >> ~/.bashrc << 'EOF'

# === BASH HISTORY MELHORADO ===
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTTIMEFORMAT="%d/%m/%y %T "
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ps:history:exit:clear"

shopt -s histappend
shopt -s histverify
shopt -s checkwinsize

# Sincronizar history entre sessões
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF
    
    log_success "History melhorado configurado"
    echo ""
}

# =============================================================================
# VIM CONFIGURAÇÃO BÁSICA
# =============================================================================

configure_vim_basics() {
    section_header "Vim Básico para Desenvolvimento" "$SYMBOL_GEAR"
    
    if [[ -f ~/.vimrc ]] && grep -q "syntax on" ~/.vimrc 2>/dev/null; then
        if ! confirm "Vim já configurado. Sobrescrever?" "n"; then
            return 0
        fi
    fi
    
    cat > ~/.vimrc << 'EOF'
" Configuração Vim para desenvolvimento

" Aparência
syntax on
set number
set cursorline
set showmatch

" Indentação
set autoindent
set tabstop=4
set shiftwidth=4
set expandtab

" Busca
set hlsearch
set incsearch
set ignorecase
set smartcase

" Usabilidade
set backspace=indent,eol,start
set wildmenu
set mouse=a
set clipboard=unnamedplus

" Atalhos úteis
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a

" Para desenvolvimento web
autocmd FileType html,css,javascript,json set tabstop=2 shiftwidth=2
EOF
    
    log_success "Vim configurado para desenvolvimento"
    echo ""
}

# =============================================================================
# FUNÇÃO PRINCIPAL DO MÓDULO
# =============================================================================

apply_development_config() {
    log_header "🛠️ APLICANDO CONFIGURAÇÕES DE DESENVOLVIMENTO"
    
    echo ""
    echo -e "${BLUE}Configurações a aplicar:${NC}"
    bullet_list \
        "inotify watches aumentado (crítico para IDEs)" \
        "Limites de file descriptors otimizados" \
        "Git configuração básica" \
        "Aliases práticos para desenvolvimento" \
        "History bash/zsh melhorado" \
        "Vim configuração básica"
    
    echo ""
    
    if ! confirm "Aplicar todas as configurações?" "y"; then
        log_info "Configurações de desenvolvimento canceladas"
        return 0
    fi
    
    # Aplicar configurações
    configure_inotify_watches
    configure_file_limits
    configure_git_basics
    configure_dev_aliases
    configure_enhanced_history
    configure_vim_basics
    
    log_success "🎉 Configurações de desenvolvimento aplicadas!"
    echo ""
    echo -e "${YELLOW}💡 PRÓXIMOS PASSOS:${NC}"
    bullet_list \
        "Fazer logout/login para aplicar limites" \
        "Reiniciar IDEs para detetar novos watches" \
        "Usar 'source ~/.dev_aliases' para carregar aliases" \
        "Testar: 'mkproject teste-projeto'"
    
    echo ""
}