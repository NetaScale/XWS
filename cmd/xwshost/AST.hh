#ifndef AST_HH_
#define AST_HH_

#include <string>

struct Operator {
	enum Op {
		kExp,
		kMul,
		kDiv,
		kMod,
		kAdd,
		kSub,
		kLShift,
		kRShift,
		KSRShift,
		kInstanceOf,
		kAmong, /* in */
		kEquals,
		kNotEquals,
		kStrictEquals,
		kStrictNotEquals,
		kBitAnd,
		kBitXOr,
		kBitOr,
		kAnd,
		kOr,
		kCoalesce
	};
};

#include "Parser.tab.hh"

class Node {
    protected:
	Node(JSLTYPE loc);

	JSLTYPE m_loc;
};

class ExpressionNode : public Node {
	ExpressionNode(JSLTYPE loc);
};

class ThisNode : public ExpressionNode {
    public:
	ThisNode(JSLTYPE loc);
};

class IdentifierNode : public ExpressionNode {
    public:
	IdentifierNode(JSLTYPE loc, const char *value);

    protected:
	std::string m_value;
};

class NullNode : public ExpressionNode {
    public:
	NullNode(JSLTYPE loc);
};

class BoolNode : public ExpressionNode {
    public:
	BoolNode(JSLTYPE loc, bool value);

    protected:
	bool m_value;
};

class NumberNode : public ExpressionNode {
    public:
	NumberNode(JSLTYPE loc, double value);

    protected:
	double m_value;
};

class StringNode : public ExpressionNode {
    public:
	StringNode(JSLTYPE loc, const char *value);

    protected:
	std::string m_value;
};

class ArrayNode : public ExpressionNode {
    public:
};

class ObjectNode : public ExpressionNode {
    public:
};

class FunctionExpressionNode : public ExpressionNode {
    public:
};

/*
 * Binary operators
 */

class BinOpNode : public ExpressionNode {
    public:
	BinOpNode(ExpressionNode *lhs, ExpressionNode *rhs, Operator::Op op);

    protected:
	ExpressionNode *m_lhs, *m_rhs;
	Operator::Op m_op;
};

#endif /* AST_HH_ */