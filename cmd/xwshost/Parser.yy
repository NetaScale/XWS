/*
 * These coded instructions, Stmts, and computer programs contain
 * software derived from the following specification:
 *
 * ECMA-262, 11th edition, June 2020: ECMAScript® 2020 Language Specification
 * https://262.ecma-international.org/11.0/
 * Draft ECMA-262, 13th edition, November 20, 2021: ECMAScript® 2022 Language
 * Specification
 * https://tc39.es/ecma262/
 */

%{
#include <cassert>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "Driver.hh"
#include "AST.hh"

#define YYDEBUG 1
#define UNIMPLEMENTED printf("Sorry, this is unimplemented\n"); YYERROR

static int assign_merge (YYSTYPE pattern, YYSTYPE regular);
%}

%code requires {
#include "Driver.hh"

class ExprNode;
class StmtNode;

#define ASI printf(" -> ADDING AUTO SC\n");

void
jserror(YYLTYPE * loc, Driver * driver, const char * msg);
void
print_highlight(const char * txt, int first_line, int first_col, int last_line,
    int last_col);

/*
#define YYLEX jslex(driver->scanner, &yylval, &yylloc)
#define YYERROR_CALL(message) yyerror(driver, yychar, yystate, &yylloc, message)

void
yyerror (Driver * driver, int yystate, YYLTYPE * loc, char *s);

*/
}

%code provides {
#define YY_DECL int \
	true_jslex(JSSTYPE *yylval, JSLTYPE *loc, yyscan_t yyscanner, \
	    Driver * driver)

YY_DECL;
int
jslex(JSSTYPE *yylval, JSLTYPE *loc, Driver * driver);
}

%define api.pure
%define api.prefix {js}
%define parse.trace
%define parse.error verbose
%param { Driver *driver }
%locations

%start Script

%token AS ASYNC AWAIT BREAK CASE CATCH CLASS CONST CONTINUE DEBUGGER DEFAULT
%token DELETE DO ELSE ENUM EVAL EXPORT EXTENDS FINALLY FOR FROM FUNCTION GET IF
%token IMPLEMENTS IMPORT IN INSTANCEOF INTERFACE LET NEW OF PACKAGE PRIVATE
%token PROTECETED PUBLIC RETURN SET STATIC SUPER SWITCH TARGET THIS THROW TRY
%token TYPEOF VAR VOID WHILE WITH YIELD

%token ELLIPSIS /* ... */
%token REGEXBODY REGEXFLAGS UNMATCHABLE
%token NULLTOK BOOLLIT STRINGLIT NUMLIT
%token IDENTIFIER
%token META

%token /* ~, ! */ PLUSPLUS MINUSMINUS /* ++, -- */
%token STARSTAR /* ** */
%token LSHIFT RSHIFT URSHIFT /*  <<, >>, >>> */
%token LTE GTE /* <=, >= */
%token EQ NEQ STRICTEQ STRICTNEQ  /* ==, !=, ===, !== */
%token LOGAND /* && */
%token LOGOR /* || */
%token QUESTIONQUESTION /* ?? */
/* ?, : */
%token /* = */ ASSIGNOP /* *=, /=, ... */
%token OPTIONAL /* ?. */

%precedence PLAIN_IF
%precedence ELSE

%union {
	Operator::Op opVal;
	char * str;

	ExprNode * exprNode;
	StmtNode * stmtNode;
}

%type <str> IDENTIFIER IdentifierNotReserved

%type <exprNode> IdentifierReference BindingIdentifier LabelIdentifier

%type <exprNode> PrimaryExpr PrimaryExpr_NoBrace
%type <exprNode> Literal

%type <exprNode> MemberExpr MemberExpr_NoBrace
%type <exprNode> SuperProperty SuperCall
%type <exprNode> NewExpr NewExpr_NoBrace
%type <exprNode> CallExpr CallExpr_NoBrace
%type <exprNode> OptionalExpr OptionalExpr_NoBrace
%type <exprNode> LeftHandSideExpr LeftHandSideExpr_NoBrace
%type <exprNode> UpdateExpr UpdateExpr_NoBrace
%type <exprNode> UnaryExpr UnaryExpr_NoBrace
%type <exprNode> ExponentialExpr ExponentialExpr_NoBrace

%type <opVal> MultiplicativeOperator
%type <exprNode> MultiplicativeExpr MultiplicativeExpr_NoBrace
%type <exprNode> AdditiveExpr AdditiveExpr_NoBrace
%type <exprNode> ShiftExpr ShiftExpr_NoBrace
%type <exprNode> RelationalExpr RelationalExpr_NoBrace
%type <exprNode> EqualityExpr EqualityExpr_NoBrace
%type <exprNode> BitwiseANDExpr BitwiseANDExpr_NoBrace
%type <exprNode> BitwiseORExpr BitwiseORExpr_NoBrace
%type <exprNode> BitwiseXORExpr BitwiseXORExpr_NoBrace
%type <exprNode> LogicalANDExpr LogicalANDExpr_NoBrace
%type <exprNode> LogicalORExpr LogicalORExpr_NoBrace
%type <exprNode> CoalesceExpr CoalesceExpr_NoBrace
%type <exprNode> CoalesceExprHead CoalesceExprHead_NoBrace
%type <exprNode> ShortCircuitExpr ShortCircuitExpr_NoBrace
%type <exprNode> ConditionalExpr ConditionalExpr_NoBrace
%type <exprNode> AssignmentExpr AssignmentExpr_NoBrace
%type <exprNode> Expr Expr_NoBrace

