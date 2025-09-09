# HomeGuard - Controle de Versão e Build Management

## 🎯 **Arquivos Excluídos do Git (.gitignore)**

O projeto está configurado para **não sincronizar** arquivos temporários e de build com o GitHub.

### 📁 **Diretórios Excluídos:**

#### **Build e Compilação**
```
build/                     # ❌ Arquivos temporários do arduino-cli
firmware/*.bin             # ❌ Binários compilados  
firmware/*.hex             # ❌ Arquivos hex
firmware/*.elf             # ❌ Arquivos executáveis
temp/, tmp/, .build/       # ❌ Diretórios temporários
```

#### **Ambiente Python**
```
homeguard-env/             # ❌ Ambiente virtual Python
venv/, env/, .venv/        # ❌ Outros ambientes virtuais
__pycache__/               # ❌ Cache Python
*.pyc, *.pyo, *.pyd        # ❌ Arquivos compilados Python
```

#### **Sistema e IDEs**
```
.DS_Store                  # ❌ Arquivos do macOS
.vscode/                   # ❌ Configurações VS Code
.idea/                     # ❌ Configurações IDEs
*.log                      # ❌ Arquivos de log
```

#### **Segurança**
```
.env                       # ❌ Variáveis de ambiente
config.json                # ❌ Configurações sensíveis
*.pem, *.key, *.crt        # ❌ Chaves privadas
```

## 🧹 **Limpeza de Arquivos**

### **Script de Limpeza Automática:**
```bash
# Limpar todos os arquivos de build
./scripts/clean-build.sh
```

### **O que é removido:**
- ✅ Pasta `build/` completa (sketches compilados)
- ✅ Arquivos `*.bin`, `*.hex`, `*.elf` 
- ✅ Cache Python (`__pycache__/`)
- ✅ Diretórios temporários
- ✅ Arquivos de log

### **Tamanho liberado:**
- Típico: **20-50MB** por limpeza
- Build completo: até **100MB+**

## 📦 **Estrutura de Build**

### **Durante a Compilação:**
```
build/
├── Garagem_motion_sensor/
│   ├── Garagem_motion_sensor.ino
│   └── build/
│       ├── Garagem_motion_sensor.ino.bin    # 293KB
│       ├── Garagem_motion_sensor.ino.elf    # 500KB+
│       └── outros arquivos...
├── Area_Servico_motion_sensor/
├── Varanda_motion_sensor/
├── Mezanino_motion_sensor/
└── Ad_Hoc_motion_sensor/
```

### **Firmware Gerado:**
```
firmware/
├── Garagem_motion_sensor.bin      # ❌ Não versionado
├── Area_Servico_motion_sensor.bin # ❌ Não versionado  
├── Varanda_motion_sensor.bin      # ❌ Não versionado
├── Mezanino_motion_sensor.bin     # ❌ Não versionado
└── Ad_Hoc_motion_sensor.bin       # ❌ Não versionado
```

## ✅ **Arquivos Versionados**

### **Código Fonte:**
- ✅ `source/` - Código Arduino e Python
- ✅ `scripts/` - Scripts de automação
- ✅ `docs/` - Documentação

### **Configuração:**
- ✅ `.gitignore` - Regras de exclusão
- ✅ `README.md` - Documentação principal
- ✅ Arquivos de configuração de exemplo

### **Templates:**
- ✅ `motion_detector_template.ino` - Template configurável
- ✅ Scripts de compilação
- ✅ Scripts de setup

## 🔄 **Workflow de Desenvolvimento**

### **1. Desenvolvimento Local:**
```bash
# Fazer alterações no código
vim source/esp01/mqtt/motion_detector/motion_detector_template.ino

# Testar compilação
./scripts/test-compilation.sh

# Compilar todos os sensores
./scripts/batch-compile-sensors.sh
```

### **2. Limpeza Antes do Commit:**
```bash
# Limpar arquivos temporários
./scripts/clean-build.sh

# Verificar status
git status
```

### **3. Commit e Push:**
```bash
# Adicionar apenas arquivos necessários
git add source/ scripts/ docs/ *.md .gitignore

# Commit
git commit -m "Update motion sensor system"

# Push
git push origin main
```

### **4. Deploy em Outro Local:**
```bash
# Clone do repositório
git clone https://github.com/pu2clr/HomeGuard.git
cd HomeGuard

# Setup do ambiente
./scripts/setup-dev-environment.sh

# Compilar firmware
./scripts/batch-compile-sensors.sh

# Upload para dispositivos
./scripts/compile-motion-sensors-auto.sh
```

## 🚨 **Importância do .gitignore**

### **Benefícios:**
1. **Repositório Limpo**: Apenas código fonte essencial
2. **Velocidade**: Clones e pulls mais rápidos
3. **Segurança**: Evita vazamento de arquivos sensíveis
4. **Colaboração**: Evita conflitos desnecessários
5. **Espaço**: Economiza espaço no GitHub

### **Problemas Evitados:**
- ❌ Arquivos binários grandes no repositório
- ❌ Conflitos em arquivos de build
- ❌ Vazamento de credenciais
- ❌ Poluição do histórico do Git
- ❌ Limitações de tamanho do GitHub

## 📊 **Comandos Úteis**

### **Verificar Status:**
```bash
# Ver arquivos não rastreados
git status

# Ver tamanho do diretório build
du -sh build/

# Listar arquivos ignorados
git ls-files --others --ignored --exclude-standard
```

### **Limpeza:**
```bash
# Limpeza automática
./scripts/clean-build.sh

# Limpeza manual
rm -rf build/ firmware/*.bin

# Limpeza cache Python
find . -name "__pycache__" -exec rm -rf {} +
```

### **Verificação:**
```bash
# Verificar se .gitignore está funcionando
git check-ignore build/
git check-ignore homeguard-env/

# Ver arquivos grandes
find . -size +1M -type f | grep -v ".git"
```

## 🎯 **Resumo**

- ✅ **Build files**: Automaticamente excluídos
- ✅ **Environment**: Ambiente Python ignorado
- ✅ **Cleanup**: Script automático disponível
- ✅ **Security**: Arquivos sensíveis protegidos
- ✅ **Performance**: Repositório otimizado

**O sistema está configurado corretamente para desenvolvimento colaborativo!** 🚀
