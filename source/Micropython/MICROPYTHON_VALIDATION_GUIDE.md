"""
GUIA COMPLETO: VALIDAÇÃO DE CÓDIGO MICROPYTHON
==============================================

Este guia apresenta as melhores ferramentas e práticas para validar
código MicroPython antes do upload para microcontroladores.

"""

# =============================================================================
# 1. FERRAMENTAS RECOMENDADAS
# =============================================================================

VALIDATION_TOOLS = {
    'THONNY_IDE': {
        'description': 'IDE específico para MicroPython',
        'installation': 'pip install thonny',
        'features': [
            'Syntax highlighting MicroPython',
            'Validação em tempo real',
            'Debug integrado',
            'Upload direto para ESP32',
            'REPL integrado'
        ],
        'rating': '⭐⭐⭐⭐⭐ (Altamente Recomendado)'
    },
    
    'MPY_CROSS': {
        'description': 'Cross-compiler oficial MicroPython',
        'installation': 'pip install mpy-cross',
        'features': [
            'Validação de sintaxe 100% precisa',
            'Compilação para bytecode',
            'Detecção de erros específicos',
            'Usado pelo próprio MicroPython'
        ],
        'usage': 'mpy-cross arquivo.py',
        'rating': '⭐⭐⭐⭐⭐ (Essencial)'
    },
    
    'WOKWI_SIMULATOR': {
        'description': 'Simulador online ESP32/Arduino',
        'url': 'https://wokwi.com',
        'features': [
            'Simulação completa de hardware',
            'Teste de componentes (ADC, GPIO)',
            'Debug visual',
            'Sem necessidade de hardware'
        ],
        'rating': '⭐⭐⭐⭐ (Excelente para testes)'
    },
    
    'MICROPYTHON_STUBS': {
        'description': 'Type hints para IDEs',
        'installation': 'pip install micropython-stubs',
        'features': [
            'Autocomplete em IDEs',
            'Detecção de erros de tipo',
            'Documentação integrada'
        ],
        'rating': '⭐⭐⭐⭐ (Muito útil)'
    },
    
    'CUSTOM_VALIDATOR': {
        'description': 'Script personalizado HomeGuard',
        'file': 'validate_micropython.sh',
        'features': [
            'Validação específica ESP32-C3',
            'Verificação de pinos',
            'Análise de configuração MQTT',
            'Estimativa de memória',
            'Relatório completo'
        ],
        'usage': './validate_micropython.sh main.py',
        'rating': '⭐⭐⭐⭐⭐ (Customizado para projeto)'
    }
}

# =============================================================================
# 2. INSTALAÇÃO DAS FERRAMENTAS
# =============================================================================

INSTALLATION_COMMANDS = """
# Instalar todas as ferramentas de uma vez
pip install thonny mpy-cross pylint micropython-stubs black

# Verificar instalação
mpy-cross --version
pylint --version
thonny --version

# Para Ubuntu/Debian (dependências do sistema)
sudo apt-get install python3-pip python3-venv

# Para macOS (com Homebrew)
brew install python3
"""

# =============================================================================
# 3. WORKFLOW DE VALIDAÇÃO RECOMENDADO
# =============================================================================

VALIDATION_WORKFLOW = [
    {
        'step': 1,
        'title': 'Validação de Sintaxe Básica',
        'tool': 'Python built-in compiler',
        'command': 'python3 -m py_compile main.py',
        'description': 'Verifica sintaxe Python básica'
    },
    {
        'step': 2,
        'title': 'Validação MicroPython Específica',
        'tool': 'mpy-cross',
        'command': 'mpy-cross main.py',
        'description': 'Verifica compatibilidade com MicroPython'
    },
    {
        'step': 3,
        'title': 'Análise Estática',
        'tool': 'pylint',
        'command': 'pylint --rcfile=.pylintrc main.py',
        'description': 'Detecta problemas de código'
    },
    {
        'step': 4,
        'title': 'Validação Específica do Projeto',
        'tool': 'validate_micropython.sh',
        'command': './validate_micropython.sh main.py',
        'description': 'Validações específicas ESP32-C3 e HomeGuard'
    },
    {
        'step': 5,
        'title': 'Teste em Simulador (Opcional)',
        'tool': 'Wokwi',
        'command': 'https://wokwi.com',
        'description': 'Teste visual com hardware simulado'
    },
    {
        'step': 6,
        'title': 'Upload e Teste Real',
        'tool': 'mpremote ou test_wdt_fix.sh',
        'command': './test_wdt_fix.sh upload',
        'description': 'Upload para hardware real'
    }
]

# =============================================================================
# 4. CONFIGURAÇÃO DO AMBIENTE DE DESENVOLVIMENTO
# =============================================================================

