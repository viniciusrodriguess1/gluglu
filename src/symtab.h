#ifndef SYMTAB_H
#define SYMTAB_H

#include <stdbool.h>
#include <stddef.h>

typedef enum {
    TYPE_UNKNOWN = 0,
    TYPE_INTEIRO,
    TYPE_REAL,
    TYPE_BOOLEANO,
    TYPE_TEXTO,
    TYPE_VOID
} DataType;

typedef enum {
    SYM_VAR,
    SYM_FUNCTION,
    SYM_PROCEDURE
} SymbolKind;

typedef struct Symbol {
    char *name;
    DataType type;
    SymbolKind kind;
    DataType *param_types;
    size_t param_count;
    int scope_level;
    bool is_initialized;
    struct Symbol *next; // Tratamento de colisões por encadeamento
} Symbol;

typedef struct Scope {
    int level;
    Symbol **buckets;
    int size;
    struct Scope *parent; // Ponteiro para o escopo pai (estático/aninhado)
} Scope;

typedef struct SymbolTable {
    Scope *current_scope;
    int current_level;
} SymbolTable;

// Gerenciamento de ciclo de vida da tabela
SymbolTable *symtab_create(void);
void symtab_destroy(SymbolTable *st);

// Gerenciamento de escopos
void symtab_enter_scope(SymbolTable *st);
void symtab_exit_scope(SymbolTable *st);

// Inserção e buscas
bool symtab_insert(SymbolTable *st, const char *name, DataType type, SymbolKind kind);
bool symtab_set_signature(Symbol *symbol, const DataType *param_types, size_t param_count);
Symbol *symtab_lookup(SymbolTable *st, const char *name);
Symbol *symtab_lookup_current_scope(SymbolTable *st, const char *name);

// Utilitários de tipos
DataType str_to_datatype(const char *str);
const char *datatype_to_str(DataType type);
bool is_type_compatible(DataType target, DataType src);

#endif
