# GLUGLU — Compilador e Tradutor

Implementação do compilador/tradutor da linguagem **GLUGLU**, desenvolvido como projeto prático para a disciplina de **Compiladores**.

---

## 👥 Integrantes

* Pedro Vinícius Marques
* Rodrigo Dias da Paz Santos
* Vinícius Rodrigues Santana

---

## 📌 Sobre o Repositório e Modalidade Escolhida

Este projeto implementa um **compilador/transpilador completo** para a linguagem didática **GLUGLU**. O compilador processa o código-fonte `.glu` por meio das fases clássicas de compilação (análise léxica, análise sintática, análise semântica, construção da AST e geração de código), gera código equivalente em **C estruturado (C99/C11)** e aciona `gcc` automaticamente para produzir ou executar o binário nativo.

### Justificativa da Linguagem de Destino

O C foi escolhido por mapear diretamente os tipos estáticos e as estruturas imperativas da GLUGLU, produzir código nativo compilável com ferramentas amplamente disponíveis (`gcc` e `clang`) e permitir inspecionar o resultado da tradução (`--emit-c`). A escolha deve constar na proposta inicial e ser aprovada pelo professor; a aprovação é uma etapa acadêmica externa ao repositório.

### Arquitetura e Progresso da Implementação

| Etapa / Componente | Status | Arquivo(s) Principal(is) | Descrição |
| :--- | :---: | :--- | :--- |
| **1. Análise Léxica (Scanner)** | ✅ Concluído | `src/lexer.l`, `src/lexer.h` | Tokens nomeados (incluindo `DOIS_PONTOS` e operadores), literais com checagem de faixa, rastreamento de linha/coluna, comentários (`%%` e `%glu`), desambiguação léxica e modo `--tokens`. |
| **2. Análise Sintática (Parser)** | ✅ Concluído | `src/parser.y` | Gramática LALR(1) enxuta em Bison com precedência de operadores, controle de fluxo e sub-rotinas. |
| **3. Tabela de Símbolos e Semântica** | ✅ Concluído | `src/symtab.h`, `src/symtab.c`, `src/semantic.h`, `src/semantic.c` | Escopos aninhados, declarações, checagem/inferência de tipos, assinaturas de sub-rotinas, retornos e contexto de laços. |
| **4. Construção e Impressão da AST** | ✅ Concluído | `src/ast.h`, `src/ast.c` | Construção da Árvore Sintática Abstrata tipada em memória e visualização hierárquica via `--ast`. |
| **5. Geração de Código Alvo (C)** | ✅ Concluído | `src/codegen.h`, `src/codegen.c` | Travessia da AST emitindo código C99 estruturado com globais/funções no escopo de arquivo e bloco principal em `main()`. |
| **6. Driver / CLI** | ✅ Concluído | `src/main.c` | Interface de linha de comando para compilar direto para executável (`-o`), rodar (`--run`), emitir C (`--emit-c`), inspecionar AST (`--ast`) e tokens (`--tokens`). |

---

## 🦃 Especificação da Linguagem GLUGLU

A **GLUGLU** é uma linguagem imperativa, de tipagem estática e forte, com sintaxe inspirada em temática avícola/ornitológica.

### 1. Tipos de Dados Suportados

* `inteiro`: Números inteiros (ex: `0`, `42`, `-10`) $\to$ mapeado para `int` em C.
* `real`: Números de ponto flutuante com notação decimal obrigatória (ex: `3.14`, `0.5`) $\to$ mapeado para `double` em C.
* `booleano`: Valores lógicos literais (`true` e `false`) $\to$ mapeado para `bool` (`<stdbool.h>`) em C.
* `texto`: Sequências de caracteres delimitadas por `<` e `>` (ex: `<Olá, GLUGLU!>`) $\to$ mapeado para `char*` em C. A igualdade e a diferença entre textos comparam o conteúdo.

### 2. Comentários

* **Linha única:** iniciam com `%%` e seguem até o final da linha.
  ```gluglu
  %% Isso é um comentário de linha única
  ```
* **Multilinha:** delimitados por `%glu` no início e no fim.
  ```gluglu
  %glu
  Bloco de comentário
  com várias linhas
  %glu
  ```

### 3. Declaração e Atribuição de Variáveis

Toda variável deve ser obrigatoriamente declarada com seu tipo e inicializada no momento da criação:

