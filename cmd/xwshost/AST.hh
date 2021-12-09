#ifndef AST_HH_
#define AST_HH_

#include <string>

struct Operator {
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
	JSLTYPE &loc() { return m_loc; };
};

class StmtNode : public Node {
    protected:
	StmtNode(JSLTYPE loc)
	    : Node(loc) {};
};

class ExprNode : public Node {
    protected:
	ExprNode(JSLTYPE loc)
	    : Node(loc) {};
};

class ThisNode : public ExprNode {
    public:
	ThisNode(JSLTYPE loc);
};

class IdentifierNode : public ExprNode {
	char *m_value;

    public:
	IdentifierNode(JSLTYPE loc, char *value)
	    : ExprNode(loc)
	    , m_value(value)
	{
	};
};

class NullNode : public ExprNode {
    public:
	NullNode(JSLTYPE loc);
};

class BoolNode : public ExprNode {
	bool m_value;

    public:
	BoolNode(JSLTYPE loc, bool value)
	    : ExprNode(loc)
	    , m_value(value) {};
};

class NumberNode : public ExprNode {
	double m_value;

    public:
	NumberNode(JSLTYPE loc, double value)
	    : ExprNode(loc)
	    , m_value(value)
	{
	};
};

class StringNode : public ExprNode {
	char *m_value;

    public:
	StringNode(JSLTYPE loc, char *value)
	    : ExprNode(loc)
	    , m_value(value)
	{
	};
};

class ArrayNode : public ExprNode {
    public:
};

class ObjectNode : public ExprNode {
    public:
};

class AccessorNode : public ExprNode {
	ExprNode *m_object, *m_property;

    public:
	AccessorNode(ExprNode *object, ExprNode *property)
	    : ExprNode(loc_from(object->loc(), property->loc()))
	    , m_object(object)
	    , m_property(property) {};
};

class SuperNode : public ExprNode {
    public:
	SuperNode(JSLTYPE loc)
	    : ExprNode(loc) {};
};

class NewExprNode: public ExprNode {
	ExprNode *m_expr;

    public:
	NewExprNode(JSLTYPE superLoc, ExprNode* expr)
	    : ExprNode(loc_from(superLoc, expr->loc())), m_expr(expr) {};
};

class FunctionExprNode : public ExprNode {
    public:
};

/*
 * Binary operators
 */

class BinOpNode : public ExprNode {
	ExprNode *m_lhs, *m_rhs;
	Operator::Op m_op;

    public:
	BinOpNode(ExprNode *lhs, ExprNode *rhs, Operator::Op op)
	    : ExprNode(loc_from(lhs->loc(), rhs->loc()))
	    , m_lhs(lhs)
	    , m_rhs(rhs)
	    , m_op(op) {};
};

class AssignNode : public ExprNode {
	ExprNode *m_lhs, *m_rhs;
	Operator::Op m_op; /* optional operation */

    public:
	AssignNode(ExprNode *lhs, ExprNode *rhs, Operator::Op op)
	    : ExprNode(loc_from(lhs->loc(), rhs->loc()))
	    , m_lhs(lhs)
	    , m_rhs(rhs)
	    , m_op(op) {};
};

class ExprStmtNode : public StmtNode {
	ExprNode *m_expr;

    public:
	ExprStmtNode(ExprNode *expr) : StmtNode(expr->loc()), m_expr(expr) {};
};

#endif /* AST_HH_ */