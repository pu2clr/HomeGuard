"""
CONFIGURAÇÃO AVANÇADA PARA SENSOR ZMPT101B - ESP32-C3
====================================================

Este arquivo contém configurações avançadas para calibração
e ajuste fino do sensor ZMPT101B no Grid Monitor.

MELHORIAS IMPLEMENTADAS:
1. Filtro de média com exclusão de outliers
2. Hysteresis para evitar oscilação
3. Validação de estado estável
4. Logs detalhados para calibração
5. Configurações flexíveis de threshold
"""

# =============================================================================
# CONFIGURAÇÕES DE CALIBRAÇÃO DO SENSOR ZMPT101B
# =============================================================================

SENSOR_CONFIG = {
    # Configurações de amostragem
    'ADC_SAMPLES': 20,              # Número de amostras por leitura
    'SAMPLE_DELAY_MS': 20,          # Delay entre amostras (ms)
    'OUTLIERS_TO_REMOVE': 4,        # Remove 2 maiores + 2 menores
    
    # Thresholds com hysteresis (ajustar conforme calibração)
    'GRID_THRESHOLD_HIGH': 2750,    # Rede OFF→ON (threshold alto)
    'GRID_THRESHOLD_LOW': 2650,     # Rede ON→OFF (threshold baixo)
    'GRID_THRESHOLD_DEFAULT': 2700, # Threshold padrão
    
    # Estabilidade
    'MIN_STABLE_READINGS': 3,       # Leituras consecutivas para mudança
    'VOLTAGE_HISTORY_SIZE': 10,     # Tamanho do histórico
    
    # Configurações de debug
    'ENABLE_DETAILED_LOGS': True,   # Logs detalhados do sensor
    'ENABLE_VOLTAGE_STATS': True,   # Estatísticas de tensão
    'LOG_EVERY_N_READINGS': 1,      # Log a cada N leituras (1=sempre)
}

# =============================================================================
# VALORES DE CALIBRAÇÃO POR AMBIENTE
# =============================================================================

# Configurações pré-definidas para diferentes ambientes
CALIBRATION_PRESETS = {
    'RESIDENCIAL_220V': {
        'GRID_THRESHOLD_HIGH': 2800,
        'GRID_THRESHOLD_LOW': 2600,
        'MIN_STABLE_READINGS': 3,
        'DESCRIPTION': 'Rede residencial 220V estável'
    },
    
    'INDUSTRIAL_220V': {
        'GRID_THRESHOLD_HIGH': 2900,
        'GRID_THRESHOLD_LOW': 2500,
        'MIN_STABLE_READINGS': 5,
        'DESCRIPTION': 'Rede industrial com variações'
    },
    
    'RURAL_INSTAVEL': {
        'GRID_THRESHOLD_HIGH': 2700,
        'GRID_THRESHOLD_LOW': 2300,
        'MIN_STABLE_READINGS': 7,
        'DESCRIPTION': 'Rede rural com instabilidade'
    },
    
    'ALTA_SENSIBILIDADE': {
        'GRID_THRESHOLD_HIGH': 2600,
        'GRID_THRESHOLD_LOW': 2400,
        'MIN_STABLE_READINGS': 2,
        'DESCRIPTION': 'Detecção rápida, mais sensível'
    },
    
    'BAIXA_SENSIBILIDADE': {
        'GRID_THRESHOLD_HIGH': 3000,
        'GRID_THRESHOLD_LOW': 2000,
        'MIN_STABLE_READINGS': 10,
        'DESCRIPTION': 'Detecção lenta, menos sensível'
    }
}

# =============================================================================
# FUNÇÕES DE CALIBRAÇÃO
# =============================================================================

def apply_calibration_preset(preset_name):
    """
    Aplica um preset de calibração pré-definido
    """
    if preset_name in CALIBRATION_PRESETS:
        preset = CALIBRATION_PRESETS[preset_name]
        SENSOR_CONFIG.update(preset)
        print(f"Calibração aplicada: {preset_name}")
        print(f"Descrição: {preset.get('DESCRIPTION', 'N/A')}")
        print(f"Threshold Alto: {preset['GRID_THRESHOLD_HIGH']}")
        print(f"Threshold Baixo: {preset['GRID_THRESHOLD_LOW']}")
        return True
    else:
        print(f"Preset '{preset_name}' não encontrado!")
        print("Presets disponíveis:", list(CALIBRATION_PRESETS.keys()))
        return False

