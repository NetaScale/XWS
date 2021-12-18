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
#define UNIMPLEMENTED printf("Internal compiler error: %s:%d: " \
    "Sorry, this is unimplemented\n", __FILE__, __LINE__); YYERROR

static int assign_merge (YYSTYPE pattern, YYSTYPE regular);
%}

%code requires {
#include "Driver.hh"

class ExprNode;
class StmtNode;
class CoverParenthesisedExprAndArrowParameterListNode;
class DestructuringNode;
class SingleDeclNode;
class DeclNode;

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
%token PROTECTED PUBLIC RETURN SET STATIC SUPER SWITCH TARGET THIS THROW TRY
%token TYPEOF VAR VOID WHILE WITH YIELD FARROW

%token AMONG /* not in ES spec. 'in' for expressions. */

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
	int intVal;
	BinOp::Op opVal;
	char *str;

	ExprNode *exprNode;
	StmtNode *stmtNode;
	CoverParenthesisedExprAndArrowParameterListNode
	    *coverParenthesisedExprAndArrowParameterListNode;
	DestructuringNode *destructuringNode;
	SingleDeclNode *singleDeclNode;
	DeclNode * declNode;
	IdentifierNode *identNode;

	std::vector<DestructuringNode*> *destructuringNodeVec;
	std::vector<StmtNode*> *stmtNodeVec;
	std::vector<ExprNode*> *exprNodeVec;
	std::vector<SingleDeclNode*> *singleDeclNodeVec;
}

%type <str> IDENTIFIER IdentifierNotReserved

%type <exprNode> NULLTOK BOOLLIT STRINGLIT NUMLIT

%type <identNode> IdentifierReference BindingIdentifier LabelIdentifier
%type <str> BindingIdentifier_Str

%type <exprNode> Initialiser

%type <exprNode> ObjectLiteral RegularExprLiteral TemplateLiteral ArrayLiteral

%type <exprNode> PrimaryExpr PrimaryExpr_NoBrace
%type <exprNode> Literal

%type <coverParenthesisedExprAndArrowParameterListNode>
    CoverParenthesisedExprAndArrowParameterList

%type <exprNode> MemberExpr MemberExpr_NoBrace
%type <exprNode> SuperProperty SuperCall
%type <exprNode> NewExpr NewExpr_NoBrace
%type <exprNode> CallExpr CallExpr_NoBrace CallMemberExpr CallMemberExpr_NoBrace
%type <exprNode> OptionalExpr OptionalExpr_NoBrace
%type <exprNode> LeftHandSideExpr LeftHandSideExpr_NoBrace
%type <exprNode> UpdateExpr UpdateExpr_NoBrace
%type <exprNode> UnaryExpr UnaryExpr_NoBrace UnaryExpr_Common
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
%type <exprNode> Expr Expr_NoBrace ExprOpt

%type <stmtNode> Block BlockStmt VariableStmt EmptyStmt
%type <stmtNode> ExprStmt IfStmt BreakableStmt
%type <stmtNode> ContinueStmt BreakStmt ReturnStmt WithStmt
%type <stmtNode> LabelledStmt ThrowStmt TryStmt DebuggerStmt
%type <stmtNode> IterationStmt DoWhileStmt WhileStmt ForStmt
%type <stmtNode> Stmt LabelledItem StmtListItem

%type <destructuringNode> BindingElement BindingRestElement SingleNameBinding

%type <destructuringNodeVec> UniqueFormalParameters FormalParameters
%type <destructuringNodeVec> FormalParameterList
%type <destructuringNode> FunctionRestParameter FormalParameter

%type <exprNodeVec> Arguments ArgumentList

%type <stmtNodeVec> StmtList ScriptBody

%type <exprNode> FunctionExpr
%type <stmtNodeVec> FunctionBody FunctionStmtList

%type <intVal> LetOrConst
%type <singleDeclNode> LexicalBinding
%type <singleDeclNodeVec> BindingList
%type <declNode> LexicalDeclaration

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

BindingIdentifier_Str:
	  IdentifierNotReserved
	;

/* 12.2 Primary Expression */

PrimaryExpr:
	  PrimaryExpr_NoBrace
	| ObjectLiteral {
		UNIMPLEMENTED;
	}
	| FunctionExpr
	/*| ClassExpr
	| GeneratorExpr
	| AsyncFunctionExpr*/
	| RegularExprLiteral
	| TemplateLiteral
	;