%type <stmtNode> Block BlockStmt VariableStmt EmptyStmt
%type <stmtNode> ExprStmt IfStmt BreakableStmt
%type <stmtNode> ContinueStmt BreakStmt ReturnStmt WithStmt
%type <stmtNode> LabelledStmt ThrowStmt TryStmt DebuggerStmt
%type <stmtNode> Stmt LabelledItem


%%

/* 11.8.5 Regular Expr Literals */
RegularExprLiteral:
	  '/' { printf("Matching Regex\n"); } REGEXBODY '/' REGEXFLAGS
	;

/*
 * 12 Exprs
 */

/* Lexical */

IdentifierNotReserved:
	  IDENTIFIER
	;

/* 12.1 Identifiers */

/* these ought to include yield/await in some instances */

/*
how a preprocessor grammar might look:
IdentifierReference(Yield, Await):
	  IdentifierNotReserved(?Yield, ?Await)
	| (~Yield) YIELD
	| (~Await) AWAIT
*/

IdentifierReference:
	  IdentifierNotReserved { $$ = new IdentifierNode(@1, $1); }
	;

BindingIdentifier:
	  IdentifierNotReserved { $$ = new IdentifierNode(@1, $1); }
	;

LabelIdentifier:
	  IdentifierNotReserved { $$ = new IdentifierNode(@1, $1); }
	;

/* 12.2 Primary Expr */

PrimaryExpr:
	  PrimaryExpr_NoBrace
	| ObjectLiteral
	| FunctionExpr
	/*| ClassExpr
	| GeneratorExpr
	| AsyncFunctionExpr*/
	| RegularExprLiteral
	| TemplateLiteral
	;

PrimaryExpr_NoBrace:
	  THIS
	| IdentifierReference
	| Literal
	| ArrayLiteral
	| CoverParenthesisedExprAndArrowParameterList
	;

CoverParenthesisedExprAndArrowParameterList:
	  '(' Expr ')'
	| '(' Expr ',' ')'
	| '(' ')'
	| '(' ELLIPSIS BindingIdentifier ')'
	| '(' ELLIPSIS BindingPattern ')'
	| '(' Expr ',' ELLIPSIS BindingIdentifier ')'
	| '(' Expr ',' ELLIPSIS BindingPattern ')'
	;

/* 12.2.4 Literals */
Literal:
	  NULLTOK
	| BOOLLIT
	| NUMLIT
	| STRINGLIT
	;

/* 12.2.5. Array Initializer */
ArrayLiteral:
	  '[' ']'
	| '[' Elision ']'
	| '[' ElementList ']'
	| '[' ElementList ',' Elision ']'
	| '[' ElementList ',' ']'
	;

ElementList:
	  Elision AssignmentExpr
	| AssignmentExpr
	| Elision SpreadElement
	| SpreadElement
	| ElementList ',' Elision AssignmentExpr
	| ElementList ',' AssignmentExpr
	| ElementList ',' Elision SpreadElement
	| ElementList ',' SpreadElement
	;

Elision:
	  ','
	| Elision ','
	;

SpreadElement:
	  ELLIPSIS AssignmentExpr
	;

/* 12.2.6 Object Initialiser */
ObjectLiteral:
	  '{' '}'
	| '{' PropertyDefinitionList '}'
	| '{' PropertyDefinitionList ',' '}'
	;

PropertyDefinitionList:
	  PropertyDefinition
	| PropertyDefinitionList ',' PropertyDefinition
	;

PropertyDefinition:
	  IdentifierReference
	| CoverInitializedName
	| PropertyName ':' AssignmentExpr
	/*| MethodDefinition*/
	| ELLIPSIS AssignmentExpr
	;

PropertyName:
	  LiteralPropertyName
	| ComputedPropertyName
	;

LiteralPropertyName:
	  IDENTIFIER
	| STRINGLIT
	| NUMLIT
	;

ComputedPropertyName:
	  '[' AssignmentExpr ']'
	;

CoverInitializedName:
	  IdentifierReference Initialiser
	;

Initialiser:
	  '=' AssignmentExpr
	;

TemplateLiteral:
	  UNMATCHABLE /* todo */
	;

/* 12.3 Left-Hand-Side Exprs */
MemberExpr:
	  PrimaryExpr
	| MemberExpr '[' Expr ']' {
		$$ = new AccessorNode($1, $3);
	}
	| MemberExpr '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	// | MemberExpr TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpr Arguments
	;

