#ifndef AST_HH_
#define AST_HH_

#include <map>
#include <string>
#include <vector>

class Visitor;

class ExprNode;
class ThisNode;
class IdentifierNode;
class NullNode;
class BoolNode;
class NumberNode;
class StringNode;
class ArrayNode;
class ObjectNode;
class AccessorNode;
class SuperNode;
class NewExprNode;
class FunCallNode;
class FunctionExprNode;
class UnaryOpNode;
class BinOpNode;
class AssignNode;
class ConditionalNode;
class CommaNode;
class SpreadNode;

class StmtNode;
class BlockNode;
class ExprStmtNode;
class IfNode;
class DoWhileNode;
class WhileNode;
class ForNode;
class ForInNode;
class ForOfNode;
class ContinueNode;
class BreakNode;
class ReturnNode;
class WithNode;
class LabelNode;
class ThrowNode;

class SingleNameDestructuringNode;

class ScriptNode;

struct BinOp {
	enum Op {
		kNone = 0,
		kExp,
		kMul,
		kDiv,
		kMod,
		kAdd,
		kSub,
		kLShift,
		kRShift,
		kURShift,
		kLessThan,
		kGreaterThan,
		kLessThanOrEq,
		kGreaterThanOrEq,
		kInstanceOf,
		kAmong, /* in */
		kEquals,
		kNotEquals,
		kStrictEquals,
		kStrictNotEquals,
		kBitAnd,
		kBitXor,
		kBitOr,
		kAnd,
		kOr,
		kCoalesce
	};
};

struct UnaryOp {
	enum Op {
		kNone = 0,
		kPostInc,
		kPostDec,
		kPreInc,
		kPreDec,
		kDelete,
		kVoid,
		kTypeOf,
		kPlus,
		kMinus,
		kBitNot,
		kNot,
	};
};

struct Decl {
	enum Type { kArg, kLocal, kGlobal } m_type;
	unsigned int m_idx;

	Decl(Type type, unsigned int idx = 0)
	    : m_type(type)
	    , m_idx(idx)
	{
	}
};

class DeclEnv {
    protected:
	friend class Hoister;
	friend class BytecodeGenerator;
	DeclEnv * m_parent;
	std::map<std::string, Decl *> m_decls;

    public:
	enum Type { kGlobal, kFunction, kBlock } m_type;

	DeclEnv(Type type)
	    : m_type(type) {};

	void defineArg(const char *name, unsigned int idx);
	/** define a lexically scoped variable */
	void defineLocal(const char *name);
	/** define a function/global-scoped variable */
	void defineVar(const char *name);
};

#include "Parser.tab.hh"

static inline JSLTYPE
loc_from(JSLTYPE &a, JSLTYPE &b)
{
	JSLTYPE ret;
	ret.first_column = a.first_column;
	ret.first_line = a.first_line;
	ret.last_column = b.last_column;
	ret.last_line = b.last_line;
	return ret;
}

class Node {
    protected:
	JSLTYPE m_loc;

	Node(JSLTYPE loc)
	    : m_loc(loc) {};

    public:
	virtual int accept(Visitor &visitor) { throw "fail"; };

	JSLTYPE &loc() { return m_loc; };
};

class StmtNode : public Node {
    protected:
	StmtNode(JSLTYPE loc)
	    : Node(loc) {};

    public:
	typedef std::vector<StmtNode *> Vec;
};

/*
 * Abstract superclass of all nodes introducing a context in which variables may
 * be lexically scoped, and within which statements may partake thereof.
 */
class ScopeNode : public StmtNode, public DeclEnv {
    protected:
	StmtNode::Vec *m_stmts;

	ScopeNode(JSLTYPE loc, DeclEnv::Type type, StmtNode::Vec *stmts)
	    : StmtNode(loc)
	    , DeclEnv(type)
	    , m_stmts(stmts) {};
};