IDE_CONFIGURATIONS = {
    'VS_CODE': {
        'extensions': [
            'ms-python.python',
            'ms-python.pylint',
            'ms-python.black-formatter'
        ],
        'settings_file': '.vscode/settings.json',
        'features': [
            'Syntax highlighting',
            'Error detection',
            'Code formatting',
            'Integrated terminal'
        ]
    },
    
    'THONNY': {
        'download': 'https://thonny.org',
        'configuration': [
            'Tools → Options → Interpreter',
            'Select MicroPython (ESP32)',
            'Configure port (USB/Serial)'
        ],
        'advantages': [
            'Designed for MicroPython',
            'Direct device connection',
            'Built-in file manager',
            'REPL integration'
        ]
    },
    
    'PYCHARM': {
        'edition': 'Community (Free) ou Professional',
        'plugins': [
            'MicroPython Support',
            'Serial Port Monitor'
        ],
        'configuration': [
            'Settings → Languages → MicroPython',
            'Device path configuration',
            'Upload settings'
        ]
    }
}

# =============================================================================
# 5. VALIDAÇÕES ESPECÍFICAS PARA ESP32-C3
# =============================================================================

ESP32C3_VALIDATIONS = {
    'GPIO_PINS': {
        'valid_range': 'GPIO 0-21',
        'reserved_pins': [11, 12, 13, 14, 15, 16, 17],  # SPI Flash
        'adc_pins': [0, 1, 2, 3, 4],  # ADC1_CH0 to ADC1_CH4
        'special_pins': {
            'GPIO0': 'ADC1_CH0, Boot mode selection',
            'GPIO9': 'Boot mode selection',
            'GPIO8': 'Often used for onboard LED',
            'GPIO18': 'USB D-',
            'GPIO19': 'USB D+'
        }
    },
    
    'MEMORY_LIMITS': {
        'ram_total': '400KB',
        'ram_available': '~320KB (after system)',
        'recommended_code_size': '<50KB',
        'max_code_size': '<100KB'
    },
    
    'POWER_CONSIDERATIONS': {
        'operating_voltage': '3.3V',
        'max_current_per_pin': '40mA',
        'total_current_limit': '1200mA'
    }
}

# =============================================================================
# 6. EXEMPLO DE USO PRÁTICO
# =============================================================================

PRACTICAL_EXAMPLE = """
# 1. Validar arquivo main.py
./validate_micropython.sh main.py

# 2. Se houver erros, corrigir e validar novamente
# Exemplo de erro comum:
# ❌ GPIO25 > 21 (máximo para ESP32-C3)
# ✅ Corrigir para GPIO5

# 3. Executar validação completa
./validate_micropython.sh

# 4. Se todos os testes passarem:
✅ CÓDIGO PRONTO PARA UPLOAD! 🚀

# 5. Upload para ESP32-C3
./test_wdt_fix.sh upload

# 6. Monitorar funcionamento
./test_wdt_fix.sh monitor
"""

# =============================================================================
# 7. ERROS COMUNS E SOLUÇÕES
# =============================================================================

COMMON_ERRORS = {
    'SYNTAX_ERROR': {
        'error': 'SyntaxError: invalid syntax',
        'cause': 'Erro de sintaxe Python',
        'solution': 'Verificar indentação, parênteses, aspas'
    },
    
    'IMPORT_ERROR': {
        'error': 'ImportError: no module named',
        'cause': 'Módulo não disponível no MicroPython',
        'solution': 'Usar apenas módulos MicroPython (machine, network, etc.)'
    },
    
    'MEMORY_ERROR': {
        'error': 'MemoryError',
        'cause': 'Código muito grande ou uso excessivo de RAM',
        'solution': 'Reduzir tamanho do código, usar garbage collection'
    },
    
    'WDT_TIMEOUT': {
        'error': 'Guru Meditation Error: WDT timeout',
        'cause': 'Loop sem machine.idle()',
        'solution': 'Adicionar machine.idle() em loops longos'
    },
    
    'GPIO_ERROR': {
        'error': 'ValueError: invalid pin',
        'cause': 'Pino inválido para ESP32-C3',
        'solution': 'Usar apenas GPIO 0-21, evitar pinos reservados'
    }
}

# =============================================================================
# 8. RECURSOS ADICIONAIS
# =============================================================================

ADDITIONAL_RESOURCES = {
    'DOCUMENTATION': [
        'https://docs.micropython.org',
        'https://randomnerdtutorials.com/esp32-esp8266-micropython',
        'https://github.com/micropython/micropython'
    ],
    
    'TOOLS': [
        'https://thonny.org - Thonny IDE',
        'https://wokwi.com - Online Simulator',
        'https://github.com/Josverl/micropython-stubs - Type stubs'
    ],
    
    'COMMUNITY': [
        'https://forum.micropython.org',
        'https://reddit.com/r/micropython',
        'https://discord.gg/micropython'
    ]
}

print("📚 Guia de Validação MicroPython carregado!")
print("🔧 Use validate_micropython.sh para validação automática")
print("💡 Configure seu IDE com as ferramentas recomendadas")