MemberExpr_NoBrace:
	  PrimaryExpr_NoBrace
	| MemberExpr_NoBrace '[' Expr ']' {
		$$ = new AccessorNode($1, $3);
	}
	| MemberExpr_NoBrace '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	//| MemberExpr_NoBrace TemplateLiteral
	| SuperProperty
	| MetaProperty
	| NEW MemberExpr Arguments
	;

SuperProperty:
	  SUPER '[' Expr ']' {
		$$ = new AccessorNode(new SuperNode(@1), $3);
	}
	| SUPER '.' IDENTIFIER {
		$$ = new AccessorNode(new SuperNode(@1), new
		    IdentifierNode(@3, $3));
	}
	;

MetaProperty:
	  NewTarget
	| ImportMeta
	;

NewTarget:
	  NEW '.' TARGET
	;

ImportMeta:
	  IMPORT '.' META
	;

NewExpr:
	  MemberExpr
	| NEW NewExpr {
		$$ = new NewExprNode(@1, $2);
	}
	;

NewExpr_NoBrace:
	  MemberExpr_NoBrace
	| NEW NewExpr {
		$$ = new NewExprNode(@1, $2);
	}
	;

CallExpr:
	  CallMemberExpr
	| SuperCall
	| CallExpr Arguments
	| CallExpr '[' Expr ']' {
		$$ = new AccessorNode($1, $3);
	}
	| CallExpr '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	| CallExpr TemplateLiteral {
		UNIMPLEMENTED;
	}
	;

CallExpr_NoBrace:
	  CallMemberExpr_NoBrace
	| SuperCall
	| CallExpr_NoBrace Arguments
	| CallExpr_NoBrace '[' Expr ']' {
		$$ = new AccessorNode($1, $3);
	}
	| CallExpr_NoBrace '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	| CallExpr_NoBrace TemplateLiteral {
		UNIMPLEMENTED;
	}
	;

CallMemberExpr:
	  MemberExpr Arguments
	;

CallMemberExpr_NoBrace:
	  MemberExpr_NoBrace Arguments
	;

SuperCall:
	  SUPER Arguments
	;

ImportCall:
	  IMPORT '(' AssignmentExpr ')'
	;

Arguments:
	  '(' ')'
	| '(' ArgumentList ')'
	;

ArgumentList:
	  AssignmentExpr
	| ELLIPSIS AssignmentExpr
	| ArgumentList ',' AssignmentExpr
	| ArgumentList ',' ELLIPSIS AssignmentExpr
	;

/* todo OptionalExpr */
OptionalExpr:
	  MemberExpr OptionalChain
	| CallExpr OptionalChain
	| OptionalExpr OptionalChain
	;

OptionalExpr_NoBrace:
	  MemberExpr_NoBrace OptionalChain
	| CallExpr_NoBrace OptionalChain
	| OptionalExpr_NoBrace OptionalChain
	;

OptionalChain:
	  OPTIONAL Arguments
	| OPTIONAL '[' Expr ']'
	| OPTIONAL IDENTIFIER
	| OPTIONAL TemplateLiteral
	| OptionalChain Arguments
	| OptionalChain '[' Expr ']'
	| OptionalChain '.' IDENTIFIER
	| OptionalChain TemplateLiteral
	;

LeftHandSideExpr:
	  NewExpr
	| CallExpr
	| OptionalExpr
	;

LeftHandSideExpr_NoBrace:
	  NewExpr_NoBrace
	| CallExpr_NoBrace
	| OptionalExpr_NoBrace
	;

/* 12.4 Update Exprs */
UpdateExpr:
	  LeftHandSideExpr
	| LeftHandSideExpr PLUSPLUS
	| LeftHandSideExpr MINUSMINUS
	| PLUSPLUS UnaryExpr
	| MINUSMINUS UnaryExpr
	;

UpdateExpr_NoBrace:
	  LeftHandSideExpr_NoBrace
	| LeftHandSideExpr_NoBrace PLUSPLUS
	| LeftHandSideExpr_NoBrace MINUSMINUS
	| PLUSPLUS UnaryExpr
	| MINUSMINUS UnaryExpr
	;

/* 12.5 Unary Operators */
UnaryExpr:
	  UpdateExpr
	| DELETE UnaryExpr
	| VOID UnaryExpr
	| TYPEOF UnaryExpr
	| '+' UnaryExpr
	| '-' UnaryExpr
	| '~' UnaryExpr
	| '!' UnaryExpr
	/* | AwaitExpr */
	;

UnaryExpr_NoBrace:
	  UpdateExpr_NoBrace
	| DELETE UnaryExpr
	| VOID UnaryExpr
	| TYPEOF UnaryExpr
	| '+' UnaryExpr
	| '-' UnaryExpr
	| '~' UnaryExpr
	| '!' UnaryExpr
	/* | AwaitExpr */
	;

