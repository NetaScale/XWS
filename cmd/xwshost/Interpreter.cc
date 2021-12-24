#include <cassert>
#include <cmath>
#include <cstdio>
#include <limits>
#include <math.h>
#include <stdint.h>

#include "Bytecode.hh"
#include "ObjectMemory.hh"
#include "VM.hh"
#include "Object.inl.hh"

UndefinedDesc * ObjectMemory::s_undefinedDesc = 0x0;
NullDesc * ObjectMemory::s_nullDesc = 0x0;
BooleanDesc * ObjectMemory::s_trueDesc = (BooleanDesc*)0x16;
BooleanDesc * ObjectMemory::s_falseDesc = 0x0;

PrimOop ObjectMemory::s_undefined(s_undefinedDesc, Oop::kUndefined);
PrimOop ObjectMemory::s_null(s_nullDesc, Oop::kNull);
PrimOop ObjectMemory::s_true(s_trueDesc, Oop::kBoolean);
PrimOop ObjectMemory::s_false(s_falseDesc, Oop::kBoolean);

namespace VM {

static const int gSmiMax = INT32_MAX / 2, gSmiMin = INT32_MIN / 2;
static const double gEpsilon = std::numeric_limits<double>::epsilon();

Oop
Interpreter::pop()
{
	Oop val = m_stack.top();
	m_stack.pop();
	return val;
}

Interpreter::Interpreter(ObjectMemoryOSThread &omemt, MemOop<Closure> closure)
    : m_omemt(omemt)
{
	m_bp = 0;
	m_pc = 0;
	m_closure = closure;

	m_env = omemt.makeEnvironment(
	    *(MemOop<Environment> *)&ObjectMemory::s_undefined,
	    closure->m_func->m_map, 0);

	printf("Hello\n");
}

#define ISINT32(x) a.type == JSValue::kInt32
#define ISDOUBLE(x) a.type == JSValue::kDouble

#define DBLEQ(a, b) (fabs(a.dbl - b.dbl) < gEpsilon)

void
Interpreter::interpret()
{
	while (1) {
#define FETCH m_closure->m_func->m_bytecode->m_elements[m_pc++]
		char op = FETCH;

		printf("about to execute %s\n", opName((VM::Op)op));

		switch (op) {
		case kPushArg: {
			uint8_t idx = FETCH;
			m_stack.push(m_env->m_args->m_elements[idx]);
			break;
		}

		case kPushUndefined: {
			m_stack.push(ObjectMemory::s_undefined);
			break;
		}

		case kPushLiteral: {
			uint8_t idx = FETCH;
			m_stack.push(m_closure->m_func->m_literals->m_elements[idx]);
			break;
		}

		case kResolve: {
			uint8_t idx = FETCH;
			PrimOop val = *(PrimOop*)&m_closure->m_func->m_literals->m_elements[idx];
			m_stack.push(m_env->lookup(val->m_str));
			break;
		}

		case kResolvedStore: {
			uint8_t idx = FETCH;
			PrimOop id = *(PrimOop*)&m_closure->m_func->m_literals->m_elements[idx];
			Oop obj = m_stack.top();

			m_env->lookup(id->m_str) = obj;

			break;
		}

		case kPop: {
			m_stack.pop();
			break;
		}

		case kJump: {
			uint8_t b1 = FETCH;
			uint8_t b2 = FETCH;
			int16_t offs = (b1 << 8) | b2;
			m_pc += offs;
			break;
		}

		case kJumpIfFalse: {
			uint8_t b1 = FETCH;
			uint8_t b2 = FETCH;
			int16_t offs = (b1 << 8) | b2;
			Oop val = pop();

			if (val.JS_ToBoolean() == false)
				m_pc += offs;
			break;
		}

		case kAdd: {
			Oop a = pop();
			Oop b = pop();

			if (a.isSmi() && b.isSmi()) {
				int64_t res = a.asI32() + b.asI32();
				if (res <= gSmiMin || res >= gSmiMax)
					m_stack.push(m_omemt.makeDouble(res));
				else
					m_stack.push((int32_t)res);
			} else if (a.type() == Oop::kDouble && b.type() == Oop::kDouble)
			{
				*a.dblAddr() = *a.dblAddr() + *b.dblAddr();
				m_stack.push(a);
			}
			else
				abort();

			break;
		};

#if 0
		case kSub: {
			JSValue a = pop();
			JSValue b = pop();
			if (ISINT32(a) && ISINT32(b)) {
				int64_t res = a.i32 - b.i32;
				if (res <= gSmiMin || res >= gSmiMax)
					m_stack.push((double)res);
				else
					m_stack.push((int32_t)res);
			} else if (ISDOUBLE(a) && ISDOUBLE(b))
				m_stack.push(a.dbl - b.dbl);
			else
				abort();
			break;
		};

		case kMul: {
			JSValue a = pop();
			JSValue b = pop();

			if (ISINT32(a) && ISINT32(b)) {
				int64_t res = a.i32 * b.i32;
				if (res <= gSmiMin || res >= gSmiMax)
					m_stack.push((double)res);
				else
					m_stack.push((int32_t)res);
			} else if (ISDOUBLE(a) && ISDOUBLE(b))
				m_stack.push(a.dbl * b.dbl);
			else
				abort();
			break;
		};

		case kDiv: {
			JSValue a = pop();
			JSValue b = pop();
			if (ISINT32(a) && ISINT32(b)) {
				int32_t res;

				if (a.i32 % b.i32 == 0)
					m_stack.push((int32_t)(a.i32 / b.i32));
				else
					m_stack.push(
					    (double)a.i32 / (double)b.i32);
			} else if (ISDOUBLE(a) && ISDOUBLE(b))
				m_stack.push(a.dbl / b.dbl);
			else
				abort();
			break;
		};

		case kEquals: {
			JSValue a = pop();
			JSValue b = pop();
			if (ISINT32(a) && ISINT32(b)) {
				int32_t res;

				if (a.i32 == b.i32)
					m_stack.push(true);
				else
					m_stack.push(false);
			} else if (ISDOUBLE(a) && ISDOUBLE(b))
				m_stack.push(DBLEQ(a, b));
			else
				abort();
			break;
		};
#endif

#define AS(T, VAL) (*(T*)&(VAL))

		case kCall: {
			uint8_t nArgs = FETCH;
			Oop val = pop();
			MemOop<Closure> closure = AS(MemOop<Closure>, val);
			MemOop<Environment> env = m_omemt.makeEnvironment(m_env, closure->m_func->m_map, nArgs);
	
			for (int i = 0; i < nArgs; i++) {
				printf("ARG %d:", i);
				Oop arg = pop();
				arg.print();
				printf("\n");

				env->m_args->m_elements[i] = arg;
			}

			m_stack.push((int32_t)m_pc);
			m_stack.push((int32_t)m_bp);
			m_stack.push(m_closure);
			m_stack.push(m_env);

			m_pc = 0;
			m_bp = m_stack.size() - 1;
			m_closure = closure;
			m_env = env;

			break;
		}

		case kCreateClosure: {
			Oop VAL = pop();
			MemOop<Function> val = AS(MemOop<Function>, VAL);
			MemOop<Closure> closure;

			closure = m_omemt.makeClosure(val, m_env);
			m_stack.push(closure);

			break;
		}


		case kReturn:
		{
			Oop val = pop();

			if (m_stack.empty()) {
				printf(
				    "Interpretation finished with a final value of:\n");
				val.print();
				printf("\n");
				return;
			} else {
				/*JSValue env = pop();
				JSValue closure = pop();
				JSValue bp = pop();
				JSValue pc = pop();*/

				printf("RETURNING...\n");
				Oop env = pop();
				Oop closure = pop();
				m_env = AS(MemOop<Environment>, env);
				m_closure = AS(MemOop<Closure>, closure);
				m_bp = pop().asI32();
				m_pc = pop().asI32();
				//assert(m_env);
				//assert(m_closure);
				m_stack.push(val);
			}
			break;
		}

		default:
			abort();
		}
	}
}

}; /* namespace VM */