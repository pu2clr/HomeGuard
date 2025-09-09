# 🚨 CORREÇÃO URGENTE - VIEWS DO BANCO DE DADOS

## 🎯 PROBLEMA IDENTIFICADO

**ROOT CAUSE:** As views do banco de dados (`vw_temperature_activity`, `vw_humidity_activity`, etc.) estão retornando **0 registros**, mesmo com a API externa funcionando e dados existindo na tabela `activity`.

**EVIDÊNCIA:**
```bash
# API externa tem dados:
curl "http://100.87.71.125:5000/api/temperature/data" → 47 registros

# Dashboard ultra-básico:
APIs retornam 0 registros → VIEWS QUEBRADAS
```

## 🔧 SOLUÇÃO IMEDIATA

### NO RASPBERRY PI, execute:

```bash
# 1. Copiar o script de correção
cd /home/homeguard/HomeGuard
wget -O scripts/fix_database_views.sh "SEU_LINK_DO_SCRIPT"

# 2. Dar permissão
chmod +x scripts/fix_database_views.sh

# 3. EXECUTAR CORREÇÃO
./scripts/fix_database_views.sh
```

## 📋 O QUE O SCRIPT FAZ

1. **Verifica dados** na tabela `activity`
2. **Remove views antigas** (possivelmente quebradas)
3. **Recria views corretas** com sintaxe JSON adequada
4. **Testa as views** corrigidas
5. **Reinicia o dashboard**
6. **Testa as APIs** após correção

## 🎯 RESULTADO ESPERADO

Após executar o script:

```
✅ CORREÇÃO CONCLUÍDA!
=====================

📊 RESULTADOS:
   📦 Dados na tabela: Temp=100+, Umid=100+
   📋 Views corrigidas: Temp=50+, Umid=50+
   🌐 APIs funcionando: Temp=20+, Umid=20+

🧪 TESTE AGORA:
   Dashboard: http://100.87.71.125:5000/
   Ultra-básico: http://100.87.71.125:5000/ultra-basic
```

## 🚨 SE AINDA NÃO FUNCIONAR

1. **Verificar logs:**
   ```bash
   tail -f dashboard_views_fixed.log
   ```

2. **Testar manualmente:**
   ```bash
   sqlite3 /home/homeguard/HomeGuard/db/homeguard.db
   SELECT COUNT(*) FROM vw_temperature_activity;
   .quit
   ```

3. **Reportar resultado** do script completo

## 🎯 EXPECTATIVA

- **Ultra-básico DEVE mostrar dados** após correção
- **Dashboard principal** deve voltar a funcionar
- **Todos os painéis** (Temp, Umidade, Movimento, Relés) devem carregar

---

**EXECUTE O SCRIPT AGORA** e reporte o resultado! 🚀