/* 12.6 Exponential Operator */
ExponentialExpr:
	  UnaryExpr
	| UpdateExpr STARSTAR ExponentialExpr {
		$$ = new BinOpNode($1, $3, Operator::kExp);
	}
	;

ExponentialExpr_NoBrace:
	  UnaryExpr_NoBrace
	| UpdateExpr_NoBrace STARSTAR ExponentialExpr {
		$$ = new BinOpNode($1, $3, Operator::kExp);
	}
	;

/* 12.7 Multiplicative Operators */
MultiplicativeExpr:
	  ExponentialExpr
	| MultiplicativeExpr MultiplicativeOperator
	  ExponentialExpr {
		$$ = new BinOpNode($1, $3, $2);
	}
	;

MultiplicativeExpr_NoBrace:
	  ExponentialExpr_NoBrace
	| MultiplicativeExpr_NoBrace MultiplicativeOperator
	  ExponentialExpr {
		$$ = new BinOpNode($1, $3, $2);
	}
	;

MultiplicativeOperator:
	  '*' { $$ = Operator::kMul; }
	| '/' { $$ = Operator::kDiv; }
	| '%' { $$ = Operator::kMod; }
	;

/* 12.8 Additive Operators */
AdditiveExpr:
	  MultiplicativeExpr
	| AdditiveExpr '+' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, Operator::kAdd);
	}
	| AdditiveExpr '-' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, Operator::kSub);
	}
	;

AdditiveExpr_NoBrace:
	  MultiplicativeExpr_NoBrace
	| AdditiveExpr_NoBrace '+' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, Operator::kAdd);
	}
	| AdditiveExpr_NoBrace '-' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, Operator::kSub);
	}
	;

/* 12.9 Bitwise Shift Operators */
ShiftExpr:
	  AdditiveExpr
	| ShiftExpr LSHIFT AdditiveExpr{
		$$ = new BinOpNode($1, $3, Operator::kLShift);
	}
	| ShiftExpr RSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, Operator::kRShift);
	}
	| ShiftExpr URSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, Operator::kURShift);
	}
	;

ShiftExpr_NoBrace:
	  AdditiveExpr_NoBrace
	| ShiftExpr_NoBrace LSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, Operator::kLShift);
	}
	| ShiftExpr_NoBrace RSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, Operator::kRShift);
	}
	| ShiftExpr_NoBrace URSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, Operator::kURShift);
	}
	;

/* 12.10 Relational Operators */
RelationalExpr:
	  ShiftExpr
	| RelationalExpr '<' ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kLessThan);
	}
	| RelationalExpr '>' ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThan);
	}
	| RelationalExpr LTE ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kLessThanOrEq);
	}
	| RelationalExpr GTE ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThanOrEq);
	}
	| RelationalExpr INSTANCEOF ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kInstanceOf);
	}
	| RelationalExpr IN ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kAmong);
	}
	;

RelationalExpr_NoBrace:
	  ShiftExpr_NoBrace
	| RelationalExpr_NoBrace '<' ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kLessThan);
	}
	| RelationalExpr_NoBrace '>' ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThan);
	}
	| RelationalExpr_NoBrace LTE ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kLessThanOrEq);
	}
	| RelationalExpr_NoBrace GTE ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kGreaterThanOrEq);
	}
	| RelationalExpr_NoBrace INSTANCEOF ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kInstanceOf);
	}
	| RelationalExpr_NoBrace IN ShiftExpr {
		$$ = new BinOpNode($1, $3, Operator::kAmong);
	}
	;

/* 12.11 Equality Operators */
EqualityExpr:
	  RelationalExpr
	| EqualityExpr EQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kEquals);
	}
	| EqualityExpr NEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kNotEquals);
	}
	| EqualityExpr STRICTEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kStrictEquals);
	}
	| EqualityExpr STRICTNEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kStrictNotEquals);
	}
	;

EqualityExpr_NoBrace:
	  RelationalExpr_NoBrace
	| EqualityExpr_NoBrace EQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kEquals);
	}
	| EqualityExpr_NoBrace NEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kNotEquals);
	}
	| EqualityExpr_NoBrace STRICTEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kStrictEquals);
	}
	| EqualityExpr_NoBrace STRICTNEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, Operator::kStrictNotEquals);
	}
	;

/* 12.12 Binary Bitwise Operators */
BitwiseANDExpr:
	  EqualityExpr
	| BitwiseANDExpr '&' EqualityExpr {
		$$ = new BinOpNode($1, $3, Operator::kBitAnd);
	}
	;

BitwiseANDExpr_NoBrace:
	  EqualityExpr_NoBrace
	| BitwiseANDExpr_NoBrace '&' EqualityExpr {
		$$ = new BinOpNode($1, $3, Operator::kBitAnd);
	}
	;

