# Correção de Dados JSON Malformados - Sensores de Movimento

## 🔍 Problema Identificado
JSON malformado nos sensores de movimento:
```json
❌ ANTES: "location":"Espaço Maker""sensor_type":"REGULAR_IR_SENSOR"
✅ DEPOIS: "location":"Espaço Maker","sensor_type":"REGULAR_IR_SENSOR"
```

## 🛠️ Comandos SQL para Correção

### 1. Identificar registros problemáticos
```sql
-- Ver quantos registros têm JSON inválido nos sensores de movimento
SELECT 
    COUNT(*) as total_invalid,
    topic
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0
GROUP BY topic
ORDER BY total_invalid DESC;
```

### 2. Examinar mensagens malformadas
```sql
-- Ver exemplos de mensagens malformadas
SELECT 
    id,
    created_at,
    topic,
    message
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0
    AND message LIKE '%"location"%'
LIMIT 10;
```

### 3. Corrigir registros malformados - Método 1 (Específico)
```sql
-- Corrigir o padrão específico: "location":"value""sensor_type"
UPDATE activity 
SET message = REPLACE(message, '"location":"Espaço Maker""sensor_type"', '"location":"Espaço Maker","sensor_type"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0
    AND message LIKE '%"location":"Espaço Maker""sensor_type"%';

-- Verificar se há outros padrões similares
UPDATE activity 
SET message = REPLACE(message, '""sensor_type"', '","sensor_type"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0
    AND message LIKE '%""sensor_type"%';
```

### 4. Corrigir registros malformados - Método 2 (Genérico)
```sql
-- Corrigir padrão geral: dois quotes consecutivos entre campos JSON
UPDATE activity 
SET message = REPLACE(message, '""', '","')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0
    AND message LIKE '%""%';
```

### 5. Validar correções
```sql
-- Verificar se ainda há registros inválidos
SELECT 
    COUNT(*) as still_invalid
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;

-- Ver registros que foram corrigidos
SELECT 
    COUNT(*) as now_valid
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 1;
```

### 6. Testar extração de dados após correção
```sql
-- Testar se agora conseguimos extrair dados dos sensores de movimento
SELECT 
    created_at,
    json_extract(message, '$.device_id') as device_id,
    json_extract(message, '$.location') as location,
    json_extract(message, '$.sensor_type') as sensor_type,
    json_extract(message, '$.motion') as motion,
    json_extract(message, '$.ip') as ip
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 1
ORDER BY created_at DESC
LIMIT 10;
```

## 🔧 Script Completo de Correção

```sql
-- BACKUP: Criar tabela de backup antes da correção
CREATE TABLE activity_backup AS 
SELECT * FROM activity 
WHERE topic LIKE 'home/motion/%' 
    AND json_valid(message) = 0;

-- ETAPA 1: Corrigir padrão específico mais comum
UPDATE activity 
SET message = REPLACE(message, '""sensor_type"', '","sensor_type"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;

-- ETAPA 2: Corrigir outros padrões de quotes duplos
UPDATE activity 
SET message = REPLACE(message, '""name"', '","name"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;

UPDATE activity 
SET message = REPLACE(message, '""location"', '","location"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;

UPDATE activity 
SET message = REPLACE(message, '""ip"', '","ip"')
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;

-- ETAPA 3: Verificar resultado
SELECT 
    'ANTES' as status,
    COUNT(*) as count
FROM activity_backup
UNION ALL
SELECT 
    'DEPOIS_VALIDOS' as status,
    COUNT(*) as count
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 1
UNION ALL
SELECT 
    'AINDA_INVALIDOS' as status,
    COUNT(*) as count
FROM activity 
WHERE topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;
```

## 🧪 Comando de Teste Seguro

Antes de executar as correções, teste com um registro específico:

```sql
-- Testar correção em um registro específico (substitua o ID)
UPDATE activity 
SET message = REPLACE(message, '""sensor_type"', '","sensor_type"')
WHERE id = 12345  -- substitua pelo ID real
    AND topic LIKE 'home/motion/%'
    AND json_valid(message) = 0;

-- Verificar se o registro foi corrigido
SELECT 
    id,
    json_valid(message) as is_valid,
    message
FROM activity 
WHERE id = 12345;
```

## ⚠️ Importante

1. **SEMPRE faça backup** antes de executar UPDATEs em massa
2. **Teste com um registro** primeiro
3. **Verifique o resultado** com `json_valid(message)`
4. **Mantenha o backup** até confirmar que tudo está funcionando

## 🎯 Resultado Esperado

Após a correção, as consultas do arquivo SQL_JSON_QUERIES.md funcionarão perfeitamente com os dados dos sensores de movimento! ✅