def calculate_optimal_thresholds(readings_with_grid_on, readings_with_grid_off):
    """
    Calcula thresholds ótimos baseado em leituras de calibração
    
    Args:
        readings_with_grid_on: Lista de leituras com rede ligada
        readings_with_grid_off: Lista de leituras com rede desligada
    
    Returns:
        dict com thresholds recomendados
    """
    if not readings_with_grid_on or not readings_with_grid_off:
        return None
    
    # Estatísticas básicas
    max_off = max(readings_with_grid_off)
    min_on = min(readings_with_grid_on)
    avg_on = sum(readings_with_grid_on) // len(readings_with_grid_on)
    avg_off = sum(readings_with_grid_off) // len(readings_with_grid_off)
    
    # Calcular thresholds com margem de segurança
    safety_margin = (avg_on - avg_off) * 0.1  # 10% de margem
    
    optimal_thresholds = {
        'GRID_THRESHOLD_HIGH': int(max_off + safety_margin),
        'GRID_THRESHOLD_LOW': int(min_on - safety_margin),
        'RECOMMENDED_DEFAULT': int((avg_on + avg_off) // 2),
        'STATISTICS': {
            'avg_on': avg_on,
            'avg_off': avg_off,
            'min_on': min_on,
            'max_off': max_off,
            'separation': min_on - max_off,
            'safety_margin': int(safety_margin)
        }
    }
    
    return optimal_thresholds

def generate_calibration_report(voltage_history):
    """
    Gera relatório de calibração baseado no histórico de tensões
    """
    if len(voltage_history) < 10:
        return "Histórico insuficiente para relatório"
    
    # Estatísticas básicas
    min_val = min(voltage_history)
    max_val = max(voltage_history)
    avg_val = sum(voltage_history) // len(voltage_history)
    
    # Variação
    variations = [abs(voltage_history[i] - voltage_history[i-1]) 
                 for i in range(1, len(voltage_history))]
    avg_variation = sum(variations) // len(variations) if variations else 0
    max_variation = max(variations) if variations else 0
    
    # Análise de estabilidade
    stable_readings = sum(1 for v in variations if v < 50)  # Variação < 50
    stability_percent = (stable_readings * 100) // len(variations) if variations else 100
    
    report = f"""
=== RELATÓRIO DE CALIBRAÇÃO ZMPT101B ===
Período analisado: {len(voltage_history)} leituras

ESTATÍSTICAS:
- Tensão mínima: {min_val}
- Tensão máxima: {max_val}
- Tensão média: {avg_val}
- Faixa de variação: {max_val - min_val}

VARIABILIDADE:
- Variação média: {avg_variation}
- Variação máxima: {max_variation}
- Estabilidade: {stability_percent}%

RECOMENDAÇÕES:
"""
    
    # Recomendações baseadas na análise
    if stability_percent > 80:
        report += "- Sensor estável, thresholds atuais provavelmente adequados\n"
    elif stability_percent > 60:
        report += "- Sensor moderadamente estável, considerar aumentar MIN_STABLE_READINGS\n"
    else:
        report += "- Sensor instável, recomendado usar preset RURAL_INSTAVEL\n"
    
    if max_variation > 200:
        report += "- Alta variação detectada, aumentar hysteresis\n"
    
    if (max_val - min_val) < 500:
        report += "- Baixa faixa de variação, verificar conexões do sensor\n"
    
    report += f"\nTHRESHOLDS SUGERIDOS:\n"
    report += f"- GRID_THRESHOLD_HIGH: {avg_val + (max_val - avg_val) // 2}\n"
    report += f"- GRID_THRESHOLD_LOW: {avg_val - (avg_val - min_val) // 2}\n"
    
    return report

# =============================================================================
# EXEMPLO DE USO NO MAIN.PY
# =============================================================================

"""
# No início do main.py, adicionar:

from sensor_calibration import SENSOR_CONFIG, apply_calibration_preset

# Aplicar preset de calibração
apply_calibration_preset('RESIDENCIAL_220V')  # ou outro preset

# Usar as configurações
ADC_SAMPLES = SENSOR_CONFIG['ADC_SAMPLES']
SAMPLE_DELAY = SENSOR_CONFIG['SAMPLE_DELAY_MS']
GRID_THRESHOLD_HIGH = SENSOR_CONFIG['GRID_THRESHOLD_HIGH']
GRID_THRESHOLD_LOW = SENSOR_CONFIG['GRID_THRESHOLD_LOW']
MIN_STABLE_READINGS = SENSOR_CONFIG['MIN_STABLE_READINGS']
OUTLIERS_TO_REMOVE = SENSOR_CONFIG['OUTLIERS_TO_REMOVE']

# No loop principal, adicionar coleta de dados para calibração:
voltage_history_for_calibration = []

# Dentro do loop:
voltage_history_for_calibration.append(voltage_reading)
if len(voltage_history_for_calibration) > 100:  # Manter últimas 100 leituras
    voltage_history_for_calibration.pop(0)

# A cada 100 leituras, gerar relatório:
if count % 100 == 0:
    report = generate_calibration_report(voltage_history_for_calibration)
    print(report)
"""

# =============================================================================
# COMANDOS MQTT PARA CALIBRAÇÃO REMOTA
# =============================================================================

MQTT_CALIBRATION_COMMANDS = {
    'PRESET_RESIDENTIAL': 'Aplicar preset residencial',
    'PRESET_INDUSTRIAL': 'Aplicar preset industrial', 
    'PRESET_RURAL': 'Aplicar preset rural',
    'PRESET_HIGH_SENS': 'Aplicar alta sensibilidade',
    'PRESET_LOW_SENS': 'Aplicar baixa sensibilidade',
    'CALIBRATION_REPORT': 'Gerar relatório de calibração',
    'VOLTAGE_STATS': 'Mostrar estatísticas de tensão',
    'RESET_CALIBRATION': 'Resetar para configuração padrão'
}

# Exemplo de implementação no mqtt_callback:
"""
def mqtt_callback(topic, msg):
    global relay_manual_override, relay_manual_state, client
    try:
        cmd = msg.decode().strip().upper()
        
        # Comandos existentes...
        
        # Novos comandos de calibração
        if cmd == 'PRESET_RESIDENTIAL':
            apply_calibration_preset('RESIDENCIAL_220V')
        elif cmd == 'PRESET_INDUSTRIAL':
            apply_calibration_preset('INDUSTRIAL_220V')
        elif cmd == 'PRESET_RURAL':
            apply_calibration_preset('RURAL_INSTAVEL')
        elif cmd == 'CALIBRATION_REPORT':
            report = generate_calibration_report(voltage_history_for_calibration)
            print(report)
        # ... outros comandos
        
    except Exception as e:
        print('Erro no callback MQTT:', e)
"""

print("Configuração de calibração ZMPT101B carregada!")
print("Presets disponíveis:", list(CALIBRATION_PRESETS.keys()))