PrimaryExpr_NoBrace:
	  THIS {
		  $$ = new ThisNode(@1);
	}
	| IdentifierReference
	| Literal
	| ArrayLiteral {
		UNIMPLEMENTED;
	}
	| CoverParenthesisedExprAndArrowParameterList {
		ExprNode * expr = $1->toExpr();

		if (!expr)
		{
			yyerror(&@1, driver, "Syntax error: "
			"arrow function parameters found where parenthesised "
			"expression expected");
			YYERROR;
		}

		$$ = expr;
	}
	;

CoverParenthesisedExprAndArrowParameterList:
	  '(' Expr ')' {
		$$ = new CoverParenthesisedExprAndArrowParameterListNode(
		    loc_from(@1, @3), $2);
	}
	| '(' Expr ',' ')' {
		$$ = new CoverParenthesisedExprAndArrowParameterListNode(
		    loc_from(@1, @4), $2);
	}
	| '(' ')'  {
		$$ = new CoverParenthesisedExprAndArrowParameterListNode(
		    loc_from(@1, @2), NULL);
	}
	| '(' ELLIPSIS BindingIdentifier ')' {
		$$ = new CoverParenthesisedExprAndArrowParameterListNode(
		    loc_from(@1, @4), NULL, $3);
	}
	| '(' ELLIPSIS BindingPattern ')' {
		UNIMPLEMENTED;
	}
	| '(' Expr ',' ELLIPSIS BindingIdentifier ')' {
		$$ = new CoverParenthesisedExprAndArrowParameterListNode(
		    loc_from(@1, @5), $2, $5);
	}
	| '(' Expr ',' ELLIPSIS BindingPattern ')' {
		UNIMPLEMENTED;
	}
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
	  '=' AssignmentExpr {
		$$ = $2;
	}
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
	| MemberExpr TemplateLiteral {
		UNIMPLEMENTED;
	}
	| SuperProperty
	| MetaProperty {
		UNIMPLEMENTED;
	}
	| NEW MemberExpr Arguments {
		UNIMPLEMENTED;
	}
	;

MemberExpr_NoBrace:
	  PrimaryExpr_NoBrace
	| MemberExpr_NoBrace '[' Expr ']' {
		$$ = new AccessorNode($1, $3);
	}
	| MemberExpr_NoBrace '.' IDENTIFIER {
		$$ = new AccessorNode($1, new IdentifierNode(@3, $3));
	}
	| MemberExpr_NoBrace TemplateLiteral {
		UNIMPLEMENTED;
	}
	| SuperProperty {
		UNIMPLEMENTED;
	}
	| MetaProperty {
		UNIMPLEMENTED;
	}
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
	| CallExpr Arguments {
		$$ = new FunCallNode($1, $2);
	}
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
	| CallExpr_NoBrace Arguments {
		$$ = new FunCallNode($1, $2);
	}
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
	  MemberExpr Arguments {
		$$ = new FunCallNode($1, $2);
	}
	;

CallMemberExpr_NoBrace:
	  MemberExpr_NoBrace Arguments {
		$$ = new FunCallNode($1, $2);
	}
	;

SuperCall:
	  SUPER Arguments {
		UNIMPLEMENTED;
	}
	;

ImportCall:
	  IMPORT '(' AssignmentExpr ')' {
		UNIMPLEMENTED;
	}
	;

Arguments:
	  '(' ')' {
		$$ = NULL;
	}
	| '(' ArgumentList ')' {
		$$ = $2;
	}
	;

ArgumentList:
	  AssignmentExpr {
		$$ = new std::vector<ExprNode*>;
		$$->push_back($1);
	}
	| ELLIPSIS AssignmentExpr {
		$$ = new std::vector<ExprNode*>;
		$$->push_back(new SpreadNode($2));
	}
	| ArgumentList ',' AssignmentExpr {
		$$ = $1;
		$$->push_back($3);
	}
	| ArgumentList ',' ELLIPSIS AssignmentExpr {
		$$ = $1;
		$$->push_back(new SpreadNode($4));
	}
	;

/* todo OptionalExpr */
OptionalExpr:
	  MemberExpr OptionalChain {
		UNIMPLEMENTED;
	}
	| CallExpr OptionalChain {
		UNIMPLEMENTED;
	}
	| OptionalExpr OptionalChain {
		UNIMPLEMENTED;
	}
	;

