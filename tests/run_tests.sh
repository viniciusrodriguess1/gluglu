#!/bin/sh
set -eu

COMPILER="./glugluc"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pass_count=0

if [ ! -x "$COMPILER" ]; then
    echo "Erro: compilador '$COMPILER' nao encontrado. Execute 'make' antes." >&2
    exit 1
fi

echo "==> Testando opcoes de linha de comando"
"$COMPILER" --help >/dev/null
if "$COMPILER" --opcao-invalida >/dev/null 2>&1; then
    echo "FALHA: --opcao-invalida deveria falhar." >&2
    exit 1
fi
pass_count=$((pass_count + 1))

run_valid_case() {
    file="$1"
    base="$(basename "$file" .glu)"
    c_file="$TMP_DIR/${base}.c"
    bin_file="$TMP_DIR/${base}"
    out_file="$TMP_DIR/${base}.out"

    "$COMPILER" --ast "$file" >/dev/null
    "$COMPILER" < "$file" > "$c_file"
    gcc -std=c99 -Wall -Wextra -Werror "$c_file" -o "$bin_file"

    case "$base" in
        idade)
            printf "20\n" | "$bin_file" > "$out_file"
            grep -q "Acesso Liberado!" "$out_file"
            ;;
        entrada_texto)
            printf "42\n3.5\ntrue\nEsta linha de entrada tem espacos e mais de sessenta e quatro caracteres para validar o crescimento dinamico do buffer com seguranca.\n" | "$bin_file" > "$out_file"
            grep -q "Conteudo igual." "$out_file"
            ;;
        operadores_relacionais)
            "$bin_file" > "$out_file"
            grep -q "^-seta$" "$out_file"
            grep -q "^=menor$" "$out_file"
            grep -q "^11$" "$out_file"
            grep -q "^10$" "$out_file"
            ;;
        escopo_global_e_recursao)
            "$bin_file" > "$out_file"
            grep -q "^15$" "$out_file"
            grep -q "^fim$" "$out_file"
            grep -q "^2.500000$" "$out_file"
            grep -q "^120$" "$out_file"
            ;;
        *)
            "$bin_file" > "$out_file"
            ;;
    esac

    echo "  [OK] $file"
    pass_count=$((pass_count + 1))
}

echo "==> Testando programas validos (exemplos/ e tests/valid/)"
for file in exemplos/*.glu tests/valid/*.glu; do
    run_valid_case "$file"
done

echo "==> Testando programas invalidos (tests/invalid/)"
for file in tests/invalid/*.glu; do
    err_file="$TMP_DIR/$(basename "$file" .glu).err"
    if "$COMPILER" < "$file" > /dev/null 2> "$err_file"; then
        echo "FALHA: '$file' deveria ser rejeitado pelo compilador." >&2
        exit 1
    fi
    if [ ! -s "$err_file" ]; then
        echo "FALHA: '$file' falhou sem emitir mensagem de erro." >&2
        exit 1
    fi
    echo "  [OK] $file (rejeitado conforme esperado)"
    pass_count=$((pass_count + 1))
done

echo "==> Todos os $pass_count testes passaram!"
