%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

// === Tabla de símbolos ===
typedef enum { TIPO_NUMERO, TIPO_CADENA } TipoDato;

typedef struct {
    char* nombre;
    TipoDato tipo;
    union {
        float numero;
        char* cadena;
    } valor;
} simbolo;

simbolo tabla[100];
int tabla_index = 0;

// === Funciones definidas ===
typedef struct {
    char* nombre;
} funcion_definida;

funcion_definida funciones[50];
int funciones_index = 0;

// ---- utilidades de pila para control de ejecución ----
int exec_stack[100];
int exec_top = 0;

static inline void push_exec(int flag)  { exec_stack[exec_top++] = flag; }
static inline void pop_exec(void)       { if(exec_top>0) exec_top--; }
static inline int  current_exec(void)   { return exec_top==0 ? 1 : exec_stack[exec_top-1]; }

// ---- pila para saber si algún ramo del if ya ejecutó ----
int if_done_stack[100];
int if_done_top = 0;

static inline void push_if_done(int v)  { if_done_stack[if_done_top++] = v; }
static inline void pop_if_done(void)    { if(if_done_top>0) if_done_top--; }
static inline int  get_if_done(void)    { return if_done_top==0 ? 0 : if_done_stack[if_done_top-1]; }
static inline void set_if_done(int v)   { if_done_stack[if_done_top-1] = v; }

// ---- funciones de la mini‑máquina ----
float obtener_numero(char* nombre) {
    for (int i = 0; i < tabla_index; i++)
        if (strcmp(tabla[i].nombre, nombre) == 0) {
            if (tabla[i].tipo != TIPO_NUMERO) {
                printf("Error: '%s' no es un número\n", nombre);
                exit(1);
            }
            return tabla[i].valor.numero;
        }
    printf("Variable '%s' no definida\n", nombre);
    exit(1);
}

char* obtener_cadena(char* nombre) {
    for (int i = 0; i < tabla_index; i++)
        if (strcmp(tabla[i].nombre, nombre) == 0) {
            if (tabla[i].tipo != TIPO_CADENA) {
                printf("Error: '%s' no es una cadena\n", nombre);
                exit(1);
            }
            return tabla[i].valor.cadena;
        }
    printf("Variable '%s' no definida\n", nombre);
    exit(1);
}

void asignar_numero(char* nombre, float valor) {
    for (int i = 0; i < tabla_index; i++) {
        if (strcmp(tabla[i].nombre, nombre) == 0) {
            tabla[i].tipo = TIPO_NUMERO;
            tabla[i].valor.numero = valor;
            return;
        }
    }
    tabla[tabla_index++] = (simbolo){strdup(nombre), TIPO_NUMERO, {.numero = valor}};
}

void asignar_cadena(char* nombre, char* valor) {
    for (int i = 0; i < tabla_index; i++) {
        if (strcmp(tabla[i].nombre, nombre) == 0) {
            tabla[i].tipo = TIPO_CADENA;
            tabla[i].valor.cadena = strdup(valor);
            return;
        }
    }
    tabla[tabla_index++] = (simbolo){strdup(nombre), TIPO_CADENA, {.cadena = strdup(valor)}};
}

void guardar_funcion(char* nombre) {
    funciones[funciones_index++] = (funcion_definida){strdup(nombre)};
}

void ejecutar_funcion(char* nombre);
int yylex();
int yyerror(char* s);
int modo_interactivo = 1;
%}

%union {
    int ival;
    float fval;
    char* sval;
}

%token <ival> INT
%token <fval> REAL
%token <sval> ID
%token <sval> STRING

%token PRINT IF ELIF ELSE DEF
%token ASSIGN LPAREN RPAREN LBRACE RBRACE COLON
%token PLUS MINUS MUL DIV IGUAL DIFERENTE MAYORIGUAL MENORIGUAL MAYOR MENOR
%token NEWLINE

%type <fval> expr
%type <sval> cadena
%type <fval> condition

%start programa

%left PLUS MINUS
%left MUL DIV

%%

programa:
    programa linea
  | linea
;

linea:
    stmt opt_nl
  | opt_nl
;

opt_nl:
    NEWLINE
  | /* vacío */
;

