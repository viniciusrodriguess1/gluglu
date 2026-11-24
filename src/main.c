#define _POSIX_C_SOURCE 200809L

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "ast.h"
#include "codegen.h"
#include "lexer.h"
#include "semantic.h"
#include "symtab.h"
#include "parser.tab.h"

extern ASTNode *root;
int yyparse(void);

typedef enum {
    MODE_COMPILE = 0,
    MODE_RUN,
    MODE_EMIT_C,
    MODE_AST,
    MODE_TOKENS
} RunMode;

static void print_usage(FILE *out, const char *prog) {
    fprintf(out,
            "Uso:\n"
            "  %s <arquivo.glu> [-o <executavel>]   Compila para executavel nativo\n"
            "  %s --run <arquivo.glu>               Compila e executa diretamente\n"
            "  %s --emit-c <arquivo.glu> [-o <c>]   Emite apenas o codigo C gerado\n"
            "  %s --ast <arquivo.glu> [-o <arq>]    Imprime a AST tipada\n"
            "  %s --tokens <arquivo.glu> [-o <arq>] Imprime os tokens do analisador lexico\n"
            "  %s --help                            Exibe esta ajuda\n",
            prog, prog, prog, prog, prog, prog);
}

static char *derive_default_output(const char *input_path) {
    if (!input_path) {
        return gluglu_strdup("programa_gluglu");
    }

    const char *base = input_path;
    for (const char *p = input_path; *p; p++) {
        if (*p == '/' || *p == '\\') {
            base = p + 1;
        }
    }

    size_t len = strlen(base);
    if (len > 4 && strcmp(base + len - 4, ".glu") == 0) {
        len -= 4;
    }
    if (len == 0) {
        return gluglu_strdup("programa_gluglu");
    }

    char *out = (char *)malloc(len + 1);
    if (!out) return NULL;
    memcpy(out, base, len);
    out[len] = '\0';
    return out;
}

static int run_process(const char *program, char *const argv[], bool use_path) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return 1;
    }
    if (pid == 0) {
        if (use_path) {
            execvp(program, argv);
        } else {
            execv(program, argv);
        }
        perror(program);
        _exit(127);
    }

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        perror("waitpid");
        return 1;
    }
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    return 1;
}

static int dump_tokens(FILE *out) {
    int tok;
    while ((tok = yylex()) != 0) {
        fprintf(out, "%d:%d\t%s", yylineno, token_column, lexer_token_name(tok));
        switch (tok) {
            case ID:
                fprintf(out, "\t%s", yylval.str);
                free(yylval.str);
                break;
            case LIT_TEXTO:
                fprintf(out, "\t<%s>", yylval.str);
                free(yylval.str);
                break;
            case LIT_INT:
                fprintf(out, "\t%d", yylval.num_int);
                break;
            case LIT_REAL: {
                char buf[64];
                format_real_literal(yylval.num_real, buf, sizeof(buf));
                fprintf(out, "\t%s", buf);
                break;
            }
            case LIT_BOOL:
                fprintf(out, "\t%s", yylval.num_int ? "true" : "false");
                break;
            case TIPO:
                fprintf(out, "\t%s", datatype_to_str(yylval.data_type));
                break;
            default:
                break;
        }
        fputc('\n', out);
    }

    if (lexical_errors > 0) {
        fprintf(stderr, "\nAnalise lexica concluida com %d erro(s).\n", lexical_errors);
        return 1;
    }
    return 0;
}

static int compile_to_binary(ASTNode *ast_root, const char *output_bin, bool execute_after) {
    char tmp_dir[] = "/tmp/glugluc_XXXXXX";
    if (!mkdtemp(tmp_dir)) {
        perror("mkdtemp");
        return 1;
    }

    char c_path[256];
    char bin_path[256];
    snprintf(c_path, sizeof(c_path), "%s/programa.c", tmp_dir);
    snprintf(bin_path, sizeof(bin_path), "%s/programa", tmp_dir);

    const char *target_bin = execute_after ? bin_path : output_bin;

    FILE *c_file = fopen(c_path, "w");
    if (!c_file) {
        perror(c_path);
        rmdir(tmp_dir);
        return 1;
    }
    generate_code(ast_root, c_file);
    if (fclose(c_file) != 0) {
        perror(c_path);
        unlink(c_path);
        rmdir(tmp_dir);
        return 1;
    }

    char *gcc_argv[] = {
        "gcc",
        "-std=c99",
        c_path,
        "-o",
        (char *)target_bin,
        NULL
    };
    int status = run_process("gcc", gcc_argv, true);
    unlink(c_path);

    if (status == 0 && execute_after) {
        char *run_argv[] = { (char *)target_bin, NULL };
        status = run_process(target_bin, run_argv, false);
    }

    if (execute_after) {
        unlink(bin_path);
    }
    rmdir(tmp_dir);
    return status;
}

