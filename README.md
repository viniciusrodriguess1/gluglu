# GLUGLU — Compilador e Tradutor

Implementação do tradutor/compilador da linguagem **GLUGLU**, desenvolvido como projeto prático para a disciplina de **Compiladores**.

---

## 👥 Integrantes

* Pedro Vinícius Marques
* Rodrigo Dias da Paz Santos
* Vinícius Rodrigues Santana

---

## 📌 Sobre o Repositório e Modalidade Escolhida

Este projeto implementa um **tradutor (transpilador) completo** para a linguagem didática **GLUGLU**. O compilador processa o código-fonte `.glu`, executa as fases clássicas de compilação (léxica, sintática, semântica e construção de AST) e emite código equivalente em **C estruturado (C99/C11)**, pronto para ser compilado por `gcc` ou `clang`.

### Justificativa da Linguagem de Destino

O C foi escolhido por mapear diretamente os tipos estáticos e as estruturas imperativas da GLUGLU, produzir código nativo compilável com ferramentas amplamente disponíveis (`gcc` e `clang`) e permitir inspecionar o resultado da tradução. A escolha deve constar na proposta inicial e ser aprovada pelo professor; a aprovação é uma etapa acadêmica externa ao repositório.

### Progresso da Implementação

| Etapa / Componente | Status | Arquivo(s) Principal(is) | Descrição |
| :--- | :---: | :--- | :--- |
| **1. Análise Léxica (Scanner)** | ✅ Concluído | `src/lexer.l` | Reconhecimento de tokens, literais, palavras-chave, comentários (`%%` e `%glu`) e desambiguação léxica com Flex. |
| **2. Análise Sintática (Parser)** | ✅ Concluído | `src/parser.y` | Gramática LALR(1) em Bison com precedência de operadores, controle de fluxo e sub-rotinas. |
| **3. Tabela de Símbolos e Semântica** | ✅ Concluído | `src/symtab.h`, `src/symtab.c`, `src/parser.y` | Escopos aninhados, declarações, tipos, assinaturas de sub-rotinas, retornos e contexto de laços. |
| **4. Construção e Impressão da AST** | ✅ Concluído | `src/ast.h`, `src/ast.c` | Construção da Árvore Sintática Abstrata tipada em memória e visualização hierárquica via flag `--ast`. |
| **5. Geração de Código Alvo (C)** | ✅ Concluído | `src/ast.c` | Travessia da AST emitindo código C estruturado com funções no escopo global e bloco principal em `main()`. |

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

* **Saída (`GORGOREJA`):** Imprime valores literais, variáveis ou o resultado de expressões na saída padrão, escolhendo automaticamente o especificador de formato (`%d`, `%f`, `%s`) de acordo com o tipo semântico do nó na AST.
  ```gluglu
  GORGOREJA(<Resultado:>);
  GORGOREJA(media);
  ```
