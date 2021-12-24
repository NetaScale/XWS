#ifndef BYTECODE_HH_
#define BYTECODE_HH_

#include <cstddef>
#include <stdint.h>
#include <vector>

#include "Object.h"

namespace VM {

class JSValue;
class JSObject;
class JSFunction;

enum Op {
	kPushArg, /* u8 argIdx */
	kPushUndefined,
	kPushLiteral,	/* (u8 lit num) */
	kResolve,	/* (u8 lit str) */
	kResolvedStore, /* (u8 lit str) */

	kPop,

	/** mostly replicates AST.hh BinOp enum */
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

	kJump,    /* u16 pc-offset */
	kJumpIfFalse, /* u16 pc-offset */

	kCall, /* u8 numArgs */
	kCreateClosure,
	kReturn,
};

class BytecodeEncoder {
	ObjectMemoryOSThread & m_omemt;
	std::vector<char> m_bytecode;
	std::vector<Oop> m_literals;

    public:
	BytecodeEncoder(ObjectMemoryOSThread & omemt)
	    : m_omemt(omemt) {};

	
	MemOop<Function> makeFun(std::vector<char*> &localNames,
	std::vector<char*> & paramNames);

	void emit0(Op op);
	void emit1i16(Op op, int16_t arg1);
	void emit1(Op op, char arg1);
	void emit2(Op op, char arg1, char arg2);

	char litNum(double num);
	char litStr(const char * txt);
	char litObj(Oop obj);

	void replaceJumpTarget(size_t pos, size_t newTarget);

	size_t pos();
};

const char * opName(Op op);
};

#endif /* BYTECODE_HH_ */