class ExprNode : public Node {
    protected:
	ExprNode(JSLTYPE loc)
	    : Node(loc) {};

    public:
	typedef std::vector<ExprNode *> Vec;

	virtual DestructuringNode *toDestructuringNode() { return NULL; }
};

class DestructuringNode : public Node {
    protected:
	friend class AssignNode;

	ExprNode *m_initialiser;

	DestructuringNode(JSLTYPE loc, ExprNode *initialiser)
	    : Node(loc)
	    , m_initialiser(initialiser) {};

    public:
	typedef std::vector<DestructuringNode *> Vec;
};

class SingleDeclNode : public StmtNode {
	DestructuringNode *m_lhs;
	ExprNode *m_rhs;

    public:
	typedef std::vector<SingleDeclNode *> Vec;

	SingleDeclNode(DestructuringNode *lhs, ExprNode *rhs = NULL)
	    : StmtNode(loc_from(lhs->loc(), rhs->loc()))
	    , m_lhs(lhs)
	    , m_rhs(rhs) {};

	int accept(Visitor &visitor);
};

class DeclNode : public StmtNode {
    public:
	enum Type { kConst, kLet, kVar };

    protected:
	Type m_type;
	SingleDeclNode::Vec *m_decls;

    public:
	DeclNode(JSLTYPE loc, Type type, SingleDeclNode::Vec *decls)
	    : StmtNode(loc)
	    , m_type(type)
	    , m_decls(decls) {};

	int accept(Visitor &visitor);
};

