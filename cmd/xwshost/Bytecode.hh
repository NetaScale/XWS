#ifndef BYTECODE_HH_
#define BYTECODE_HH_

#include <vector>

namespace VM {

class JSValue;
class JSObject;
class JSFunction;

enum Op {
	kPushArg,	/* u8 argIdx */
	kPushUndefined,
	kPushLiteral,	/* (u8 lit num) */
	kResolve,	/* (u8 lit str) */
	kResolvedStore, /* (u8 lit str) */

	kPop,

	kAdd,

	kCall, /* u8 numArgs */
	kCreateClosure,
	kReturn,
};

class BytecodeEncoder {
	//std::vector<char> &m_output;
	//std::vector<JSValue> & m_litOutput;
	JSFunction * m_fun;

    public:
	BytecodeEncoder(JSFunction * fun)
	    : m_fun(fun) {};

	void emit0(Op op);
	void emit1(Op op, char arg1);
	void emit2(Op op, char arg1, char arg2);

	char litNum(double num);
	char litStr(const char * txt);
	char litObj(JSObject * obj);
};

const char * opName(Op op);
};

#endif /* BYTECODE_HH_ */
