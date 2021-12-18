#include <cstdio>

#include "Bytecode.hh"
#include "VM.hh"

namespace VM {

void
BytecodeEncoder::emit0(Op op)
{
	//printf("EMIT INTO FUNC %p\n", m_fun);
	m_fun->m_bytecode.push_back(op);
	printf("\t%s;\n", opName(op));
}

void
BytecodeEncoder::emit1(Op op, char arg1)
{
	m_fun->m_bytecode.push_back(op);
	m_fun->m_bytecode.push_back(arg1);
	printf("\t%s (%d);\n", opName(op), arg1);
}

void
BytecodeEncoder::emit2(Op op, char arg1, char arg2)
{
	m_fun->m_bytecode.push_back(op);
	m_fun->m_bytecode.push_back(arg1);
	m_fun->m_bytecode.push_back(arg2);
	printf("\t%s (%d,%d);\n", opName(op), arg1, arg2);
}

char
BytecodeEncoder::litNum(double num)
{
	m_fun->m_literals.push_back(num);
	return m_fun->m_literals.size() - 1;
}

char
BytecodeEncoder::litStr(const char *txt)
{
	m_fun->m_literals.push_back(txt);
	return m_fun->m_literals.size() - 1;
}

char
BytecodeEncoder::litObj(JSObject * obj)
{
	m_fun->m_literals.push_back(obj);
	return m_fun->m_literals.size() - 1;
}

const char *
opName(Op op)
{
	switch (op) {
	case kPushArg:
		return "PushArg";

	case kPushUndefined:
		return "PushUndefined";

	case kPushLiteral:
		return "PushLiteral";

	case kResolve:
		return "Resolve";

	case kResolvedStore:
		return "ResolvedStore";

	case kPop:
		return "Pop";

	case kAdd:
		return "Add";

	case kCall:
		return "Call";

	case kCreateClosure:
		return "CreateClosure";

	case kReturn:
		return "Return";
	}
}
};