* **Declaração com inicialização obrigatória:**
  ```gluglu
  glu: <identificador> : <tipo> <- <expressao>;
  ```
  *Exemplo:* `glu: contador : inteiro <- 0;`

* **Reatribuição:**
  ```gluglu
  <identificador> <- <expressao>;
  ```
  *Exemplo:* `contador <- contador + 1;`

### 4. Operadores e Precedência

Da menor para a maior precedência:

1. **Lógico OU:** `or` (associativo à esquerda)
2. **Lógico E:** `and` (associativo à esquerda)
3. **Negação Lógica:** `not` (unário, associativo à direita)
4. **Igualdade / Diferença:** `==`, `!=` (associativos à esquerda)
5. **Relacionais:** `<`, `>`, `<=`, `>=` (associativos à esquerda)
6. **Aditivos:** `+`, `-` (associativos à esquerda)
7. **Multiplicativos:** `*`, `/` (associativos à esquerda)
8. **Menos Unário:** `-` (unário, associativo à direita)

### 5. Entrada e Saída

* **Saída (`GORGOREJA`):** Imprime valores literais, variáveis ou o resultado de expressões na saída padrão, escolhendo automaticamente o formato adequado conforme o tipo semântico na AST (`%d` para `inteiro`, `%f` para `real`, `%s` para `texto` e `true`/`false` para `booleano`).
  ```gluglu
  GORGOREJA(<Resultado:>);
  GORGOREJA(media);
  ```
* **Entrada (`CISCA`):** Lê uma linha por chamada para uma variável previamente declarada. Para `texto`, aceita espaços e aumenta o armazenamento dinamicamente (com liberação automática ao encerrar o programa); valores numéricos e booleanos são validados antes da conversão.
  ```gluglu
  CISCA(idade);
  CISCA(mensagem);
  ```
  Valores booleanos podem ser informados como `true`/`false` ou `1`/`0`.

### 6. Estruturas de Controle de Fluxo

* **Condicional (`IFGLU` / `ELSEGLU`):**
  ```gluglu
  IFGLU (idade >= 18) {
      GORGOREJA(<Acesso liberado!>);
  } ELSEGLU {
      GORGOREJA(<Acesso negado!>);
  }
  ```
* **Laços de Repetição (`WHILEGLU` e `FORGLU`):**
  * `STOPGLU`: Interrompe imediatamente a execução do laço (`break`).
  * `PULAGLU`: Avança para a próxima iteração do laço (`continue`).
  ```gluglu
  WHILEGLU (contador > 0) {
      IFGLU (contador == 2) {
          STOPGLU;
      }
      contador <- contador - 1;
  }

  FORGLU (glu: i : inteiro <- 0; i < 5; i <- i + 1) {
      GORGOREJA(i);
  }
  ```

### 7. Modularização (Funções e Procedimentos)

* **Procedimentos sem retorno (`NINHO`):**
  ```gluglu
  NINHO alimentar_ave(texto ave, inteiro kg) {
      GORGOREJA(<Alimentando >);
      GORGOREJA(ave);
  }
  ```
* **Funções com retorno (`CHOCA` / `RETORNAGLU`):**
  ```gluglu
  CHOCA calcular_dobro(inteiro valor) {
      RETORNAGLU valor * 2;
  }
  ```
  Sub-rotinas (`NINHO` e `CHOCA`) devem ser declaradas no escopo global. Uma função `CHOCA` deve retornar um valor compatível em todos os caminhos (inclusive em chamadas recursivas). Procedimentos não retornam valores; chamadas verificam a espécie da sub-rotina, a quantidade e os tipos dos argumentos.

* **Exemplo combinado:** [exemplos/controle_funcao.glu](./exemplos/controle_funcao.glu) demonstra `CHOCA`, `RETORNAGLU`, `FORGLU` e `PULAGLU`.

---

## 📐 Gramática Formal (EBNF) e Decisões de Sintaxe e Semântica

### Gramática Livre de Contexto (EBNF)