BitwiseXORExpr:
	  BitwiseANDExpr
	| BitwiseXORExpr '^' BitwiseANDExpr {
		$$ = new BinOpNode($1, $3, Operator::kBitXor);
	}
	;

BitwiseXORExpr_NoBrace:
	  BitwiseANDExpr_NoBrace
	| BitwiseXORExpr_NoBrace '^' BitwiseANDExpr {
		$$ = new BinOpNode($1, $3, Operator::kBitXor);
	}
	;

BitwiseORExpr:
	  BitwiseXORExpr
	| BitwiseORExpr '|' BitwiseXORExpr {
		$$ = new BinOpNode($1, $3, Operator::kBitOr);
	}
	;

BitwiseORExpr_NoBrace:
	  BitwiseXORExpr_NoBrace
	| BitwiseORExpr_NoBrace '|' BitwiseXORExpr {
		$$ = new BinOpNode($1, $3, Operator::kBitOr);
	}
	;

/* 12.13 Binary Logical Operators */
LogicalANDExpr:
	  BitwiseORExpr
	| LogicalANDExpr LOGAND BitwiseORExpr {
		$$ = new BinOpNode($1, $3, Operator::kAnd);
	}
	;

LogicalANDExpr_NoBrace:
	  BitwiseORExpr_NoBrace
	| LogicalANDExpr_NoBrace LOGAND BitwiseORExpr {
		$$ = new BinOpNode($1, $3, Operator::kAnd);
	}
	;

LogicalORExpr:
	  LogicalANDExpr
	| LogicalORExpr LOGOR LogicalANDExpr {
		$$ = new BinOpNode($1, $3, Operator::kOr);
	}
	;

LogicalORExpr_NoBrace:
	  LogicalANDExpr_NoBrace
	| LogicalORExpr_NoBrace LOGOR LogicalANDExpr {
		$$ = new BinOpNode($1, $3, Operator::kOr);
	}
	;

CoalesceExpr:
	  CoalesceExprHead QUESTIONQUESTION BitwiseORExpr {
		$$ = new BinOpNode($1, $3, Operator::kCoalesce);
	}
	;

CoalesceExprHead:
	  CoalesceExpr
	| BitwiseORExpr
	;

CoalesceExpr_NoBrace:
	  CoalesceExprHead_NoBrace QUESTIONQUESTION BitwiseORExpr {
		$$ = new BinOpNode($1, $3, Operator::kCoalesce);
	}
	;

CoalesceExprHead_NoBrace:
	  CoalesceExpr_NoBrace
	| BitwiseORExpr_NoBrace
	;

ShortCircuitExpr:
	  LogicalORExpr
	| CoalesceExpr
	;

ShortCircuitExpr_NoBrace:
	  LogicalORExpr_NoBrace
	| CoalesceExpr_NoBrace
	;

/* 12.14 Conditional Operator */
ConditionalExpr:
	  ShortCircuitExpr
	| ShortCircuitExpr '?' AssignmentExpr ':'
	    AssignmentExpr
	;

ConditionalExpr_NoBrace:
	  ShortCircuitExpr_NoBrace
	| ShortCircuitExpr_NoBrace '?' AssignmentExpr ':'
	    AssignmentExpr
	;

/* 12.15 Assignment Operator */
AssignmentExpr:
	  ConditionalExpr
	// | ObjectAssignmentPattern '=' AssignmentExpr
	// | ArrayAssignmentPattern '=' AssignmentExpr
	/* | YieldExpr
	| ArrowFunction
	| AsyncArrowFunction */
	| LeftHandSideExpr '=' AssignmentExpr
	| LeftHandSideExpr ASSIGNOP AssignmentExpr
	;

AssignmentExpr_NoBrace:
	  ConditionalExpr_NoBrace
	// | ArrayAssignmentPattern '=' AssignmentExpr
	/* | YieldExpr
	| ArrowFunction
	| AsyncArrowFunction */
	| LeftHandSideExpr_NoBrace '=' AssignmentExpr
	| LeftHandSideExpr_NoBrace ASSIGNOP AssignmentExpr
	;

/* 12.15.5 Destructuring Assignment */
/*
 * This grammar is 'covered' by the ObjectLiteral and ArrayLiteral nonterminals.
 * It is therefore not actually parsed. This is why it is commented out.
 */