stmt:
    ID ASSIGN expr           { if(current_exec()) asignar_numero($1, $3); }
  | ID ASSIGN cadena         { if(current_exec()) asignar_cadena($1, $3); }
  | PRINT LPAREN expr RPAREN { if(current_exec()) printf("=> %.2f\n", $3); }
  | PRINT LPAREN cadena RPAREN { if(current_exec()) printf("=> %s\n", $3); }
  | PRINT LPAREN ID RPAREN {
        if(current_exec()) {
            for (int i = 0; i < tabla_index; i++) {
                if (strcmp(tabla[i].nombre, $3) == 0) {
                    if (tabla[i].tipo == TIPO_NUMERO)
                        printf("=> %.2f\n", tabla[i].valor.numero);
                    else if (tabla[i].tipo == TIPO_CADENA)
                        printf("=> %s\n", tabla[i].valor.cadena);
                    break;
                }
            }
        }
    }
  | IF condition COLON {
        /* preparar contexto de este if */
        push_if_done(0); // aún no se ejecuta ningún ramo
        int condflag = current_exec() && $2;
        push_exec(condflag);
        if(condflag) set_if_done(1);
    } bloque {
        pop_exec();
    } opt_elif_else {
        pop_if_done();
    }
  | DEF ID LPAREN RPAREN COLON bloque {
        if(current_exec()) {
            printf("[Definiendo funcion: %s]\n", $2);
            guardar_funcion($2);
        }
    }
  | ID LPAREN RPAREN         { if(current_exec()) ejecutar_funcion($1); }
;

cadena:
    STRING { $$ = $1; }
;

opt_elif_else:
    ELIF condition COLON {
        int condflag = !get_if_done() && current_exec() && $2;
        push_exec(condflag);
        if(condflag) set_if_done(1);
    } bloque {
        pop_exec();
    } opt_elif_else
  | ELSE COLON {
        int condflag = !get_if_done() && current_exec();
        push_exec(condflag);
        set_if_done(1);
    } bloque {
        pop_exec();
    }
  | /* vacío */
;

bloque:
    LBRACE programa RBRACE
;

condition:
    expr MAYOR expr       { $$ = current_exec() ? ($1 > $3) : 0; }
  | expr MENOR expr       { $$ = current_exec() ? ($1 < $3) : 0; }
  | expr IGUAL expr       { $$ = current_exec() ? ($1 == $3) : 0; }
  | expr DIFERENTE expr   { $$ = current_exec() ? ($1 != $3) : 0; }
  | expr MAYORIGUAL expr  { $$ = current_exec() ? ($1 >= $3) : 0; }
  | expr MENORIGUAL expr  { $$ = current_exec() ? ($1 <= $3) : 0; }
;

expr:
    expr PLUS expr  { $$ = current_exec() ? ($1 + $3) : 0; }
  | expr MINUS expr { $$ = current_exec() ? ($1 - $3) : 0; }
  | expr MUL expr   { $$ = current_exec() ? ($1 * $3) : 0; }
  | expr DIV expr   { if(current_exec()) { if ($3 == 0) { printf("Division por cero\n"); exit(1); } $$ = $1 / $3; } else $$ = 0; }
  | INT             { $$ = current_exec() ? $1 : 0; }
  | REAL            { $$ = current_exec() ? $1 : 0; }
  | ID              { $$ = current_exec() ? obtener_numero($1) : 0; }
  | LPAREN expr RPAREN { $$ = $2; }
;

%%

void ejecutar_funcion(char* nombre) {
    for (int i = 0; i < funciones_index; i++) {
        if (strcmp(funciones[i].nombre, nombre) == 0) {
            printf("[Llamando funcion definida: %s]\n", nombre);
            return;
        }
    }
    printf("Funcion '%s' no definida\n", nombre);
}

int yyerror(char* s) {
    fprintf(stderr, "  Error sintactico: %s\n", s);
    int c;
    while ((c = getchar()) != '\n' && c != EOF);
    return 0;
}

int main() {
    setlocale(LC_ALL, "");
    push_exec(1); // modo ejecución activo por defecto
    printf(">>> Welcome to Vane Ds9 !\n");
    printf(">>> Ingrese su codigo (Ctrl+C para terminar):\n");
    while (!feof(stdin)) {
        if (modo_interactivo) printf(">>> ");
        yyparse();
    }
    return 0;
}
