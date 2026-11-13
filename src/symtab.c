#include "symtab.h"
#include <stdlib.h>
#include <string.h>

#define HASH_SIZE 64

static unsigned int hash(const char *str, int size) {
    unsigned int h = 5381;
    int c;
    while ((c = *str++)) {
        h = ((h << 5) + h) + c; // h * 33 + c (djb2)
    }
    return h % size;
}

static Scope *scope_create(int level, Scope *parent) {
    Scope *scope = (Scope *)malloc(sizeof(Scope));
    if (!scope) return NULL;
    scope->level = level;
    scope->size = HASH_SIZE;
    scope->buckets = (Symbol **)calloc(HASH_SIZE, sizeof(Symbol *));
    scope->parent = parent;
    return scope;
}

static void scope_destroy(Scope *scope) {
    if (!scope) return;
    for (int i = 0; i < scope->size; i++) {
        Symbol *curr = scope->buckets[i];
        while (curr) {
            Symbol *next = curr->next;
            free(curr->name);
            free(curr->param_types);
            free(curr);
            curr = next;
        }
    }
    free(scope->buckets);
    free(scope);
}

SymbolTable *symtab_create(void) {
    SymbolTable *st = (SymbolTable *)malloc(sizeof(SymbolTable));
    if (!st) return NULL;
    st->current_level = 0;
    st->current_scope = scope_create(0, NULL);
    return st;
}

void symtab_destroy(SymbolTable *st) {
    if (!st) return;
    while (st->current_scope) {
        symtab_exit_scope(st);
    }
    free(st);
}

void symtab_enter_scope(SymbolTable *st) {
    if (!st) return;
    st->current_level++;
    Scope *new_scope = scope_create(st->current_level, st->current_scope);
    st->current_scope = new_scope;
}

void symtab_exit_scope(SymbolTable *st) {
    if (!st || !st->current_scope) return;
    Scope *old_scope = st->current_scope;
    st->current_scope = old_scope->parent;
    st->current_level--;
    scope_destroy(old_scope);
}

Symbol *symtab_lookup_current_scope(SymbolTable *st, const char *name) {
    if (!st || !st->current_scope || !name) return NULL;
    Scope *scope = st->current_scope;
    unsigned int idx = hash(name, scope->size);
    Symbol *curr = scope->buckets[idx];
    while (curr) {
        if (strcmp(curr->name, name) == 0) {
            return curr;
        }
        curr = curr->next;
    }
    return NULL;
}

Symbol *symtab_lookup(SymbolTable *st, const char *name) {
    if (!st || !name) return NULL;
    Scope *scope = st->current_scope;
    while (scope) {
        unsigned int idx = hash(name, scope->size);
        Symbol *curr = scope->buckets[idx];
        while (curr) {
            if (strcmp(curr->name, name) == 0) {
                return curr;
            }
            curr = curr->next;
        }
        scope = scope->parent;
    }
    return NULL;
}

bool symtab_insert(SymbolTable *st, const char *name, DataType type, SymbolKind kind) {
    if (!st || !st->current_scope || !name) return false;
    if (symtab_lookup_current_scope(st, name) != NULL) {
        return false; // Já existe no escopo atual
    }
    Scope *scope = st->current_scope;
    unsigned int idx = hash(name, scope->size);

    Symbol *sym = (Symbol *)malloc(sizeof(Symbol));
    if (!sym) return false;
    sym->name = strdup(name);
    sym->type = type;
    sym->kind = kind;
    sym->param_types = NULL;
    sym->param_count = 0;
    sym->scope_level = scope->level;
    sym->is_initialized = true;
    sym->next = scope->buckets[idx];
    scope->buckets[idx] = sym;
    return true;
}

bool symtab_set_signature(Symbol *symbol, const DataType *param_types, size_t param_count) {
    if (!symbol || (param_count > 0 && !param_types)) return false;

    DataType *types = NULL;
    if (param_count > 0) {
        types = (DataType *)malloc(param_count * sizeof(DataType));
        if (!types) return false;
        memcpy(types, param_types, param_count * sizeof(DataType));
    }

    free(symbol->param_types);
    symbol->param_types = types;
    symbol->param_count = param_count;
    return true;
}

DataType str_to_datatype(const char *str) {
    if (!str) return TYPE_UNKNOWN;
    if (strcmp(str, "inteiro") == 0 || strcmp(str, "int") == 0) return TYPE_INTEIRO;
    if (strcmp(str, "real") == 0 || strcmp(str, "double") == 0) return TYPE_REAL;
    if (strcmp(str, "booleano") == 0 || strcmp(str, "bool") == 0) return TYPE_BOOLEANO;
    if (strcmp(str, "texto") == 0 || strcmp(str, "char*") == 0) return TYPE_TEXTO;
    if (strcmp(str, "void") == 0) return TYPE_VOID;
    return TYPE_UNKNOWN;
}

const char *datatype_to_str(DataType type) {
    switch (type) {
        case TYPE_INTEIRO:  return "int";
        case TYPE_REAL:     return "double";
        case TYPE_BOOLEANO: return "bool";
        case TYPE_TEXTO:    return "char*";
        case TYPE_VOID:     return "void";
        default:            return "unknown";
    }
}

bool is_type_compatible(DataType target, DataType src) {
    if (target == src) return true;
    // Promoção implícita de inteiro para real
    if (target == TYPE_REAL && src == TYPE_INTEIRO) return true;
    return false;
}
