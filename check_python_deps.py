#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
HomeGuard - Verificação Rápida de Dependências
Testa se todas as dependências Python estão instaladas
"""

import sys
import subprocess

def test_import(module_name, install_cmd=None):
    """Testa importação de um módulo"""
    try:
        __import__(module_name)
        print(f"✅ {module_name} - OK")
        return True
    except ImportError:
        print(f"❌ {module_name} - NÃO ENCONTRADO")
        if install_cmd:
            print(f"   💡 Instale: {install_cmd}")
        return False

def main():
    print("🧪 HomeGuard - Verificação de Dependências Python")
    print("=" * 50)
    
    # Testar dependências essenciais
    deps = [
        ("mysql.connector", "pip3 install mysql-connector-python"),
        ("pymysql", "pip3 install PyMySQL"),
        ("flask", "pip3 install flask"),
        ("json", None),  # Built-in
        ("datetime", None),  # Built-in
        ("threading", None),  # Built-in
    ]
    
    failed = []
    
    for module, install_cmd in deps:
        if not test_import(module, install_cmd):
            failed.append((module, install_cmd))
    
    print("\n" + "=" * 50)
    
    if not failed:
        print("🎉 TODAS AS DEPENDÊNCIAS ESTÃO INSTALADAS!")
        print("✅ Você pode executar o HomeGuard MySQL")
        print("\n🚀 Próximo passo:")
        print("   ./test_mysql_connection.py")
        print("   cd web/ && python3 homeguard_flask_mysql.py")
        
    else:
        print(f"❌ {len(failed)} DEPENDÊNCIAS FALTANDO:")
        print("\n🔧 COMANDOS PARA INSTALAR:")
        
        for module, install_cmd in failed:
            if install_cmd:
                print(f"   {install_cmd}")
        
        print("\n💡 OU USE O SCRIPT AUTOMATIZADO:")
        print("   ./install_python_mysql_deps.sh")
        
        # Tentar instalação automática
        print("\n🤖 Tentar instalação automática? (s/n): ", end="")
        try:
            choice = input().lower().strip()
            if choice in ['s', 'sim', 'y', 'yes']:
                print("\n🔧 Instalando dependências...")
                
                for module, install_cmd in failed:
                    if install_cmd and "pip3 install" in install_cmd:
                        cmd = install_cmd.split()
                        try:
                            subprocess.run(cmd, check=True)
                            print(f"✅ {module} instalado")
                        except subprocess.CalledProcessError:
                            print(f"❌ Falha ao instalar {module}")
                        except FileNotFoundError:
                            print(f"❌ pip3 não encontrado")
                            break
                
                print("\n🧪 Testando novamente...")
                # Testar novamente
                for module, _ in failed:
                    test_import(module)
                    
        except (KeyboardInterrupt, EOFError):
            print("\n⏹️  Cancelado pelo usuário")
    
    # Informações adicionais
    print(f"\n📊 INFORMAÇÕES DO SISTEMA:")
    print(f"   Python: {sys.version.split()[0]}")
    print(f"   Plataforma: {sys.platform}")
    print(f"   Caminho: {sys.executable}")
    
    return len(failed) == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