* **Entrada (`CISCA`):** Lê uma linha por chamada para uma variável previamente declarada. Para `texto`, aceita espaços e aumenta o armazenamento dinamicamente; valores numéricos e booleanos são validados antes da conversão.
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
      GORGOREJA(<Alimentando>);
      GORGOREJA(ave);
  }
  ```
* **Funções com retorno (`CHOCA` / `RETORNAGLU`):**
  ```gluglu
  CHOCA calcular_dobro(inteiro valor) {
      RETORNAGLU valor * 2;
  }
  ```
  Uma função deve retornar um valor em todos os caminhos. Procedimentos não retornam valores; chamadas verificam a espécie da sub-rotina, a quantidade e os tipos dos argumentos.

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

1. **Desambiguação Léxica entre `<texto>` e Operador `<`:**
   Como literais de texto são delimitados por `<` e `>`, expressões como `a < b > c` poderiam ser confundidas com uma string literal. O analisador léxico mantém a flag contextual `can_be_relop`: imediatamente após identificadores, literais numéricos/booleanos ou `)`, o símbolo `<` é tratado como operador relacional (devolvendo o restante ao buffer via `yyless(1)`); nos demais contextos (como argumentos de `GORGOREJA(<texto>)` ou lado direito de `<-`), é reconhecido como `LIT_TEXTO`.
2. **Inicialização Obrigatória (`glu: id : tipo <- expr;`):**
   Impede o uso de variáveis com lixo de memória, garantindo que toda entrada na Tabela de Símbolos já nasça inicializada.
3. **Escopos Aninhados com Tabela Hash (`djb2`):**
   Cada bloco `{ ... }`, laço `FORGLU`, procedimento `NINHO` ou função `CHOCA` cria um novo escopo encadeado ao escopo pai (`symtab_enter_scope` / `symtab_exit_scope`). Isso permite *shadowing* seguro em blocos internos, mas proíbe redeclarações no mesmo nível de escopo.
4. **Verificação de Tipos e Coerção Implícita:**
   * Operadores aritméticos (`+`, `-`, `*`, `/`) exigem operandos numéricos (`inteiro` ou `real`). Se um dos operandos for `real`, o resultado é promovido para `real`.
   * Variáveis do tipo `real` aceitam valores do tipo `inteiro` (promoção implícita), mas variáveis `inteiro` rejeitam `real` para evitar perda silenciosa de precisão.
   * Condições de `IFGLU`, `WHILEGLU` e `FORGLU` exigem expressões do tipo `booleano`.
5. **Inferência de Tipo de Retorno em `CHOCA`:**
   Funções declaradas com `CHOCA` têm seu tipo de retorno inferido a partir das instruções `RETORNAGLU`; retornos incompatíveis e caminhos sem retorno são rejeitados.
6. **Validação de sub-rotinas e laços:**
   Chamadas verificam se o identificador é função/procedimento e se a aridade e os tipos dos argumentos correspondem à declaração. `STOPGLU` e `PULAGLU` só podem aparecer dentro de laços, e `RETORNAGLU` precisa corresponder ao contexto de função ou procedimento.
7. **Entrada e comparação de textos:**
   `CISCA` lê linhas de texto com armazenamento dinâmico. Os operadores `==` e `!=` comparam o conteúdo dos textos, não os endereços dos ponteiros C.
8. **Grafia dos operadores lógicos:**
   `and`, `or` e `not` são reconhecidos somente em letras minúsculas.

---

## 📁 Estrutura de Diretórios

```text
.
├── Makefile                       # Regras de compilação automatizadas
├── README.md                      # Documentação da linguagem e do compilador
├── src/
│   ├── ast.h                      # Definições da Árvore Sintática Abstrata (AST)
│   ├── ast.c                      # Construtores de nós, impressão da AST e geração de código C
│   ├── symtab.h                   # Estruturas da Tabela de Símbolos e escopos
│   ├── symtab.c                   # Lógica da Tabela de Símbolos e validações de tipo
│   ├── lexer.l                    # Especificação léxica (Flex)
│   └── parser.y                   # Gramática formal e ações sintático-semânticas (Bison)
├── exemplos/
│   ├── media.glu                  # Programa 1: cálculo aritmético e saída
│   ├── idade.glu                  # Programa 2: entrada e decisão condicional
│   ├── contador.glu               # Programa 3: repetição WHILEGLU e interrupção com STOPGLU
│   ├── alimentacao.glu            # Programa 4: procedimento modular reutilizável (NINHO)
│   └── controle_funcao.glu        # CHOCA, RETORNAGLU, FORGLU e PULAGLU
└── tests/
    ├── valid/
    │   ├── entrada_texto.glu       # Leitura dinâmica de linha e igualdade por conteúdo
    │   └── operadores_logicos.glu  # Operadores and, or e not em minúsculas
    └── invalid/
        ├── erro_lexico.glu
        ├── erro_comentario_nao_fechado.glu
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

### 1. Compilar o Tradutor

```bash
make
```