OptionalExpr_NoBrace:
	  MemberExpr_NoBrace OptionalChain {
		UNIMPLEMENTED;
	}
	| CallExpr_NoBrace OptionalChain {
		UNIMPLEMENTED;
	}
	| OptionalExpr_NoBrace OptionalChain {
		UNIMPLEMENTED;
	}
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
	| LeftHandSideExpr PLUSPLUS {
		$$ = new UnaryOpNode($1, @2, UnaryOp::kPostInc, true);
	}
	| LeftHandSideExpr MINUSMINUS {
		$$ = new UnaryOpNode($1, @2, UnaryOp::kPostDec, true);
	}
	| PLUSPLUS UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kPreInc);
	}
	| MINUSMINUS UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kPreDec);
	}
	;

UpdateExpr_NoBrace:
	  LeftHandSideExpr_NoBrace
	| LeftHandSideExpr_NoBrace PLUSPLUS {
		$$ = new UnaryOpNode($1, @2, UnaryOp::kPostInc, true);
	}
	| LeftHandSideExpr_NoBrace MINUSMINUS {
		$$ = new UnaryOpNode($1, @2, UnaryOp::kPostDec, true);
	}
	| PLUSPLUS UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kPreInc);
	}
	| MINUSMINUS UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kPreDec);
	}
	;

/* 12.5 Unary Operators */
UnaryExpr:
	  UpdateExpr
	| UnaryExpr_Common
	/* | AwaitExpr */
	;

UnaryExpr_NoBrace:
	  UpdateExpr_NoBrace
	| UnaryExpr_Common
	/* | AwaitExpr_NoBrace */
	;

UnaryExpr_Common:
	  DELETE UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kDelete);
	}
	| VOID UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kVoid);
	}
	| TYPEOF UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kTypeOf);
	}
	| '+' UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kPlus);
	}
	| '-' UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kMinus);
	}
	| '~' UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kBitNot);
	}
	| '!' UnaryExpr {
		$$ = new UnaryOpNode($2, @1, UnaryOp::kNot);
	}

/* 12.6 Exponential Operator */
ExponentialExpr:
	  UnaryExpr
	| UpdateExpr STARSTAR ExponentialExpr {
		$$ = new BinOpNode($1, $3, BinOp::kExp);
	}
	;

ExponentialExpr_NoBrace:
	  UnaryExpr_NoBrace
	| UpdateExpr_NoBrace STARSTAR ExponentialExpr {
		$$ = new BinOpNode($1, $3, BinOp::kExp);
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
	  '*' { $$ = BinOp::kMul; }
	| '/' { $$ = BinOp::kDiv; }
	| '%' { $$ = BinOp::kMod; }
	;

/* 12.8 Additive Operators */
AdditiveExpr:
	  MultiplicativeExpr
	| AdditiveExpr '+' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, BinOp::kAdd);
	}
	| AdditiveExpr '-' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, BinOp::kSub);
	}
	;

AdditiveExpr_NoBrace:
	  MultiplicativeExpr_NoBrace
	| AdditiveExpr_NoBrace '+' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, BinOp::kAdd);
	}
	| AdditiveExpr_NoBrace '-' MultiplicativeExpr {
		$$ = new BinOpNode($1, $3, BinOp::kSub);
	}
	;

/* 12.9 Bitwise Shift Operators */
ShiftExpr:
	  AdditiveExpr
	| ShiftExpr LSHIFT AdditiveExpr{
		$$ = new BinOpNode($1, $3, BinOp::kLShift);
	}
	| ShiftExpr RSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, BinOp::kRShift);
	}
	| ShiftExpr URSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, BinOp::kURShift);
	}
	;

ShiftExpr_NoBrace:
	  AdditiveExpr_NoBrace
	| ShiftExpr_NoBrace LSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, BinOp::kLShift);
	}
	| ShiftExpr_NoBrace RSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, BinOp::kRShift);
	}
	| ShiftExpr_NoBrace URSHIFT AdditiveExpr {
		$$ = new BinOpNode($1, $3, BinOp::kURShift);
	}
	;

/* 12.10 Relational Operators */
RelationalExpr:
	  ShiftExpr
	| RelationalExpr '<' ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kLessThan);
	}
	| RelationalExpr '>' ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kGreaterThan);
	}
	| RelationalExpr LTE ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kLessThanOrEq);
	}
	| RelationalExpr GTE ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kGreaterThanOrEq);
	}
	| RelationalExpr INSTANCEOF ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kInstanceOf);
	}
	| RelationalExpr IN ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kAmong);
	}
	;