```ebnf
programa          ::= comando_lista ;
comando_lista     ::= comando { comando } ;
comando           ::= decl_var ";"
                    | atribuicao ";"
                    | comando_saida ";"
                    | comando_entrada ";"
                    | comando_if
                    | comando_while
                    | comando_for
                    | "STOPGLU" ";"
                    | "PULAGLU" ";"
                    | "RETORNAGLU" [ expressao ] ";"
                    | chamada_func ";"
                    | decl_proc
                    | decl_func
                    | bloco_escopo ;

bloco_escopo      ::= "{" [ comando_lista ] "}" ;
decl_var          ::= "glu" ":" ID ":" TIPO "<-" expressao ;
atribuicao        ::= ID "<-" expressao ;
comando_saida     ::= "GORGOREJA" "(" expressao ")" ;
comando_entrada   ::= "CISCA" "(" ID ")" ;

comando_if        ::= "IFGLU" "(" expressao ")" bloco_escopo [ "ELSEGLU" bloco_escopo ] ;
comando_while     ::= "WHILEGLU" "(" expressao ")" bloco_escopo ;
comando_for       ::= "FORGLU" "(" ( decl_var | atribuicao ) ";" expressao ";" atribuicao ")" "{" [ comando_lista ] "}" ;

decl_proc         ::= "NINHO" ID "(" [ lista_params ] ")" "{" [ comando_lista ] "}" ;
decl_func         ::= "CHOCA" ID "(" [ lista_params ] ")" "{" [ comando_lista ] "}" ;
lista_params      ::= param { "," param } ;
param             ::= TIPO ID ;

chamada_func      ::= ID "(" [ lista_args ] ")" ;
lista_args        ::= expressao { "," expressao } ;

expressao         ::= expressao ( "+" | "-" | "*" | "/" ) expressao
                    | expressao ( "<" | ">" | "<=" | ">=" | "==" | "!=" ) expressao
                    | expressao ( "and" | "or" ) expressao
                    | ( "not" | "-" ) expressao
                    | "(" expressao ")"
                    | LIT_INT | LIT_REAL | LIT_BOOL | LIT_TEXTO
                    | chamada_func | ID ;
```

### Principais Decisões de Sintaxe e Semântica

1. **Desambiguação Léxica entre `<texto>` e Operadores `<`, `<=`, `<-`:**
   Como literais de texto são delimitados por `<` e `>`, o analisador léxico mantém um estado contextual (`LEX_CTX_EXPR_START`, `LEX_CTX_AFTER_TYPE` e `LEX_CTX_AFTER_VALUE`) combinado a uma *start condition* exclusiva (`TEXT_LIT`). Todos os símbolos possuem tokens nomeados (`DOIS_PONTOS`, `PONTO_VIRGULA`, `OP_MAIS`, `OP_MENOR`, etc.), literais numéricos validam overflow (`strtol`/`strtod`) e os erros léxicos/sintáticos informam linha e coluna.
2. **Inicialização Obrigatória (`glu: id : tipo <- expr;`):**
   Impede o uso de variáveis com lixo de memória, garantindo que toda entrada na Tabela de Símbolos já nasça inicializada. Em caso de *shadowing* com autorreferência (ex.: `glu: x : inteiro <- x + 1;`), o gerador de C usa uma variável temporária para preservar a semântica sem *Undefined Behavior*.
3. **Escopos Aninhados com Tabela Hash (`djb2`):**
   Cada bloco `{ ... }`, laço `FORGLU`, procedimento `NINHO` ou função `CHOCA` cria um novo escopo encadeado ao escopo pai (`symtab_enter_scope` / `symtab_exit_scope`). Variáveis globais declaradas antes de sub-rotinas são promovidas para o escopo de arquivo em C e inicializadas na ordem original dentro de `main()`.
4. **Verificação de Tipos e Coerção Implícita:**
   * Operadores aritméticos (`+`, `-`, `*`, `/`) exigem operandos numéricos (`inteiro` ou `real`). Se um dos operandos for `real`, o resultado é promovido para `real`.
   * Variáveis do tipo `real` aceitam valores do tipo `inteiro` (promoção implícita), mas variáveis `inteiro` rejeitam `real` para evitar perda silenciosa de precisão.
   * Condições de `IFGLU`, `WHILEGLU` e `FORGLU` exigem expressões do tipo `booleano`.
5. **Inferência de Tipo de Retorno em `CHOCA`:**
   Funções declaradas com `CHOCA` têm seu tipo de retorno inferido a partir das instruções `RETORNAGLU` (incluindo suporte a funções recursivas de qualquer tipo); retornos incompatíveis e caminhos sem retorno são rejeitados.
