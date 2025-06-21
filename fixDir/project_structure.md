# 📁 Estrutura do Laptop Optimizer

```
laptop-optimizer/
├── 📄 README.md                    # Documentação principal
├── 🚀 optimize-laptop.sh           # Script principal (menu)
├── 🌍 install-community-tools.sh   # Instalar ferramentas comunidade
├── ⚙️ config/
│   ├── settings.conf              # Configurações padrão
│   └── enterprise.conf            # Override empresarial
├── 📚 lib/
│   ├── common.sh                  # Funções comuns (log, ask_user)
│   ├── validation.sh              # Verificações sistema
│   ├── backup.sh                  # Sistema backup/rollback
│   └── colors.sh                  # Cores e formatação
├── 🔧 modules/
│   ├── enterprise-conflicts.sh    # 🏆 Verificações empresariais (ÚNICO)
│   ├── development-config.sh      # 🛠️ Configs desenvolvimento
│   ├── smart-maintenance.sh       # 🧹 Sistema manutenção (ÚNICO)
│   ├── utility-scripts.sh         # ⚡ Scripts práticos (ÚNICO)
│   ├── docker-cleanup.sh          # 🐳 Docker smart cleanup (ÚNICO)
│   └── essential-tweaks.sh        # 🔧 Otimizações comprovadas
├── 🛠️ tools/                       # Scripts finais instalados
│   ├── dev-status
│   ├── dev-clean  
│   ├── dev-health
│   ├── dev-tools
│   └── dev-benchmark
└── 📊 tests/
    ├── validate-optimizations.sh   # Testes dos módulos
    └── benchmark.sh               # Benchmarks performance
```

## 🎯 Filosofia dos Módulos

**🏆 MÓDULOS ÚNICOS (teu valor):**
- `enterprise-conflicts.sh` - Ninguém faz verificações VPN/Docker/SSH
- `smart-maintenance.sh` - Sistema manutenção inteligente  
- `utility-scripts.sh` - Scripts práticos dev-status, dev-clean
- `docker-cleanup.sh` - Cleanup que preserva DBs

**🌍 FERRAMENTAS COMUNIDADE:**
- `install-community-tools.sh` - TLP, auto-cpufreq, preload, earlyoom

**🔧 CONFIGURAÇÕES FOCADAS:**
- `development-config.sh` - Apenas configs que importam (inotify, limits)
- `essential-tweaks.sh` - Apenas otimizações comprovadas