RelationalExpr_NoBrace:
	  ShiftExpr_NoBrace
	| RelationalExpr_NoBrace '<' ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kLessThan);
	}
	| RelationalExpr_NoBrace '>' ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kGreaterThan);
	}
	| RelationalExpr_NoBrace LTE ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kLessThanOrEq);
	}
	| RelationalExpr_NoBrace GTE ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kGreaterThanOrEq);
	}
	| RelationalExpr_NoBrace INSTANCEOF ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kInstanceOf);
	}
	| RelationalExpr_NoBrace IN ShiftExpr {
		$$ = new BinOpNode($1, $3, BinOp::kAmong);
	}
	;

/* 12.11 Equality Operators */
EqualityExpr:
	  RelationalExpr
	| EqualityExpr EQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kEquals);
	}
	| EqualityExpr NEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kNotEquals);
	}
	| EqualityExpr STRICTEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kStrictEquals);
	}
	| EqualityExpr STRICTNEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kStrictNotEquals);
	}
	;

EqualityExpr_NoBrace:
	  RelationalExpr_NoBrace
	| EqualityExpr_NoBrace EQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kEquals);
	}
	| EqualityExpr_NoBrace NEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kNotEquals);
	}
	| EqualityExpr_NoBrace STRICTEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kStrictEquals);
	}
	| EqualityExpr_NoBrace STRICTNEQ RelationalExpr {
		$$ = new BinOpNode($1, $3, BinOp::kStrictNotEquals);
	}
	;

/* 12.12 Binary Bitwise Operators */
BitwiseANDExpr:
	  EqualityExpr
	| BitwiseANDExpr '&' EqualityExpr {
		$$ = new BinOpNode($1, $3, BinOp::kBitAnd);
	}
	;

BitwiseANDExpr_NoBrace:
	  EqualityExpr_NoBrace
	| BitwiseANDExpr_NoBrace '&' EqualityExpr {
		$$ = new BinOpNode($1, $3, BinOp::kBitAnd);
	}
	;

BitwiseXORExpr:
	  BitwiseANDExpr
	| BitwiseXORExpr '^' BitwiseANDExpr {
		$$ = new BinOpNode($1, $3, BinOp::kBitXor);
	}
	;

BitwiseXORExpr_NoBrace:
	  BitwiseANDExpr_NoBrace
	| BitwiseXORExpr_NoBrace '^' BitwiseANDExpr {
		$$ = new BinOpNode($1, $3, BinOp::kBitXor);
	}
	;

BitwiseORExpr:
	  BitwiseXORExpr
	| BitwiseORExpr '|' BitwiseXORExpr {
		$$ = new BinOpNode($1, $3, BinOp::kBitOr);
	}
	;

BitwiseORExpr_NoBrace:
	  BitwiseXORExpr_NoBrace
	| BitwiseORExpr_NoBrace '|' BitwiseXORExpr {
		$$ = new BinOpNode($1, $3, BinOp::kBitOr);
	}
	;

/* 12.13 Binary Logical Operators */
LogicalANDExpr:
	  BitwiseORExpr
	| LogicalANDExpr LOGAND BitwiseORExpr {
		$$ = new BinOpNode($1, $3, BinOp::kAnd);
	}
	;

LogicalANDExpr_NoBrace:
	  BitwiseORExpr_NoBrace
	| LogicalANDExpr_NoBrace LOGAND BitwiseORExpr {
		$$ = new BinOpNode($1, $3, BinOp::kAnd);
	}
	;

LogicalORExpr:
	  LogicalANDExpr
	| LogicalORExpr LOGOR LogicalANDExpr {
		$$ = new BinOpNode($1, $3, BinOp::kOr);
	}
	;

LogicalORExpr_NoBrace:
	  LogicalANDExpr_NoBrace
	| LogicalORExpr_NoBrace LOGOR LogicalANDExpr {
		$$ = new BinOpNode($1, $3, BinOp::kOr);
	}
	;

CoalesceExpr:
	  CoalesceExprHead QUESTIONQUESTION BitwiseORExpr {
		$$ = new BinOpNode($1, $3, BinOp::kCoalesce);
	}
	;