/*
ObjectAssignmentPattern:
	  '{' '}'
	| '{' AssignmentRestProperty '}'
	| '{' AssignmentPropertyList '}'
	| '{' AssignmentPropertyList ',' '}'
	| '{' AssignmentPropertyList ',' AssignmentRestProperty '}'
	;

ArrayAssignmentPattern:
	  '[' ']'
	| '[' AssignmentRestElement ']'
	| '[' Elision AssignmentRestElement ']'
	| '[' AssignmentElementList ']'
	| '[' AssignmentElementList ',' ']'
	| '[' AssignmentElementList ',' AssignmentRestElement ']'
	| '[' AssignmentElementList ',' Elision ']'
	| '[' AssignmentElementList ',' Elision ',' AssignmentRestElement ']'
	;

AssignmentRestProperty:
	  ELLIPSIS DestructuringAssignmentTarget
	  ;

AssignmentPropertyList:
	  AssignmentProperty
	| AssignmentPropertyList ',' AssignmentProperty
	;

AssignmentElementList:
	  AssignmentElisionElement
	| AssignmentElementList ',' AssignmentElisionElement
	;

AssignmentElisionElement:
	  AssignmentElement
	| Elision AssignmentElement
	;

AssignmentProperty:
	  IdentifierReference Initialiser
	| PropertyName ':' AssignmentElement
	;

AssignmentElement:
	  DestructuringAssignmentTarget Initialiser
	;

AssignmentRestElement:
	  ELLIPSIS DestructuringAssignmentTarget
	;

DestructuringAssignmentTarget:
	  LeftHandSideExpr
	;
*/

/* 12.16 ',' Operator */
Expr:
	  AssignmentExpr
	| Expr ',' AssignmentExpr
	;

Expr_NoBrace:
	  AssignmentExpr_NoBrace
	| Expr_NoBrace ',' AssignmentExpr
	;

Stmt:
	  BlockStmt
	| VariableStmt
	| EmptyStmt
	| ExprStmt
	| IfStmt
	| BreakableStmt
	| ContinueStmt
	| BreakStmt
	/* +Return */ | ReturnStmt
	| WithStmt
	| LabelledStmt
	| ThrowStmt
	| TryStmt
	| DebuggerStmt
	;

Declaration:
	  HoistableDeclaration
	//| ClassDeclaration
	| LexicalDeclaration
	//| ExportDeclaration
	;

HoistableDeclaration:
	  FunctionDeclaration
	//| GeneratorDeclaration
	//| AsyncFunctionDeclaration
	//| AsyncGeneratorDeclaration
	;

BreakableStmt:
	  IterationStmt
	//| SwitchStmt
	;


BlockStmt:
	  Block
	;

Block:
	  '{' StmtList '}'
	| '{' '}'
	;

StmtList:
	  StmtListItem
	| StmtList StmtListItem
	;

StmtListItem:
	  Stmt { printf("Stmt parsed\n"); }
	| Declaration
	;

LexicalDeclaration:
	  LetOrConst BindingList ';'
	| LetOrConst BindingList error { ASI; }
	;

LetOrConst:
	  LET
	| CONST
	;

BindingList:
	  LexicalBinding
	| BindingList ',' LexicalBinding
	;

LexicalBinding:
	  BindingIdentifier Initialiser
	| BindingPattern Initialiser
	;

VariableStmt:
	  VAR VariableDeclarationList ';'
	| VAR VariableDeclarationList error { ASI; }
	;

VariableDeclarationList:
	  VariableDeclaration
	| VariableDeclarationList ',' VariableDeclaration
	;

VariableDeclaration:
	  BindingIdentifier
	| BindingIdentifier Initialiser
	;

/* 13.3.3 Destructuring Binding Patterns */
BindingPattern:
	  ObjectBindingPattern
	| ArrayBindingPattern
	;

ObjectBindingPattern:
	  '{' '}'
	| '{' BindingPropertyList '}'
	| '{' BindingPropertyList ',' '}'
	| '{' BindingPropertyList ',' BindingRestProperty '}'
	;

ArrayBindingPattern:
	  '[' ']'
	| '[' BindingRestElement ']'
	| '[' Elision ']'
	| '[' Elision BindingRestElement ']'
	| '[' BindingElementList ']'
	| '[' BindingElementList ',' BindingRestElement ']'
	| '[' BindingElementList ',' Elision ']'
	| '[' BindingElementList ',' Elision BindingRestElement ']'
	;

BindingRestProperty:
	  ELLIPSIS BindingIdentifier
	;

BindingPropertyList:
	 BindingProperty
	| BindingPropertyList ',' BindingProperty
	;

BindingElementList:
	  BindingElisionElement
	| BindingElementList ',' BindingElisionElement
	;

BindingElisionElement:
	  BindingElement
	| Elision BindingElement
	;

BindingProperty:
	  SingleNameBinding
	| PropertyName ':' BindingElement
	;

BindingElement:
	  SingleNameBinding
	| BindingPattern
	| BindingPattern Initialiser
	;

SingleNameBinding:
	  BindingIdentifier
	| BindingIdentifier Initialiser
	;

BindingRestElement:
	  ELLIPSIS BindingIdentifier
	| ELLIPSIS BindingPattern
	;

EmptyStmt:
	  ';'
	;

/*
 * "An ExprStmt cannot start with a U+007B (LEFT CURLY BRACKET)
 * because that might make it ambiguous with a Block"
 * We therefore need a "no left curly bracket start" alternative of Expr.
 */
ExprStmt:
	  Expr_NoBrace ';'
	| Expr_NoBrace error { ASI; }
	;

