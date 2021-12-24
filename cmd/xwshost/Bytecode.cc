#include <cstdio>
#include <cstdlib>

#include "Bytecode.hh"
#include "VM.hh"

void
Function::disassemble()
{
	int pc = 0;
	int end = m_bytecode->m_nElements;

	printf("FUNCTION OF LENGTH %d\n", end);
	printf("DISASSEMBLY:\n");

	while (pc < end) {
#define FETCH m_bytecode->m_elements[pc++];
		char op = FETCH;

		printf(" %d\t", pc - 1);
		switch (op) {
		case VM::kPushArg: {
			uint8_t idx = FETCH;
			printf("PushArg (%d)\n", idx);
			break;
		}

		case VM::kPushUndefined: {
			printf("PushUndefined\n");
			break;
		}

		case VM::kPushLiteral: {
			uint8_t idx = FETCH;
			printf("PushLiteral (%d)\n", idx);
			break;
		}

		case VM::kResolve: {
			uint8_t idx = FETCH;
			//JSValue val = m_literals[idx];
			printf("Resolve (%d)\n", idx);
			break;
		}

		case VM::kResolvedStore: {
			uint8_t idx = FETCH;
			//JSValue id = m_literals[idx];
			printf("ResolvedStore (%d)\n", idx);

			break;
		}

		case VM::kPop: {
			printf("Pop\n");
			break;
		}

		case VM::kAdd: {
			printf("Add\n");

			break;
		}

		case VM::kJump: {
			uint8_t b1 = FETCH;
			uint8_t b2 = FETCH;
			int16_t offs = (b1 << 8) | b2;
			printf("Jump (%d)\n", pc + offs);
			break;
		}

		case VM::kJumpIfFalse: {
			uint8_t b1 = FETCH;
			uint8_t b2 = FETCH;
			int16_t offs = (b1 << 8) | b2;
			printf("JumpIfFalse (%d)\n", pc + offs);
			break;
		}

		case VM::kCall: {
			uint8_t nargs = FETCH;
			printf("Call (%d)\n", nargs);
			break;
		}

		case VM::kCreateClosure: {
			printf("CreateClosure\n");
			break;
		}

		case VM::kReturn:
			printf("Return\n");
			break;
		}
	}
}

namespace VM {

void
BytecodeEncoder::emit0(Op op)
{
	m_bytecode.push_back(op);
	printf("\t%s;\n", opName(op));
}

void
BytecodeEncoder::emit1i16(Op op, int16_t arg1)
{
	uint8_t bytes[2];

	bytes[0] = ((arg1 & 0xFF00) >> 8);
	bytes[1] = (arg1 & 0x00FF);

	m_bytecode.push_back(op);
	m_bytecode.push_back(bytes[0]);
	m_bytecode.push_back(bytes[1]);

	printf("\t%s (%d);\n", opName(op), arg1);
}

void
BytecodeEncoder::emit1(Op op, char arg1)
{
	m_bytecode.push_back(op);
	m_bytecode.push_back(arg1);
	printf("\t%s (%d);\n", opName(op), arg1);
}

void
BytecodeEncoder::emit2(Op op, char arg1, char arg2)
{
	m_bytecode.push_back(op);
	m_bytecode.push_back(arg1);
	m_bytecode.push_back(arg2);
	printf("\t%s (%d,%d);\n", opName(op), arg1, arg2);
}

char
BytecodeEncoder::litNum(double num)
{
	m_literals.push_back(m_omemt.makeDouble(num));
	return m_literals.size() - 1;
}

char
BytecodeEncoder::litStr(const char *txt)
{
	m_literals.push_back(m_omemt.makeString(txt));
	return m_literals.size() - 1;
}

char
BytecodeEncoder::litObj(Oop obj)
{
	m_literals.push_back(obj);
	return m_literals.size() - 1;
}

void
BytecodeEncoder::replaceJumpTarget(size_t pos, size_t newTarget)
{
	uint8_t bytes[2];
	int16_t relative = newTarget - pos;

	printf("AMEND TARGET TO %d\n", relative);
	bytes[0] = ((relative & 0xff00) >> 8);
	bytes[1] = (relative & 0x00FF);

	m_bytecode[pos - 1] = bytes[1];
	m_bytecode[pos - 2] = bytes[0];
}

size_t
BytecodeEncoder::pos()
{
	return m_bytecode.size();
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

	case kJump:
		return "Jump";

	case kJumpIfFalse:
		return "JumpIfFalse";

	case kCall:
		return "Call";

	case kCreateClosure:
		return "CreateClosure";

	case kReturn:
		return "Return";

	default:
		abort();
	}
}

}; /* namespace VM */