6. **Validação de sub-rotinas e laços:**
   Sub-rotinas só podem ser declaradas no escopo global. Chamadas verificam se o identificador é função/procedimento e se a aridade e os tipos dos argumentos correspondem à declaração. `STOPGLU` e `PULAGLU` só podem aparecer dentro de laços, e `RETORNAGLU` precisa corresponder ao contexto de função ou procedimento.
7. **Entrada e comparação de textos:**
   `CISCA` lê linhas de texto com armazenamento dinâmico e liberação automática no encerramento do programa. Os operadores `==` e `!=` comparam o conteúdo dos textos, não os endereços dos ponteiros C.
8. **Grafia dos operadores lógicos:**
   `and`, `or` e `not` são reconhecidos somente em letras minúsculas.

---

## 📁 Estrutura de Diretórios

```text
.
├── .gitattributes                 # Padronização de finais de linha (LF)
├── .gitignore                     # Arquivos gerados ignorados pelo Git
├── Makefile                       # Regras de compilação e execução de testes
├── README.md                      # Documentação da linguagem e do compilador
├── src/
│   ├── lexer.l                    # Especificação léxica (Flex) com tokens nomeados
│   ├── lexer.h                    # Interface do analisador léxico
│   ├── parser.y                   # Gramática formal (Bison)
│   ├── semantic.h / semantic.c    # Análise semântica (escopos, tipos, retornos, laços)
│   ├── symtab.h / symtab.c        # Tabela de símbolos com escopos aninhados
│   ├── ast.h / ast.c              # Árvore Sintática Abstrata (AST) e impressão
│   ├── codegen.h / codegen.c      # Geração de código C99
│   └── main.c                     # CLI e orquestração das fases
├── exemplos/
│   ├── media.glu                  # Programa 1: cálculo aritmético e saída
│   ├── idade.glu                  # Programa 2: entrada e decisão condicional
│   ├── contador.glu               # Programa 3: repetição WHILEGLU e interrupção com STOPGLU
│   ├── alimentacao.glu            # Programa 4: procedimento modular reutilizável (NINHO)
│   └── controle_funcao.glu        # CHOCA, RETORNAGLU, FORGLU e PULAGLU
└── tests/
    ├── run_tests.sh               # Suíte automatizada de testes (make test)
    ├── valid/
    │   ├── entrada_texto.glu            # Leitura dinâmica de linha e igualdade por conteúdo
    │   ├── escopo_global_e_recursao.glu # Variáveis globais em sub-rotinas e recursão tipada
    │   ├── operadores_logicos.glu       # Operadores and, or e not em minúsculas
    │   └── operadores_relacionais.glu   # Desambiguação de <-, <=, <>, precisão real e shadowing
    └── invalid/
        ├── erro_lexico.glu
        ├── erro_inteiro_overflow.glu
        ├── erro_comentario_nao_fechado.glu
        ├── erro_texto_nao_fechado.glu
        ├── erro_sintatico.glu
        ├── erro_nao_declarada.glu
        ├── erro_tipo_incompativel.glu
        ├── erro_condicao_nao_booleana.glu
        ├── erro_redeclaracao.glu
        ├── erro_chamada_variavel.glu
        ├── erro_aridade.glu
        ├── erro_tipo_argumento.glu
        ├── erro_stop_fora_laco.glu
        ├── erro_pula_fora_laco.glu
        ├── erro_retorno_fora_subrotina.glu
        ├── erro_retorno_em_procedimento.glu
        ├── erro_funcao_retorno_vazio.glu
        ├── erro_funcao_sem_retorno.glu
        ├── erro_funcao_retorno_condicional.glu
        ├── erro_tipos_retorno.glu
        ├── erro_procedimento_como_expressao.glu
        ├── erro_subrotina_como_variavel.glu
        ├── erro_subrotina_aninhada.glu
        ├── erro_menos_unario_texto.glu
        ├── erro_and_maiuscula.glu
        ├── erro_or_maiuscula.glu
        └── erro_not_maiuscula.glu
```

---

## 🛠️ Como Compilar e Executar

### Pré-requisitos

Certifique-se de ter instalado em seu ambiente (Linux ou WSL):
* `gcc` (compatível com C99/C11)
* `flex`
* `bison`
* `make`

No Ubuntu/Debian:
```bash
sudo apt update && sudo apt install build-essential flex bison
```

### 1. Compilar o Compilador

```bash
make
```

### 2. Compilar e Executar Programas GLUGLU