IfStmt:
	  IF '(' Expr ')' Stmt ELSE Stmt
	| IF '(' Expr ')' Stmt %prec PLAIN_IF
	;

IterationStmt:
	  DoWhileStmt
	| WhileStmt
	| ForStmt
	//| ForInOfStmt
	;

DoWhileStmt: /* [Yield, Await, Return] */
	  DO Stmt /* [?Yield, ?Await, ?Return] */ WHILE '('
	  Expr /* [+In, ?Yield, ?Await] */ ')' ';'
	;

WhileStmt: /* [Yield, Await, Return] */
	  WHILE '(' Expr /* [+In, ?Yield, ?Await] */ ')'
	  Stmt /* [?Yield, ?Await, ?Return] */
	;

/*
ForStmt[Yield, Await, Return] :
	for ( [lookahead ≠ let [] Expr[~In, ?Yield, ?Await]opt ;
	    Expr[+In, ?Yield, ?Await]opt ;
	    Expr[+In, ?Yield, ?Await]opt )
	    Stmt[?Yield, ?Await, ?Return]
	for ( var VariableDeclarationList[~In, ?Yield, ?Await] ;
	    Expr[+In, ?Yield, ?Await]opt ;
	    Expr[+In, ?Yield, ?Await]opt )
	    Stmt[?Yield, ?Await, ?Return]
	for ( LexicalDeclaration[~In, ?Yield, ?Await]
	    Expr[+In, ?Yield, ?Await]opt ;
	    Expr[+In, ?Yield, ?Await]opt )
	    Stmt[?Yield, ?Await, ?Return]
*/

ForStmt: /* [Yield, Await, Return] */
	  FOR '(' ExprOpt ';' ExprOpt ';' ExprOpt ')'
	  Stmt
	| FOR '(' VAR VariableDeclarationList ';' ExprOpt ';'
	  ExprOpt ')' Stmt
	| FOR '(' LexicalDeclaration ExprOpt ';' ExprOpt ')'
	  Stmt
	;

ExprOpt:
	  Expr
	| %empty
	;

/*
ForInOfStmt[Yield, Await, Return] :
	for ( [lookahead ≠ let [] LeftHandSideExpr[?Yield, ?Await] in
	    Expr[+In, ?Yield, ?Await] ) Stmt[?Yield, ?Await, ?Return]
	for ( var ForBinding[?Yield, ?Await] in Expr[+In, ?Yield, ?Await]
	    ) Stmt[?Yield, ?Await, ?Return]
	for ( ForDeclaration[?Yield, ?Await] in Expr[+In, ?Yield, ?Await]
	    ) Stmt[?Yield, ?Await, ?Return]
	for ( [lookahead ∉ { let, async of }]
	    LeftHandSideExpr[?Yield, ?Await] of
	    AssignmentExpr[+In, ?Yield, ?Await] )
	    Stmt[?Yield, ?Await, ?Return]
	for ( var ForBinding[?Yield, ?Await] of
	    AssignmentExpr[+In, ?Yield, ?Await]
	    ) Stmt[?Yield, ?Await, ?Return]
	for ( ForDeclaration[?Yield, ?Await] of
	    AssignmentExpr[+In, ?Yield, ?Await] )
	    Stmt[?Yield, ?Await, ?Return]
	[+Await] for await ( [lookahead ≠ let]
	    LeftHandSideExpr[?Yield, ?Await] of
	    AssignmentExpr[+In, ?Yield, ?Await] )
	    Stmt[?Yield, ?Await, ?Return]
	[+Await] for await ( var ForBinding[?Yield, ?Await] of
	    AssignmentExpr[+In, ?Yield, ?Await] )
	    Stmt[?Yield, ?Await, ?Return]
	[+Await] for await ( ForDeclaration[?Yield, ?Await] of
	    AssignmentExpr[+In, ?Yield, ?Await] )
	    Stmt[?Yield, ?Await, ?Return]
*/

/*
ForDeclaration[Yield, Await] :
	LetOrConst ForBinding[?Yield, ?Await]

ForBinding[Yield, Await] :
	BindingIdentifier[?Yield, ?Await]
	BindingPattern[?Yield, ?Await]
*/

ContinueStmt:
	  CONTINUE ';'
	| CONTINUE /* [no LineTerminator here] */ LabelIdentifier ';'
	;

BreakStmt:
	  BREAK ';'
	| BREAK /* [no LineTerminator here] */ LabelIdentifier ';'
	;

ReturnStmt:
	  RETURN ';'
	| RETURN /* [no LineTerminator here] */ Expr ';'
	;

WithStmt:
	  WITH '(' Expr ')' Stmt
	;

