# 🚀 Laptop Optimizer v4.0 - Sistema Híbrido Modular

**Sistema modular e inteligente de otimização para laptops Ubuntu/Debian focado em desenvolvimento**

## 🚀 Início Rápido

### 1. **Verificação Rápida** (30 segundos)
```bash
./quick-check.sh
```

### 2. **Verificação Completa** (se necessário)
```bash
./check-dependencies.sh
```

### 3. **Executar Otimizador**
```bash
./optimize-laptop.sh
```

## 📋 Sistema de Dependências

### 🔍 **Scripts de Verificação**

| Script | Propósito | Tempo | Quando Usar |
|--------|-----------|-------|-------------|
| `quick-check.sh` | Verificação básica | 30s | Antes de cada execução |
| `check-dependencies.sh` | Verificação completa + instalação | 2-5min | Setup inicial ou problemas |

### ⚙️ **Dependências por Categoria**

**📦 Essenciais (obrigatórias):**
- `sudo` - Execução com privilégios
- `systemctl` - Gestão de serviços
- `bc` - Cálculos matemáticos
- `curl` - Downloads
- `git` - Controlo de versão
- `grep, awk, sed` - Processamento de texto

**🖥️ Sistema (críticas):**
- `free, df, nproc` - Informação do sistema
- `ps, top, lsof` - Monitorização
- `ip, ping, netstat` - Rede

**🛠️ Desenvolvimento (importantes):**
- `which, whereis, file` - Utilitários
- `tar, gzip, zip` - Compressão
- `chmod, chown, ln` - Gestão de ficheiros

**🎯 Opcionais (melhoram experiência):**
- `htop` - Monitor melhorado
- `tree` - Visualização de diretórios
- `vim/nano` - Editores
- `docker` - Containerização
- `python3, nodejs` - Ambientes de desenvolvimento

### 🔧 **Instalação Automática**

O `check-dependencies.sh` detecta automaticamente:
- **Sistema operacional** (Ubuntu, Debian, Fedora, macOS)
- **Gestor de pacotes** (apt, dnf, yum, brew)
- **Pacotes em falta** 
- **Comandos não funcionais**

E oferece **instalação interativa** com confirmação.

## 📊 Cenários de Uso

### 🏢 **Ambiente Empresarial**
```bash
./quick-check.sh           # Verificação básica
./optimize-laptop.sh       # Escolher opção 9 (Empresarial)
```
- ✅ Verificação automática de conflitos (VPN, DNS, SSH)
- ✅ Modo conservador com backup obrigatório
- ✅ Preserva configurações empresariais

### 💻 **Uso Pessoal**
```bash
./check-dependencies.sh    # Setup completo
./optimize-laptop.sh       # Escolher opção 8 (Completa)
```
- ✅ Otimizações completas
- ✅ Ferramentas da comunidade
- ✅ Docker cleanup inteligente

### 🔧 **Primeira Vez**
```bash
./check-dependencies.sh    # Instalar tudo necessário
./optimize-laptop.sh       # Escolher opção 1 (Ferramentas)
```
- ✅ TLP, auto-cpufreq, preload
- ✅ Configurações básicas
- ✅ Sistema de manutenção

## 🛠️ Comandos Disponíveis (após otimização)

### 📊 **Monitorização**
```bash
dev-status              # Dashboard do sistema
dev-health              # Health check completo
dev-tools               # Verificar ferramentas instaladas
dev-benchmark           # Teste de performance
```

### 🧹 **Manutenção**
```bash
dev-clean status        # Ver espaço e uso
dev-clean now           # Limpeza rápida
dev-clean deep          # Limpeza semanal
dev-clean nuclear       # Limpeza mensal
```

### 🐳 **Docker**
```bash
docker-clean status     # Ver uso Docker
docker-clean safe       # Limpeza conservadora
docker-clean normal     # Limpeza moderada
docker-clean deep       # Limpeza agressiva (preserva BDs)
```

### 🔄 **Backup & Restore**
```bash
dev-rollback            # Listar backups disponíveis
dev-rollback <backup>   # Reverter alterações
```

## 📁 Estrutura do Projeto