```bash
# Compila e executa diretamente em um único comando
./glugluc --run exemplos/media.glu

# Compila para um executável nativo (estilo gcc)
./glugluc exemplos/media.glu -o media
./media

# Se omitir -o, gera o executável com o nome do arquivo (ex.: ./media)
./glugluc exemplos/media.glu
./media
```

### 3. Inspecionar cada Fase da Compilação

```bash
# Fase léxica: imprime todos os tokens (linha:coluna, nome e valor)
./glugluc --tokens exemplos/media.glu

# Árvore Sintática Abstrata (AST) anotada com tipos
./glugluc --ast exemplos/media.glu

# Emitir apenas o código C gerado (em arquivo com -o ou no terminal)
./glugluc --emit-c exemplos/media.glu -o saida.c
```

### 4. Executar a Suíte Automatizada de Testes

O alvo `make test` executa `tests/run_tests.sh`, validando a CLI, todos os programas em `exemplos/` e `tests/valid/` (`--tokens`, `--ast`, `--emit-c` com `gcc -std=c99 -Wall -Wextra -Werror`, compilação direta com `-o` e execução com `--run`) e todos os casos de erro em `tests/invalid/`:

```bash
make test
```

### Limpar os arquivos de build
```bash
make clean
```

---

## 💻 Exemplos de Processamento e Execução

### Exemplo 1: Cálculo de Média Ponderada (`exemplos/media.glu`)

**Entrada (`exemplos/media.glu`):**
```gluglu
glu: nota1 : real <- 8.5;
glu: nota2 : real <- 7.0;
glu: media : real <- (nota1 * 2.0 + nota2 * 3.0) / 5.0;

GORGOREJA(<Media Ponderada: >);
GORGOREJA(media);
```

**AST Gerada (`./glugluc --ast exemplos/media.glu`):**
```text
=== AST (Arvore Sintatica Abstrata) ===
[VAR_DECL] nota1 : double
    [LIT_REAL] 8.5 (double)
[VAR_DECL] nota2 : double
    [LIT_REAL] 7.0 (double)
[VAR_DECL] media : double
    [BIN_OP '/'] (double)
        [BIN_OP '+'] (double)
            [BIN_OP '*'] (double)
                [ID] nota1 (double)
                [LIT_REAL] 2.0 (double)
            [BIN_OP '*'] (double)
                [ID] nota2 (double)
                [LIT_REAL] 3.0 (double)
        [LIT_REAL] 5.0 (double)
[GORGOREJA]
    [LIT_TEXTO] <Media Ponderada: > (char*)
[GORGOREJA]
    [ID] media (double)
```

**Trecho principal do C emitido (`./glugluc --emit-c exemplos/media.glu`):**
```c
int main(void) {
    double gluglu_user_nota1 = 8.5;
    double gluglu_user_nota2 = 7.0;
    double gluglu_user_media = (((gluglu_user_nota1 * 2.0) + (gluglu_user_nota2 * 3.0)) / 5.0);
    printf("%s\n", "Media Ponderada: ");
    printf("%f\n", (double)(gluglu_user_media));
    return 0;
}
```

**Execução (`./glugluc --run exemplos/media.glu`):**
```text
Media Ponderada: 
7.600000
```

---

### Exemplo 2: Procedimento Modular (`exemplos/alimentacao.glu`)

**Entrada (`exemplos/alimentacao.glu`):**
```gluglu
NINHO alimentar_ave(texto ave, inteiro kg) {
    GORGOREJA(<Alimentando >);
    GORGOREJA(ave);
    GORGOREJA(< com >);
    GORGOREJA(kg);
    GORGOREJA(< kg de milho.>);
}

alimentar_ave(<Pavoa>, 3);
alimentar_ave(<Galo>, 2);
```

**Trecho principal do C emitido (`./glugluc --emit-c exemplos/alimentacao.glu`):**
```c
void gluglu_user_alimentar_ave(char* gluglu_user_ave, int gluglu_user_kg) {
    printf("%s\n", "Alimentando ");
    printf("%s\n", gluglu_user_ave);
    printf("%s\n", " com ");
    printf("%d\n", gluglu_user_kg);
    printf("%s\n", " kg de milho.");
}

int main(void) {
    gluglu_user_alimentar_ave("Pavoa", 3);
    gluglu_user_alimentar_ave("Galo", 2);
    return 0;
}
```