/*
SwitchStmt[Yield, Await, Return] :
switch ( Expr[+In, ?Yield, ?Await] ) CaseBlock[?Yield, ?Await, ?Return]

CaseBlock[Yield, Await, Return] :
{ CaseClauses[?Yield, ?Await, ?Return]opt }
{ CaseClauses[?Yield, ?Await, ?Return]opt DefaultClause[?Yield, ?Await, ?Return] CaseClauses[?Yield, ?Await, ?Return]opt }

CaseClauses[Yield, Await, Return] :
CaseClause[?Yield, ?Await, ?Return]
CaseClauses[?Yield, ?Await, ?Return] CaseClause[?Yield, ?Await, ?Return]

CaseClause[Yield, Await, Return] :
case Expr[+In, ?Yield, ?Await] : StmtList[?Yield, ?Await, ?Return]opt

DefaultClause[Yield, Await, Return] :
default : StmtList[?Yield, ?Await, ?Return]opt
*/

LabelledStmt:
	LabelIdentifier ':' LabelledItem {
		//$$ = new LabelNode($1, $3);
		UNIMPLEMENTED;
	}
	;

LabelledItem:
	  Stmt
	//| FunctionDeclaration
	;

ThrowStmt:
	  THROW /* [no LineTerminator here] */ Expr ';'
	;

TryStmt:
	  TRY Block Catch
	| TRY Block Finally
	| TRY Block Catch Finally
	;

Catch:
	  CATCH '(' CatchParameter ')' Block
	| CATCH Block
	;

Finally:
	  FINALLY Block
	;

CatchParameter:
	  BindingIdentifier
	| BindingPattern
	;

DebuggerStmt:
	  DEBUGGER ';'
	;

/* 15 Functions and Classes */

/* 15.1 Parameter Lists */

UniqueFormalParameters:
	  FormalParameters
	;

FormalParameters:
	  %empty
	| FunctionRestParameter
	| FormalParameterList
	| FormalParameterList ','
	| FormalParameterList ',' FunctionRestParameter
	;


FormalParameterList:
	  FormalParameter
	| FormalParameterList ',' FormalParameter
	;

FunctionRestParameter:
	BindingRestElement
	;

FormalParameter:
	BindingElement
	;

/* 15.2 Function Definitions */

FunctionDeclaration:
	  FUNCTION BindingIdentifier '(' FormalParameters ')' '{' FunctionBody
	  '}'
	| FUNCTION '(' FormalParameters ')' '{' FunctionBody '}'
	;

FunctionExpr:
	  FUNCTION BindingIdentifier '(' FormalParameters ')' '{' FunctionBody
	  '}'
	| FUNCTION '(' FormalParameters ')' '{' FunctionBody '}'
	;

FunctionBody:
	FunctionStmtList
	;

FunctionStmtList:
	  StmtList
	| %empty
	;


Script:
	  ScriptBody
	| %empty
	;

ScriptBody:
	  StmtList
	;


%%

#if 0
void
yyerror(Driver *driver, int yychar, int yystate, YYLTYPE *loc, char *text)
{
	register int yyn, count = 0;
	if (((yyn = yysindex[yystate]) != 0) && (yyn < YYTABLESIZE)) {
		printf("%d:%d: %s\n", loc->first_line + 1, loc->first_column,
		    text);
		print_highlight(driver->txt, loc->first_line, loc->first_column,
		    loc->last_line, loc->last_column);
		printf("got %s, but expected one of:\n\t", yyname[yychar]);
		for (int i = ((yyn > 0) ? yyn : 0); i <= YYTABLESIZE; ++i) {
			int tok = i - yyn;
			/*printf("i %d, tok %d, yycheck[i] %d, %s\n",
				   i, tok, yycheck[i], yyname[tok]);*/
			if ((yycheck[i] == tok) && (tok != YYERRCODE))
				printf("%s%s", count++ > 0 ? ", " : "",
				    yyname[tok]);
		}
	}
	printf("\n");
}
#endif

void jserror(JSLTYPE * loc, Driver * driver, const char * msg)
{
	printf("%d:%d: %s\n", loc->first_line + 1, loc->first_column,
	    msg);
	print_highlight(driver->txt, loc->first_line, loc->first_column,
	    loc->last_line, loc->last_column);
}

void print_highlight(const char * txt, int first_line, int first_col, int last_line, int last_col)
{
	int i;
	char fmt[9] = "";
	const char* lineend = txt;

	/* advance to the relevant line number */
	for (i = first_line ; i > 0; i--) {
		/* advance to next line */
		txt = strchr(txt, '\n');
		assert (txt != NULL);
		txt++;
		assert(*txt != '\0');
	}

	/* limit printing to not include line-terminal \n if present */
	lineend = strchr(txt, '\n');
	if (lineend != NULL)
		sprintf(fmt, "%%.%ds\n", lineend - txt);
	else
		sprintf(fmt, "%%s\n");

	printf(fmt, txt);
	for (i = 0; i < first_col; i++)
		putchar(' ');
	for (i; i < last_col; i++)
		putchar('^');

	printf("\n");
}

int
jslex(JSSTYPE *yylval, JSLTYPE *loc, Driver * driver)
{
	return true_jslex(yylval, loc, driver->scanner, driver);
}