```
laptop-optimizer/
├── optimize-laptop.sh           # 🚀 Script principal
├── quick-check.sh               # 🔍 Verificação rápida
├── check-dependencies.sh        # 📦 Verificação completa + instalação
├── setup.sh                     # 📥 Instalação global
├── install-community-tools.sh   # 🌍 Ferramentas da comunidade
├── lib/                         # 📚 Bibliotecas
│   ├── colors.sh               # 🎨 Interface colorida
│   ├── common.sh               # 🔧 Funções comuns
│   ├── validation.sh           # ✅ Validações de sistema
│   └── backup.sh               # 💾 Sistema de backup
├── modules/                     # 🔧 Módulos funcionais
│   ├── enterprise-conflicts.sh # 🏢 Verificação empresarial
│   ├── essential-tweaks.sh     # ⚡ Otimizações essenciais
│   ├── development-config.sh   # 🛠️ Configurações dev
│   ├── smart-maintenance.sh    # 🧹 Manutenção inteligente
│   ├── utility-scripts.sh      # ⚡ Scripts utilitários
│   └── docker-cleanup.sh       # 🐳 Docker inteligente
├── config/                      # ⚙️ Configurações
│   ├── settings.conf           # 📋 Configurações principais
│   ├── enterprise.conf         # 🏢 Override empresarial
│   └── enterprise-advanced.conf # 🏢 Configurações avançadas
└── tests/                       # 🧪 Testes e benchmarks
    ├── benchmark.sh            # 📊 Benchmark completo
    └── validation_tests.sh     # ✅ Testes de validação
```

## ✨ Especialidades Únicas

### 🏢 **Detecção Empresarial Automática**
- Detecta VPN, DNS empresarial, Docker corporativo
- Adapta otimizações automaticamente
- Preserva configurações críticas da empresa

### 🐳 **Docker Cleanup Inteligente**
- **Preserva automaticamente** bases de dados
- Detecta containers PostgreSQL, MySQL, MongoDB, Redis
- 3 modos: conservador, moderado, agressivo
- **NUNCA remove dados importantes**

### 🧹 **Sistema de Manutenção Automática**
- Limpeza diária/semanal/mensal automática
- Monitorização de espaço com alertas
- Integração com Docker cleanup
- Logs estruturados e estatísticas

### ⚡ **Scripts Utilitários Práticos**
- `dev-status` - Dashboard completo
- `dev-health` - Health check
- `dev-clean` - Limpeza inteligente
- `dev-rollback` - Sistema de backup

## 🔒 Segurança e Backup

### 💾 **Sistema de Backup Automático**
- Backup **obrigatório** antes de qualquer alteração
- Inclui configurações sistema, serviços, cron jobs
- Script de rollback automático gerado
- Comando global `dev-rollback` disponível

### 🏢 **Modo Empresarial**
- Detecta e preserva configurações VPN
- Não altera DNS/rede se VPN ativo
- Mantém políticas SSH empresariais
- Backup mais conservador

## 🚦 Resolução de Problemas

### ❌ **"Comando não encontrado"**
```bash
./check-dependencies.sh    # Instala dependências em falta
```

### ❌ **"Permission denied"**
```bash
chmod +x *.sh              # Dar permissões de execução
```

### ❌ **"Sistema não está pronto"**
```bash
sudo apt update && sudo apt install bc curl git
./quick-check.sh           # Verificar novamente
```

### ❌ **Problemas após otimização**
```bash
dev-rollback               # Ver backups disponíveis
dev-rollback <backup-dir>  # Reverter alterações
```

## 📈 Benchmarks e Validação

### 📊 **Benchmark Completo**
```bash
./tests/benchmark.sh       # Teste de performance completo
```

### ✅ **Validação das Otimizações**
```bash
./tests/validation_tests.sh # Verificar se tudo foi aplicado
```

## 🎯 Instalação Global (Opcional)

Para instalar globalmente e ter comando `laptop-optimizer`:

```bash
sudo ./setup.sh
laptop-optimizer            # Executar de qualquer lugar
laptop-optimizer-uninstall  # Remover sistema
```

---

## 🆘 Suporte

### 📋 **Informação do Sistema**
```bash
./quick-check.sh           # Estado básico
dev-status                 # Dashboard completo (após otimização)
dev-health                 # Health check detalhado
```

### 🔍 **Logs e Debug**
- **Logs de execução**: `/tmp/laptop-optimizer.log`
- **Logs de manutenção**: `/var/log/dev-maintenance/`
- **Backups**: `~/.laptop-optimizer-backups/`

### 🏷️ **Versão e Ajuda**
```bash
./optimize-laptop.sh --version    # Ver versão
./optimize-laptop.sh --help       # Ajuda completa
./check-dependencies.sh --help    # Ajuda sobre dependências
```

---

**Objetivo**: Laptop de desenvolvimento otimizado, seguro e inteligente! 🎯

**Sistema testado em**: Ubuntu 20.04+, Debian 11+, com suporte experimental para Fedora e macOS.