CoalesceExprHead:
	  CoalesceExpr
	| BitwiseORExpr
	;

CoalesceExpr_NoBrace:
	  CoalesceExprHead_NoBrace QUESTIONQUESTION BitwiseORExpr {
		$$ = new BinOpNode($1, $3, BinOp::kCoalesce);
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
	| ShortCircuitExpr '?' AssignmentExpr ':' AssignmentExpr {
		$$ = new ConditionalNode($1, $3, $5);
	}
	;

ConditionalExpr_NoBrace:
	  ShortCircuitExpr_NoBrace
	| ShortCircuitExpr_NoBrace '?' AssignmentExpr ':' AssignmentExpr {
		$$ = new ConditionalNode($1, $3, $5);
	}
	;

/* 12.15 Assignment Operator */
AssignmentExpr:
	  ConditionalExpr
	// virtual | ObjectAssignmentPattern '=' AssignmentExpr
	// virtual | ArrayAssignmentPattern '=' AssignmentExpr
	// | YieldExpr
	| ArrowFunction
	// | AsyncArrowFunction
	| LeftHandSideExpr '=' AssignmentExpr {
		$$ = new AssignNode($1, $3);
	}
	| LeftHandSideExpr ASSIGNOP AssignmentExpr {
		UNIMPLEMENTED;
	}
	;

AssignmentExpr_NoBrace:
	  ConditionalExpr_NoBrace
	// | ArrayAssignmentPattern '=' AssignmentExpr
	// | YieldExpr
	| ArrowFunction
	// | AsyncArrowFunction
	| LeftHandSideExpr_NoBrace '=' AssignmentExpr {
		$$ = new AssignNode($1, $3);
	}
	| LeftHandSideExpr_NoBrace ASSIGNOP AssignmentExpr {
		UNIMPLEMENTED;
	}
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
	| Expr ',' AssignmentExpr {
		$$ = new CommaNode($1, $3);
	}
	;

Expr_NoBrace:
	  AssignmentExpr_NoBrace
	| Expr_NoBrace ',' AssignmentExpr {
		$$ = new CommaNode($1, $3);
	}
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
	  '{' StmtList '}' {
		$$ = new BlockNode(loc_from(@1, @3), $2);
	}
	| '{' '}' {
		$$ = new BlockNode(loc_from(@1, @2), NULL);
	}
	;

StmtList:
	  StmtListItem {
		$$ = new std::vector<StmtNode*>;
		$$->push_back($1);
	}
	| StmtList StmtListItem {
		$$ = $1;
		$$->push_back($2);
	}
	;

StmtListItem:
	  Stmt
	| Declaration
	;

LexicalDeclaration:
	  LetOrConst BindingList ';' {
		$$ = new DeclNode(loc_from(@1, @3), (DeclNode::Type)$1, $2);
	}
	| LetOrConst BindingList error {
		ASI;
		$$ = new DeclNode(loc_from(@1, @2), (DeclNode::Type)$1, $2);
	}
	;

LetOrConst:
	  LET { $$ = DeclNode::kLet; }
	| CONST { $$ = DeclNode::kConst; }
	;

BindingList:
	  LexicalBinding {
		$$ = new SingleDeclNode::Vec;
		$$->push_back($1);
	}
	| BindingList ',' LexicalBinding {
		$$ = $1;
		$$->push_back($3);
	}
	;

LexicalBinding:
	  BindingIdentifier Initialiser {
		$$ = new SingleDeclNode(new SingleNameDestructuringNode($1, NULL), $2);
	}
	| BindingPattern Initialiser {
		UNIMPLEMENTED;
	}
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
	  ObjectBindingPattern {
		UNIMPLEMENTED;
	}
	| ArrayBindingPattern {
		UNIMPLEMENTED;
	}
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
	| BindingPattern {
		UNIMPLEMENTED;
	}
	| BindingPattern Initialiser {
		UNIMPLEMENTED;
	}
	;

SingleNameBinding:
	  BindingIdentifier {
		$$ = new SingleNameDestructuringNode($1);
	}
	| BindingIdentifier Initialiser {
		$$ = new SingleNameDestructuringNode($1, $2);
	}
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
	  Expr_NoBrace ';' {
		$$ = new ExprStmtNode($1);
	}
	| Expr_NoBrace error {
		ASI;
		$$ = new ExprStmtNode($1);
	}
	;

IfStmt:
	  IF '(' Expr ')' Stmt ELSE Stmt {
		$$ = new IfNode(loc_from(@1, @7), $3, $5, $7);
	}
	| IF '(' Expr ')' Stmt %prec PLAIN_IF {
		$$ = new IfNode(loc_from(@1, @5), $3, $5, NULL);
	}
	;

IterationStmt:
	  DoWhileStmt
	| WhileStmt
	| ForStmt
	//| ForInOfStmt
	;

DoWhileStmt: /* [Yield, Await, Return] */
	  DO Stmt /* [?Yield, ?Await, ?Return] */ WHILE '('
	  Expr /* [+In, ?Yield, ?Await] */ ')' ';' {
		$$ = new DoWhileNode(loc_from(@1, @7), $5, $2);
	}
	;

WhileStmt: /* [Yield, Await, Return] */
	  WHILE '(' Expr /* [+In, ?Yield, ?Await] */ ')'
	  Stmt /* [?Yield, ?Await, ?Return] */ {
		$$ = new WhileNode(loc_from(@1, @5), $3, $5);
	}
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
	  Stmt {
		$$ = new ForNode(loc_from(@1, @9), new ExprStmtNode($3), $5,
		    $7);
	}
	| FOR '(' VAR VariableDeclarationList ';' ExprOpt ';'
	  ExprOpt ')' Stmt {
		/*
		$$ = new ForNode(loc_from(@1, @10), $4 ??? , $6, $8,
		    $10);
		*/
		UNIMPLEMENTED;
	}
	| FOR '(' LexicalDeclaration ExprOpt ';' ExprOpt ')'
	  Stmt {
		/*
		$$ = new ForNode(loc_from(@1, @10), $4 ??? , $6, $8,
		    $10);
		*/
		UNIMPLEMENTED;
	}
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
	  %empty { $$ = NULL; }
	| FunctionRestParameter {
		UNIMPLEMENTED;
	}
	| FormalParameterList
	| FormalParameterList ','
	| FormalParameterList ',' FunctionRestParameter {
		UNIMPLEMENTED;
	}
	;


FormalParameterList:
	  FormalParameter {
		$$ = new std::vector<DestructuringNode*>;
		$$->push_back($1);
	}
	| FormalParameterList ',' FormalParameter {
		$$ = $1;
		$$->push_back($3);
	}
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
	  FUNCTION BindingIdentifier_Str '(' FormalParameters ')' '{' FunctionBody
	  '}' {
		$$ = new FunctionExprNode(loc_from(@1, @8), $2, $4, $7);
	}
	| FUNCTION '(' FormalParameters ')' '{' FunctionBody '}' {
		$$ = new FunctionExprNode(loc_from(@1, @7), NULL, $3, $6);
	}
	;

FunctionBody:
	FunctionStmtList
	;

FunctionStmtList:
	  StmtList
	| %empty { $$ = NULL; }
	;

ArrowFunction:
	  ArrowParameters /* [no LineTerminator here] */ FARROW ConciseBody
	;

ArrowParameters:
	  BindingIdentifier
	| CoverParenthesisedExprAndArrowParameterList
	;

ConciseBody:
	  ExpressionBody
	;

ExpressionBody:
	  AssignmentExpr_NoBrace
	;

/*
When processing an instance of the production

    ArrowParameters[Yield, Await] :
	CoverParenthesizedExpressionAndArrowParameterList[?Yield, ?Await]

the interpretation of CoverParenthesizedExpressionAndArrowParameterList is
refined using the following grammar:

ArrowFormalParameters[Yield, Await] :
	( UniqueFormalParameters[?Yield, ?Await] )
*/


Script:
	  ScriptBody { driver->m_script = new ScriptNode(@1, $1); }
	| %empty { driver->m_script = NULL; }
	;

ScriptBody:
	  StmtList
	;


%%

#if 0
/* this is for byacc and prints possible shifts */
void
yyerror(Driver *driver, int yychar, int yystate, YYLTYPE *loc, char *text)
{
	register int yyn, count = 0;

	printf("%d:%d: %s\n", loc->first_line + 1, loc->first_column,
		    text);
		print_highlight(driver->txt, loc->first_line, loc->first_column,
		    loc->last_line, loc->last_column);

	if (((yyn = yysindex[yystate]) != 0) && (yyn < YYTABLESIZE)) {
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