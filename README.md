# GLUGLU — Compilador e Tradutor

Implementação do tradutor/compilador da linguagem **GLUGLU**, desenvolvido como projeto prático para a disciplina de **Compiladores**.

---

## 👥 Integrantes

* Pedro Vinícius Marques
* Rodrigo Dias da Paz Santos
* Vinícius Rodrigues Santana

---

## 📌 Sobre o Repositório

Este projeto implementa um **tradutor completo** para a linguagem didática GLUGLU. O compilador processa o código-fonte `.glu`, executa as fases completas de compilação clássica e gera código equivalente em **C estruturado**, pronto para ser compilado com qualquer compilador C padrão (como `gcc` ou `clang`).

### Fases do Compilador

1. **Análise Léxica (Scanner):** Implementada via `Flex`, convertendo o fluxo de caracteres em tokens válidos e descartando espaços e comentários.
2. **Análise Sintática (Parser):** Desenvolvida com `Bison` (LALR), validando a estrutura gramatical, precedência de operadores e comandos de controle.
3. **Análise Semântica & Tabela de Símbolos:** Validação de escopos aninhados, checagem e promoção implícita de tipos (`inteiro` $\to$ `real`), verificação de inicialização e identificadores duplicados ou não declarados.
4. **Árvore Sintática Abstrata (AST) & Geração de Código:** Representação intermediária e emissão do código final estruturado em linguagem C.

---

## 🦃 Sobre a Linguagem GLUGLU

A **GLUGLU** é uma linguagem imperativa, de tipagem estática e de sintaxe expressiva e lúdica com temática ornitológica/avícola. Ela foi concebida para demonstrar de forma clara e visual o funcionamento interno de analisadores formais.

### 1. Tipos de Dados Suportados

* `inteiro`: Números inteiros (ex: `0`, `42`, `-10`).
* `real`: Números de ponto flutuante com notação decimal obrigatória (ex: `3.14`, `0.5`).
* `booleano`: Valores lógicos literais (`true` e `false`).
* `texto`: Sequências de caracteres delimitadas por `<` e `>` (ex: `<Olá, GLUGLU!>`).

### 2. Comentários

* **Linha única:** iniciam com `%%` até o fim da linha.
  ```gluglu
  %% Isso é um comentário de linha única
  ```
* **Multilinha:** delimitados por `%glu`.
  ```gluglu
  %glu
  Bloco de comentário
  com várias linhas
  %glu
  ```

### 3. Declaração e Atribuição de Variáveis

Toda variável deve ser obrigatoriamente declarada com seu tipo e inicializada no momento da criação:

* **Declaração e inicialização:**
  ```gluglu
  glu: <identificador> : <tipo> <- <expressao>;
  ```
  *Exemplo:* `glu: contador : inteiro <- 0;`

* **Reatribuição:**
  ```gluglu
  <identificador> <- <expressao>;
  ```
  *Exemplo:* `contador <- contador + 1;`

### 4. Operadores

* **Aritméticos:** `+`, `-`, `*`, `/`
* **Relacionais:** `<`, `>`, `<=`, `>=`, `==`
* **Lógicos:** `And`, `or`, `not`

### 5. Entrada e Saída

* **Saída (`GORGOREJA`):** Imprime valores, textos ou resultados de expressões na saída padrão.
  ```gluglu
  GORGOREJA(<Resultado: >);
  GORGOREJA(media);
  ```
* **Entrada (`CISCA`):** Lê valores fornecidos pelo usuário via console para uma variável.
  ```gluglu
  CISCA(idade);
  ```

### 6. Estruturas de Controle de Fluxo

* **Condicional (`IFGLU`):**
  ```gluglu
  IFGLU (idade >= 18) {
      GORGOREJA(<Acesso liberado!>);
  }
  ```
* **Laço de Repetição (`WHILEGLU` e `FORGLU`):**
  * `STOPGLU`: Interrompe imediatamente a execução do laço (`break`).
  * `PULAGLU`: Pula para a próxima iteração do laço (`continue`).
  ```gluglu
  WHILEGLU (contador > 0) {
      IFGLU (contador == 2) {
          STOPGLU;
      }
      contador <- contador - 1;
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

---

## 📁 Estrutura de Diretórios

```text
.
├── Makefile             # Regras de compilação automatizadas
├── README.md            # Documentação da linguagem e do compilador
├── src/
│   ├── ast.h            # Definições da Árvore Sintática Abstrata (AST)
│   ├── ast.c            # Construtores de nós e geração de código C
│   ├── symtab.h         # Estruturas da Tabela de Símbolos e escopos
│   ├── symtab.c         # Lógica da Tabela de Símbolos e validações
│   ├── lexer.l          # Especificação léxica (Flex)
│   └── parser.y         # Gramática formal e ações sintáticas (Bison)
└── exemplos/
    ├── media.glu        # Programa 1: cálculo aritmético e saída
    ├── idade.glu        # Programa 2: entrada e decisão condicional
    ├── laco.glu         # Programa 3: repetição e interrupção com STOPGLU
    └── ninho.glu        # Programa 4: procedimento modular reutilizável
```

---

## 🛠️ Como Compilar e Executar

### Pré-requisitos

Certifique-se de ter instalado em seu sistema operacional:
* `gcc` (ou compilador C compatível com padrão C99/C11)
* `flex`
* `bison`
* `make`

No Ubuntu/Debian:
```bash
sudo apt update && sudo apt install build-essential flex bison
```

### 1. Compilar o Tradutor

Para compilar o binário `glugluc`, execute:
```bash
make
```

### 2. Traduzir e Executar um Código GLUGLU

Passe o arquivo-fonte `.glu` como entrada para o `glugluc` gerando um arquivo C intermediário:

```bash
# 1. Traduz GLUGLU para C
./glugluc < exemplos/media.glu > saida.c

# 2. Compila o código C gerado
gcc saida.c -o programa_gluglu

# 3. Executa o binário final
./programa_gluglu
```

### Limpar os arquivos de build
```bash
make clean
```