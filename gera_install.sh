import sys

def main():
    if len(sys.argv) != 2:
        print("Uso: python3 script.py arquivo.txt")
        sys.exit(1)

    arquivo_entrada = sys.argv[1]
    arquivo_saida = "instala_pacotes.sh"

    try:
        with open(arquivo_entrada, 'r') as f_in, open(arquivo_saida, 'w') as f_out:
            for linha in f_in:
                pacote = linha.strip()
                if pacote:
                    f_out.write(f"brew install {pacote}\n")
        print(f"Arquivo '{arquivo_saida}' criado com sucesso!")
    except Exception as e:
        print("Erro:", e)

if __name__ == "__main__":
    main()