### 2. Visualizar a AST de um Programa GLUGLU

Use a flag `--ast` (ou `-a`) para inspecionar a Árvore Sintática Abstrata anotada com os tipos semânticos:

```bash
./glugluc --ast < exemplos/media.glu
```

### 3. Traduzir para C e Executar (Casos Válidos)

```bash
# 1. Traduz GLUGLU para C
./glugluc < exemplos/media.glu > saida.c

# 2. Compila o código C gerado
gcc saida.c -o programa_gluglu

# 3. Executa o binário final
./programa_gluglu
```

### 4. Verificar os Exemplos Manualmente

Os programas de demonstração estão em `exemplos/`, e os casos válidos e inválidos para conferência manual estão em `tests/valid/` e `tests/invalid/`. Não há uma suíte automatizada: compile o tradutor e teste cada arquivo conforme necessário.

```bash
# Compile o tradutor
make

# Caso válido: traduza, compile o C gerado e execute
./glugluc < exemplos/media.glu > saida.c
gcc -std=c99 saida.c -o programa_gluglu
./programa_gluglu

# Caso inválido: confira se o tradutor apresenta o erro esperado
./glugluc < tests/invalid/erro_lexico.glu
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

GORGOREJA(<Media Ponderada:>);
GORGOREJA(media);
```

**AST Gerada (`./glugluc --ast < exemplos/media.glu`):**
```text
=== AST (Arvore Sintatica Abstrata) ===
[VAR_DECL] nota1 : double
    [LIT_REAL] 8.500000 (double)
[VAR_DECL] nota2 : double
    [LIT_REAL] 7.000000 (double)
[VAR_DECL] media : double
    [BIN_OP '/'] (double)
        [BIN_OP '+'] (double)
            [BIN_OP '*'] (double)
                [ID] nota1 (double)
                [LIT_REAL] 2.000000 (double)
            [BIN_OP '*'] (double)
                [ID] nota2 (double)
                [LIT_REAL] 3.000000 (double)
        [LIT_REAL] 5.000000 (double)
[GORGOREJA]
    [LIT_TEXTO] <Media Ponderada:> (char*)
[GORGOREJA]
    [ID] media (double)
```

**Trecho principal do C emitido** (o tradutor também inclui funções auxiliares de entrada):
```c
int main() {
    double gluglu_user_nota1 = 8.500000;
    double gluglu_user_nota2 = 7.000000;
    double gluglu_user_media = (((gluglu_user_nota1 * 2.000000) + (gluglu_user_nota2 * 3.000000)) / 5.000000);
    printf("%s\n", "Media Ponderada: ");
    printf("%f\n", (double)(gluglu_user_media));
    return 0;
}
```

**Saída da Execução:**
```text
Media Ponderada: 
7.600000
```

---

### Exemplo 2: Procedimento Modular (`exemplos/alimentacao.glu`)

**Entrada (`exemplos/alimentacao.glu`):**
```gluglu
NINHO alimentar_ave(texto ave, inteiro kg) {
    GORGOREJA(<Alimentando>);
    GORGOREJA(ave);
    GORGOREJA(< com >);
    GORGOREJA(kg);
    GORGOREJA(< kg de milho.>);
}

alimentar_ave(<Pavoa>, 3);
alimentar_ave(<Galo>, 2);
```

**Trecho principal do C emitido** (os nomes GLUGLU recebem o prefixo `gluglu_user_` no C):
```c
void gluglu_user_alimentar_ave(char* gluglu_user_ave, int gluglu_user_kg) {
    printf("%s\n", "Alimentando ");
    printf("%s\n", gluglu_user_ave);
    printf("%s\n", " com ");
    printf("%d\n", gluglu_user_kg);
    printf("%s\n", " kg de milho.");
}

int main() {
    gluglu_user_alimentar_ave("Pavoa", 3);
    gluglu_user_alimentar_ave("Galo", 2);
    return 0;
}
```
