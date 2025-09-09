#!/usr/bin/env python3
"""
Diagnóstico completo do Dashboard - Executar no Raspberry Pi
"""

import sqlite3
import json
import os
import sys

def test_database():
    """Testar conexão e views do banco"""
    print("1️⃣ Testando banco de dados...")
    
    # Encontrar banco
    possible_paths = [
        "./db/homeguard.db",
        "../db/homeguard.db", 
        "/home/homeguard/HomeGuard/db/homeguard.db"
    ]
    
    db_path = None
    for path in possible_paths:
        if os.path.exists(path):
            db_path = path
            break
    
    if not db_path:
        print("   ❌ Banco não encontrado!")
        return False
    
    print(f"   📁 Banco: {db_path}")
    
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        # Testar views
        views = ['vw_temperature_activity', 'vw_humidity_activity', 'vw_motion_activity', 'vw_relay_activity']
        
        for view in views:
            cursor.execute(f"SELECT COUNT(*) as count FROM {view}")
            count = cursor.fetchone()['count']
            print(f"   📊 {view}: {count} registros")
        
        conn.close()
        print("   ✅ Banco OK")
        return True
        
    except Exception as e:
        print(f"   ❌ Erro no banco: {e}")
        return False

def test_flask_imports():
    """Testar se Flask está disponível"""
    print("\n2️⃣ Testando importações Python...")
    
    try:
        import flask
        print(f"   ✅ Flask {flask.__version__} OK")
        return True
    except ImportError as e:
        print(f"   ❌ Flask não encontrado: {e}")
        print("   💡 Instale com: pip3 install flask")
        return False

def test_dashboard_file():
    """Testar se dashboard.py existe e está correto"""
    print("\n3️⃣ Testando arquivo dashboard.py...")
    
    dashboard_paths = [
        "./dashboard.py",
        "./web/dashboard.py",
        "/home/homeguard/HomeGuard/web/dashboard.py"
    ]
    
    dashboard_path = None
    for path in dashboard_paths:
        if os.path.exists(path):
            dashboard_path = path
            break
    
    if not dashboard_path:
        print("   ❌ dashboard.py não encontrado!")
        return False
    
    print(f"   📁 Dashboard: {dashboard_path}")
    
    # Verificar conteúdo
    try:
        with open(dashboard_path, 'r') as f:
            content = f.read()
            
        if 'api_temperature_data' in content:
            print("   ✅ API temperature OK")
        else:
            print("   ❌ API temperature não encontrada")
            
        if 'api_humidity_data' in content:
            print("   ✅ API humidity OK")
        else:
            print("   ❌ API humidity não encontrada")
            
        if 'humidity\': row[\'humidity\']' in content:
            print("   ✅ Campo humidity correto")
        else:
            print("   ⚠️ Campo humidity pode estar incorreto")
            
        return True
        
    except Exception as e:
        print(f"   ❌ Erro ao ler dashboard: {e}")
        return False

def test_templates():
    """Testar templates HTML"""
    print("\n4️⃣ Testando templates...")
    
    template_paths = [
        "./templates",
        "./web/templates",
        "/home/homeguard/HomeGuard/web/templates"
    ]
    
    templates_dir = None
    for path in template_paths:
        if os.path.exists(path):
            templates_dir = path
            break
    
    if not templates_dir:
        print("   ❌ Pasta templates não encontrada!")
        return False
    
    print(f"   📁 Templates: {templates_dir}")
    
    required_templates = [
        'base.html',
        'dashboard.html', 
        'temperature_panel.html',
        'humidity_panel.html'
    ]
    
    for template in required_templates:
        template_path = os.path.join(templates_dir, template)
        if os.path.exists(template_path):
            print(f"   ✅ {template} OK")
        else:
            print(f"   ❌ {template} não encontrado")
    
    return True

def main():
    print("🔍 Diagnóstico HomeGuard Dashboard")
    print("=" * 50)
    
    # Executar testes
    tests = [
        test_database,
        test_flask_imports, 
        test_dashboard_file,
        test_templates
    ]
    
    results = []
    for test in tests:
        results.append(test())
    
    print("\n" + "=" * 50)
    print("📊 Resumo:")
    
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print("✅ Todos os testes passaram!")
        print("\n🚀 Para executar o dashboard:")
        print("   cd /home/homeguard/HomeGuard/web")
        print("   python3 dashboard.py")
        print("   Acesse: http://IP_DO_PI:5000")
    else:
        print(f"❌ {total - passed} teste(s) falharam")
        print("\n🔧 Próximos passos:")
        print("   1. Corrigir os problemas indicados")
        print("   2. Executar novamente este diagnóstico")
        
    print(f"\n📈 Score: {passed}/{total}")

if __name__ == '__main__':
    main()
