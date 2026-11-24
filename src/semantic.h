#ifndef SEMANTIC_H
#define SEMANTIC_H

#include <stdbool.h>
#include "ast.h"
#include "symtab.h"

bool semantic_init(void);
void semantic_cleanup(void);
int semantic_error_count(void);

// Escopos e controle de laços
void semantic_enter_scope(void);
void semantic_exit_scope(void);
void semantic_enter_loop(void);
void semantic_exit_loop(void);
void semantic_check_loop_control(const char *keyword, int line);

// Sub-rotinas (NINHO / CHOCA)
void semantic_begin_procedure(const char *name, int line);
void semantic_begin_function(const char *name, int line);
void semantic_register_params(ASTNode *params, int line);
void semantic_end_procedure(void);
DataType semantic_end_function(ASTNode *body, const char *name, int line);

// Declarações, comandos e expressões
void semantic_declare_var(const char *name, DataType type, DataType expr_type, int line);
void semantic_declare_param(const char *name, DataType type, int line);
DataType semantic_check_assignment(const char *name, DataType expr_type, int line);
DataType semantic_check_read(const char *name, int line);
DataType semantic_check_var_use(const char *name, int line);
DataType semantic_check_call(const char *name, ASTNode *args, int line);
void semantic_check_call_as_expr(DataType ret_type, int line);
void semantic_check_return(bool has_value, int line);
void semantic_check_condition(const char *cmd, DataType cond_type, int line);

DataType semantic_infer_arith(const char *op, DataType left, DataType right, int line);
DataType semantic_infer_unary_minus(DataType operand, int line);
DataType semantic_check_rel(const char *op, DataType left, DataType right, int line);
DataType semantic_check_logic(const char *op, DataType left, DataType right, int line);

#endif
