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
if "$COMPILER" --run exemplos/media.glu -o "$TMP_DIR/invalido" >/dev/null 2>&1; then
    echo "FALHA: --run com -o deveria falhar." >&2
    exit 1
fi
if "$COMPILER" --ast --tokens exemplos/media.glu >/dev/null 2>&1; then
    echo "FALHA: --ast combinado com --tokens deveria falhar." >&2
    exit 1
fi
pass_count=$((pass_count + 1))

run_valid_case() {
    file="$1"
    base="$(basename "$file" .glu)"
    tok_file="$TMP_DIR/${base}.tokens"
    ast_file="$TMP_DIR/${base}.ast"
    c_file="$TMP_DIR/${base}.c"
    strict_bin="$TMP_DIR/${base}_strict"
    direct_bin="$TMP_DIR/${base}_direct"
    out_file="$TMP_DIR/${base}.out"

    # 1. Fase lexica (--tokens) e AST (--ast) salvando via -o
    "$COMPILER" --tokens "$file" -o "$tok_file"
    "$COMPILER" --ast "$file" -o "$ast_file"

    # 2. Emissao de C via --emit-c -o + compilacao estrita com -Werror
    "$COMPILER" --emit-c "$file" -o "$c_file"
    gcc -std=c99 -Wall -Wextra -Werror "$c_file" -o "$strict_bin"

    # 3. Compilacao direta para executavel (-o)
    "$COMPILER" "$file" -o "$direct_bin"

    # 4. Execucao direta (--run) e validacao de saidas
    case "$base" in
        idade)
            printf "20\n" | "$COMPILER" --run "$file" > "$out_file"
            grep -q "Acesso Liberado!" "$out_file"
            if printf "   \n" | "$direct_bin" >/dev/null 2>&1; then
                echo "FALHA: CISCA(inteiro) deveria rejeitar entrada contendo apenas espacos." >&2
                exit 1
            fi
            ;;
        entrada_texto)
            printf "42\n3.5\ntrue\nEsta linha de entrada tem espacos e mais de sessenta e quatro caracteres para validar o crescimento dinamico do buffer com seguranca.\n" | "$COMPILER" --run "$file" > "$out_file"
            grep -q "Conteudo igual." "$out_file"
            if printf "42\n   \ntrue\ntexto\n" | "$direct_bin" >/dev/null 2>&1; then
                echo "FALHA: CISCA(real) deveria rejeitar entrada contendo apenas espacos." >&2
                exit 1
            fi
            ;;
        operadores_relacionais)
            "$COMPILER" --run "$file" > "$out_file"
            grep -q "^-seta$" "$out_file"
            grep -q "^=menor$" "$out_file"
            grep -q "^11$" "$out_file"
            grep -q "^10$" "$out_file"
            ;;
        escopo_global_e_recursao)
            "$COMPILER" --run "$file" > "$out_file"
            grep -q "^15$" "$out_file"
            grep -q "^fim$" "$out_file"
            grep -q "^2.500000$" "$out_file"
            grep -q "^120$" "$out_file"
            ;;
        media)
            "$COMPILER" --run "$file" > "$out_file"
            grep -q "7.600000" "$out_file"
            grep -q "DOIS_PONTOS" "$tok_file"
            ;;
        alimentacao)
            "$COMPILER" --run "$file" > "$out_file"
            printf 'Alimentando \nPavoa\n com \n3\n kg de milho.\nAlimentando \nGalo\n com \n2\n kg de milho.\n' > "$TMP_DIR/alimentacao.expected"
            diff -u "$TMP_DIR/alimentacao.expected" "$out_file"
            ;;
        contador)
            "$COMPILER" --run "$file" > "$out_file"
            printf '5\n4\n3\n2\nInterrompendo antecipadamente...\nFim do laco!\n' > "$TMP_DIR/contador.expected"
            diff -u "$TMP_DIR/contador.expected" "$out_file"
            ;;
        controle_funcao)
            "$COMPILER" --run "$file" > "$out_file"
            printf '0\n2\n6\n8\n10\n' > "$TMP_DIR/controle_funcao.expected"
            diff -u "$TMP_DIR/controle_funcao.expected" "$out_file"
            ;;
        operadores_logicos)
            "$COMPILER" --run "$file" > "$out_file"
            printf 'true\ntrue\n' > "$TMP_DIR/operadores_logicos.expected"
            diff -u "$TMP_DIR/operadores_logicos.expected" "$out_file"
            ;;
        *)
            "$COMPILER" --run "$file" > "$out_file"
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
    if "$COMPILER" --emit-c "$file" -o "$TMP_DIR/nao_gerado.c" 2> "$err_file"; then
        echo "FALHA: '$file' deveria ser rejeitado pelo compilador." >&2
        exit 1
    fi
    if [ ! -s "$err_file" ]; then
        echo "FALHA: '$file' falhou sem emitir mensagem de erro." >&2
        exit 1
    fi
    base="$(basename "$file" .glu)"
    case "$base" in
        erro_comentario_nao_fechado|erro_inteiro_overflow|erro_lexico|erro_texto_nao_fechado)
            expected_category="Erro lexico"
            ;;
        erro_sintatico|erro_and_maiuscula|erro_not_maiuscula|erro_or_maiuscula)
            expected_category="Erro sintatico"
            ;;
        *)
            expected_category="Erro semantico"
            ;;
    esac
    if ! grep -q "$expected_category" "$err_file"; then
        echo "FALHA: '$file' deveria emitir '$expected_category', mas o stderr foi:" >&2
        cat "$err_file" >&2
        exit 1
    fi
    if [ "$base" = "erro_condicao_nao_booleana" ] && ! grep -q "linha 1:" "$err_file"; then
        echo "FALHA: '$file' deveria reportar erro na linha 1, mas o stderr foi:" >&2
        cat "$err_file" >&2
        exit 1
    fi
    echo "  [OK] $file (rejeitado com $expected_category)"
    pass_count=$((pass_count + 1))
done

echo "==> Todos os $pass_count testes passaram!"