static bool set_mode(RunMode *current, bool *explicit_mode, RunMode next) {
    if (*explicit_mode && *current != next) {
        fputs("Erro: opcoes de modo mutuamente exclusivas.\n", stderr);
        return false;
    }
    *current = next;
    *explicit_mode = true;
    return true;
}

int main(int argc, char **argv) {
    RunMode mode = MODE_COMPILE;
    bool explicit_mode = false;
    const char *input_path = NULL;
    const char *output_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            print_usage(stdout, argv[0]);
            return 0;
        } else if (strcmp(argv[i], "--run") == 0 || strcmp(argv[i], "-r") == 0) {
            if (!set_mode(&mode, &explicit_mode, MODE_RUN)) return 1;
        } else if (strcmp(argv[i], "--emit-c") == 0 || strcmp(argv[i], "-c") == 0) {
            if (!set_mode(&mode, &explicit_mode, MODE_EMIT_C)) return 1;
        } else if (strcmp(argv[i], "--ast") == 0 || strcmp(argv[i], "-a") == 0) {
            if (!set_mode(&mode, &explicit_mode, MODE_AST)) return 1;
        } else if (strcmp(argv[i], "--tokens") == 0 || strcmp(argv[i], "-t") == 0) {
            if (!set_mode(&mode, &explicit_mode, MODE_TOKENS)) return 1;
        } else if (strcmp(argv[i], "-o") == 0 || strcmp(argv[i], "--output") == 0) {
            if (i + 1 >= argc) {
                fputs("Erro: a opcao '-o' requer um caminho de saida.\n", stderr);
                print_usage(stderr, argv[0]);
                return 1;
            }
            output_path = argv[++i];
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "Erro: opcao desconhecida '%s'.\n", argv[i]);
            print_usage(stderr, argv[0]);
            return 1;
        } else if (!input_path) {
            input_path = argv[i];
        } else {
            fprintf(stderr, "Erro: argumento inesperado '%s'.\n", argv[i]);
            print_usage(stderr, argv[0]);
            return 1;
        }
    }

    if (mode == MODE_RUN && output_path) {
        fputs("Erro: '--run' nao pode ser combinado com '-o'.\n", stderr);
        return 1;
    }

    FILE *input_file = NULL;
    if (input_path) {
        input_file = fopen(input_path, "r");
        if (!input_file) {
            perror(input_path);
            return 1;
        }
        yyin = input_file;
    }

    int status = 0;

    if (mode == MODE_TOKENS) {
        FILE *out = stdout;
        if (output_path) {
            out = fopen(output_path, "w");
            if (!out) {
                perror(output_path);
                if (input_file) fclose(input_file);
                return 1;
            }
        }
        status = dump_tokens(out);
        if (output_path) fclose(out);
        yylex_destroy();
        if (input_file) fclose(input_file);
        return status;
    }

    if (!semantic_init()) {
        fputs("Erro interno: memoria insuficiente ao inicializar a analise semantica.\n", stderr);
        if (input_file) fclose(input_file);
        return 1;
    }

    if (yyparse() == 0 && lexical_errors == 0 && semantic_error_count() == 0) {
        if (mode == MODE_AST || mode == MODE_EMIT_C) {
            FILE *out = stdout;
            if (output_path) {
                out = fopen(output_path, "w");
                if (!out) {
                    perror(output_path);
                    status = 1;
                }
            }
            if (status == 0) {
                if (mode == MODE_AST) {
                    print_ast(root, out);
                } else {
                    generate_code(root, out);
                }
                if (output_path && fclose(out) != 0) {
                    perror(output_path);
                    status = 1;
                }
            }
        } else if (mode == MODE_RUN) {
            status = compile_to_binary(root, NULL, true);
        } else {
            char *default_out = NULL;
            const char *target = output_path;
            if (!target) {
                default_out = derive_default_output(input_path);
                if (!default_out) {
                    fputs("Erro interno: memoria insuficiente.\n", stderr);
                    status = 1;
                } else {
                    target = default_out;
                }
            }
            if (status == 0) {
                status = compile_to_binary(root, target, false);
            }
            free(default_out);
        }
    } else {
        fprintf(stderr, "\nCompilacao abortada: foram encontrados erros no programa.\n");
        status = 1;
    }

    free_ast(root);
    root = NULL;
    semantic_cleanup();
    yylex_destroy();
    if (input_file) fclose(input_file);
    return status;
}