class ThisNode : public ExprNode {
    public:
	ThisNode(JSLTYPE loc)
	    : ExprNode(loc) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class IdentifierNode : public ExprNode {
    protected:
	char *m_value;

    public:
	IdentifierNode(JSLTYPE loc, char *value)
	    : ExprNode(loc)
	    , m_value(value) {};

	DestructuringNode *toDestructuringNode();

	int accept(Visitor &visitor);

	const char *value() const { return m_value; }
};

class NullNode : public ExprNode {
    public:
	NullNode(JSLTYPE loc)
	    : ExprNode(loc) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class BoolNode : public ExprNode {
    protected:
	bool m_value;

    public:
	BoolNode(JSLTYPE loc, bool value)
	    : ExprNode(loc)
	    , m_value(value) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class NumberNode : public ExprNode {
    protected:
	double m_value;

    public:
	NumberNode(JSLTYPE loc, double value)
	    : ExprNode(loc)
	    , m_value(value) {};

	int accept(Visitor &visitor);
};

class StringNode : public ExprNode {
    protected:
	char *m_value;

    public:
	StringNode(JSLTYPE loc, char *value)
	    : ExprNode(loc)
	    , m_value(value) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class ArrayNode : public ExprNode {
    public:
};

class ObjectNode : public ExprNode {
    public:
};

class AccessorNode : public ExprNode {
    protected:
	ExprNode *m_object, *m_property;

    public:
	AccessorNode(ExprNode *object, ExprNode *property)
	    : ExprNode(loc_from(object->loc(), property->loc()))
	    , m_object(object)
	    , m_property(property) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class SuperNode : public ExprNode {
    public:
	SuperNode(JSLTYPE loc)
	    : ExprNode(loc) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class NewExprNode : public ExprNode {
    protected:
	ExprNode *m_expr;

    public:
	NewExprNode(JSLTYPE superLoc, ExprNode *expr)
	    : ExprNode(loc_from(superLoc, expr->loc()))
	    , m_expr(expr) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class FunCallNode : public ExprNode {
    protected:
	ExprNode *m_fun;
	std::vector<ExprNode *> *m_args;

    public:
	FunCallNode(ExprNode *fun, std::vector<ExprNode *> *args)
	    : ExprNode(
		  args ? loc_from(fun->loc(), args->back()->loc()) : fun->loc())
	    , m_fun(fun)
	    , m_args(args) {};

	int accept(Visitor &visitor);
};

class FunctionExprNode : public ExprNode, public DeclEnv {
    protected:
	std::string m_name;
	std::vector<DestructuringNode *> *m_formals;
	std::vector<StmtNode *> *m_body;

    public:
	FunctionExprNode(JSLTYPE loc, char *name,
	    std::vector<DestructuringNode *> *formals,
	    std::vector<StmtNode *> *body)
	    : ExprNode(loc)
	    , DeclEnv(DeclEnv::kFunction)
	    , m_name(name == NULL ? "" : name)
	    , m_formals(formals)
	    , m_body(body) {};

	int accept(Visitor &visitor);
};

class UnaryOpNode : public ExprNode {
    protected:
	ExprNode *m_expr;
	UnaryOp::Op m_op;

    public:
	UnaryOpNode(ExprNode *expr, JSLTYPE opLoc, UnaryOp::Op op,
	    bool isPostFix = false)
	    : ExprNode(isPostFix ? loc_from(expr->loc(), opLoc) :
					 loc_from(opLoc, expr->loc()))
	    , m_expr(expr)
	    , m_op(op) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class BinOpNode : public ExprNode {
    protected:
	ExprNode *m_lhs, *m_rhs;
	BinOp::Op m_op;

    public:
	BinOpNode(ExprNode *lhs, ExprNode *rhs, BinOp::Op op)
	    : ExprNode(loc_from(lhs->loc(), rhs->loc()))
	    , m_lhs(lhs)
	    , m_rhs(rhs)
	    , m_op(op) {};

	int accept(Visitor &visitor);
};

class AssignNode : public ExprNode {
    protected:
	ExprNode *m_lhs, *m_rhs;
	BinOp::Op m_op; /* optional operation */

    public:
	AssignNode(ExprNode *lhs, ExprNode *rhs, BinOp::Op op = BinOp::kNone)
	    : ExprNode(loc_from(lhs->loc(), rhs->loc()))
	    , m_lhs(lhs)
	    , m_rhs(rhs)
	    , m_op(op) {};

	DestructuringNode *toDestructuringNode();

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class ConditionalNode : public ExprNode {
    protected:
	ExprNode *m_cond, *m_trueCase, *m_falseCase;

    public:
	ConditionalNode(ExprNode *cond, ExprNode *trueCase, ExprNode *falseCase)
	    : ExprNode(loc_from(cond->loc(), falseCase->loc()))
	    , m_cond(cond)
	    , m_trueCase(trueCase)
	    , m_falseCase(falseCase) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class CommaNode : public ExprNode {
    protected:
	ExprNode *m_prev, *m_expr;

    public:
	CommaNode(ExprNode *prev, ExprNode *expr)
	    : ExprNode(loc_from(prev->loc(), expr->loc()))
	    , m_prev(prev)
	    , m_expr(expr) {};

	DestructuringNode::Vec *toDestructuringVec(
	    std::vector<DestructuringNode *> *vec = NULL);

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class SpreadNode : public ExprNode {
    protected:
	ExprNode *m_expr;

    public:
	SpreadNode(ExprNode *expr)
	    : ExprNode(expr->loc())
	    , m_expr(expr) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class BlockNode : public ScopeNode {
    public:
	BlockNode(JSLTYPE loc, StmtNode::Vec *stmts)
	    : ScopeNode(loc, DeclEnv::kBlock, stmts) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class ExprStmtNode : public StmtNode {
    protected:
	ExprNode *m_expr;

    public:
	ExprStmtNode(ExprNode *expr)
	    : StmtNode(expr->loc())
	    , m_expr(expr) {};

	int accept(Visitor &visitor);
};

class IfNode : public StmtNode {
    protected:
	ExprNode *m_cond;
	StmtNode *m_if, *m_else;

    public:
	IfNode(JSLTYPE loc, ExprNode *cond, StmtNode *ifBlock,
	    StmtNode *elseBlock)
	    : StmtNode(loc)
	    , m_cond(cond)
	    , m_if(ifBlock)
	    , m_else(elseBlock) {};

	int accept(Visitor &visitor);
};

class DoWhileNode : public StmtNode {
    protected:
	ExprNode *m_cond;
	StmtNode *m_do;

    public:
	DoWhileNode(JSLTYPE loc, ExprNode *cond, StmtNode *doBlock)
	    : StmtNode(loc)
	    , m_cond(cond)
	    , m_do(doBlock) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class WhileNode : public StmtNode {
    protected:
	ExprNode *m_cond;
	StmtNode *m_do;

    public:
	WhileNode(JSLTYPE loc, ExprNode *cond, StmtNode *doBlock)
	    : StmtNode(loc)
	    , m_cond(cond)
	    , m_do(doBlock) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class ForNode : public StmtNode {
    protected:
	StmtNode *m_init;
	ExprNode *m_cond, *m_post;

    public:
	ForNode(JSLTYPE loc, StmtNode *init, ExprNode *cond, ExprNode *post)
	    : StmtNode(loc)
	    , m_init(init)
	    , m_cond(cond)
	    , m_post(post) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class ForInNode : public StmtNode {
};

class ForOfNode : public StmtNode {
};

class ContinueNode : public StmtNode {
    protected:
	IdentifierNode *m_label;

    public:
	ContinueNode(JSLTYPE loc, IdentifierNode *label = NULL)
	    : StmtNode(loc)
	    , m_label(label) {};

	int accept(Visitor &visitor);
};

class BreakNode : public StmtNode {
    protected:
	IdentifierNode *m_label;

    public:
	BreakNode(JSLTYPE loc, IdentifierNode *label = NULL)
	    : StmtNode(loc)
	    , m_label(label) {};

	int accept(Visitor &visitor);
};

class ReturnNode : public StmtNode {
    protected:
	ExprNode *m_expr;

    public:
	ReturnNode(ExprNode *expr)
	    : StmtNode(expr->loc())
	    , m_expr(expr) {};

	int accept(Visitor &visitor);
};

class WithNode : public StmtNode {
    protected:
	ExprNode *m_expr;
	StmtNode *m_stmt;

    public:
	WithNode(ExprNode *expr, StmtNode *stmt)
	    : StmtNode(loc_from(expr->loc(), stmt->loc()))
	    , m_expr(expr)
	    , m_stmt(stmt) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

class LabelNode : public StmtNode {
    protected:
	IdentifierNode *m_label;
	StmtNode *m_stmt;

    public:
	LabelNode(IdentifierNode *label, StmtNode *stmt)
	    : StmtNode(stmt->loc())
	    , m_label(label)
	    , m_stmt(stmt) {};

	int accept(Visitor &visitor);
};

class ThrowNode : public StmtNode {
    protected:
	StmtNode *m_try, *m_catchStmt, *m_finally;
	DestructuringNode *m_catchDestructuring;

    public:
	ThrowNode(JSLTYPE loc, StmtNode *tryStmt,
	    DestructuringNode *catchDestructuring, StmtNode *catchStmt,
	    StmtNode *finally)
	    : StmtNode(loc)
	    , m_try(tryStmt)
	    , m_catchDestructuring(catchDestructuring)
	    , m_catchStmt(catchStmt)
	    , m_finally(finally) {};

	int accept(Visitor &visitor) { throw "unimplemented"; }
};

/*
 * Depending on context, either a parenthesised expression or an arrow function
 * parameter list.
 */
class CoverParenthesisedExprAndArrowParameterListNode : public Node {
    protected:
	ExprNode *m_expr, *m_restIdentifier;
	/* BindingPattern * m_restPattern; */

    public:
	CoverParenthesisedExprAndArrowParameterListNode(JSLTYPE loc,
	    ExprNode *expr, ExprNode *restIdentifier = NULL)
	    : Node(loc)
	    , m_expr(expr)
	    , m_restIdentifier(restIdentifier) {};

	/***
	 * Convert to an expression node if possible - returns NULL if this
	 * cannot be done.
	 */
	ExprNode *toExpr();

	/**
	 * Convert to a vector of destructuring nodes if possible. Returns NULL
	 * if this cannot be done. */
	std::vector<DestructuringNode *> *toDestructuringVec();

	int accept(Visitor &visitor) { throw "Unreachable"; }
};

class SingleNameDestructuringNode : public DestructuringNode {
	IdentifierNode *m_ident;

    public:
	SingleNameDestructuringNode(IdentifierNode *ident,
	    ExprNode *initialiser = NULL)
	    : DestructuringNode(initialiser ?
			    loc_from(ident->loc(), initialiser->loc()) :
			    ident->loc(),
		  initialiser)
	    , m_ident(ident) {};

	int accept(Visitor &visitor);
};

class ScriptNode : public ScopeNode {
    public:
	ScriptNode(JSLTYPE loc, StmtNode::Vec *stmts)
	    : ScopeNode(loc, DeclEnv::kGlobal, stmts) {};

	int accept(Visitor &visitor);
};

class Visitor {
    public:
	int visitThis(ThisNode *node);
	virtual int visitIdentifier(IdentifierNode *node, const char *ident);
	int visitNull(NullNode *node);
	int visitBool(BoolNode *node);
	virtual int visitNumber(NumberNode *node, double val);
	int visitString(StringNode *node);
	int visitArray(ArrayNode *node);
	int visitObject(ObjectNode *node);
	int visitAccessor(AccessorNode *node);
	int visitSuper(SuperNode *node);
	int visitNew(NewExprNode *node);
	virtual int visitFunCall(FunCallNode *node, ExprNode *expr,
	    ExprNode::Vec *args);
	virtual int visitFunExpr(FunctionExprNode *node, const char *name,
	    std::vector<DestructuringNode *> *formals,
	    std::vector<StmtNode *> *body);
	int visitUnaryOp(UnaryOpNode *node);
	virtual int visitBinOp(BinOpNode *node, ExprNode *lhs, BinOp::Op op,
	    ExprNode *rhs);
	int visitAssign(AssignNode *node);
	int visitConditional(ConditionalNode *node);
	int visitComma(CommaNode *node);
	int visitSpread(SpreadNode *node);

	int visitBlock(BlockNode *node);
	virtual int visitExprStmt(ExprStmtNode *node, ExprNode *expr);
	virtual int visitIf(IfNode *node, ExprNode *cond, StmtNode *ifCode,
	    StmtNode *elseCode);
	int visitDoWhile(DoWhileNode *node);
	int visitWhile(WhileNode *node);
	int visitFor(ForNode *node);
	int visitForIn(ForInNode *node);
	int visitForOf(ForOfNode *node);
	virtual int visitContinue(ContinueNode *node, IdentifierNode *label);
	virtual int visitBreak(BreakNode *node, IdentifierNode *label);
	virtual int visitReturn(ReturnNode *node, ExprNode * expr);
	int visitWith(WithNode *node);
	virtual int visitLabel(LabelNode *node, IdentifierNode *label,
	    StmtNode *stmt);
	int visitThrow(ThrowNode *node);

	virtual int
	visitSingleNameDestructuring(SingleNameDestructuringNode *node,
	    IdentifierNode *ident, ExprNode *initialiser);

	virtual int visitSingleDecl(SingleDeclNode *node,
	    DestructuringNode *lhs, ExprNode *rhs);
	virtual int visitDecl(DeclNode *node, DeclNode::Type type,
	    SingleDeclNode::Vec *&decls);

	virtual int visitScript(ScriptNode *node, StmtNode::Vec *stmts);
};

#define FOR_EACH(TYPE, ITER, VAR) \
	for (TYPE::iterator ITER = (VAR).begin(); ITER != (VAR).end(); it++)

#endif /* AST_HH_ */