#include <cassert>
#include <cmath>
#include <cstdio>
#include <limits>
#include <math.h>
#include <stdint.h>

#include "Bytecode.hh"
#include "ObjectMemory.hh"
#include "VM.hh"

UndefinedDesc ObjectMemory::s_undefinedDesc;
NullDesc ObjectMemory::s_nullDesc;
BooleanDesc ObjectMemory::s_trueDesc;
BooleanDesc ObjectMemory::s_falseDesc;

Oop ObjectMemory::s_undefined(&s_undefinedDesc);
Oop ObjectMemory::s_null(&s_nullDesc);
Oop ObjectMemory::s_true(&s_trueDesc);
Oop ObjectMemory::s_false(&s_falseDesc);

namespace VM {

static const int gSmiMax = INT32_MAX / 2, gSmiMin = INT32_MIN / 2;
static const double gEpsilon = std::numeric_limits<double>::epsilon();


bool
JSValue::JS_ToBoolean()
{
	switch (type) {
	case kUndefined:
		return false;
	case kInt32:
		return i32 != 0;
	case kString:
		return strlen(str) != 0;
	case kDouble: {
		int cls = fpclassify(dbl);
		return cls != FP_NAN && cls != FP_ZERO;
	}
	case kObject:
		return true;
	}
}

void
JSValue::print()
{
	switch (type) {
	case kUndefined:
		printf("undefined");
		break;
	case kInt32:
		printf("i32:%d", i32);
		break;
	case kString:
		printf("str:%s", str);
		break;
	case kDouble:
		printf("dbl:%lf", dbl);
		break;
	case kObject:
		return (void)obj->print();
	}
}

Environment::Environment(ScopeMap *map, Environment *prev)
    : m_map(map)
    , m_prev(prev)
{
	m_locals.resize(map->m_localNames.size(), JSValue());
	m_params.resize(map->m_paramNames.size(), JSValue());
}

JSValue
Environment::resolve(const char *id)
{
	for (int i = 0; i < m_locals.size(); i++) {
		if (m_map->m_localNames[i] != NULL &&
		    !strcmp(m_map->m_localNames[i], id)) {
			printf("Resolved identifier %s to local %d: ", id, i);
			m_locals[i].print();
			printf("\n");
			return m_locals[i];
		}
	}

	for (int i = 0; i < m_params.size(); i++) {
		if (m_map->m_paramNames[i] != NULL &&
		    !strcmp(m_map->m_paramNames[i], id)) {
			printf("Resolved identifier %s to parameter %d: ", id,
			    i);
			m_params[i].print();
			printf("\n");
			return m_params[i];
		}
	}

	return m_prev ? m_prev->resolve(id) : throw "Not resolved\n";
}

void
Environment::resolveStore(const char *id, JSValue val)
{
	for (int i = 0; i < m_locals.size(); i++) {
		if (m_map->m_localNames[i] != NULL &&
		    !strcmp(m_map->m_localNames[i], id)) {
			printf("Resolved identifier %s to local %d: ", id, i);
			return (void)(m_locals[i] = val);
		}
	}

	for (int i = 0; i < m_params.size(); i++) {
		if (m_map->m_paramNames[i] != NULL &&
		    !strcmp(m_map->m_paramNames[i], id)) {
			printf("Resolved identifier %s to parameter %d: ", id,
			    i);
			return (void)(m_params[i] = val);
		}
	}

	return m_prev ? m_prev->resolveStore(id, val) : throw "Not resolved\n";
}

JSValue
Interpreter::pop()
{
	JSValue val = m_stack.top();
	m_stack.pop();
	return val;
}

Interpreter::Interpreter(JSClosure *closure)
{
	m_bp = 0;
	m_pc = 0;
	m_closure = closure;
	m_env = new Environment(closure->m_func);
}

#define ISINT32(x) a.type == JSValue::kInt32
#define ISDOUBLE(x) a.type == JSValue::kDouble

#define DBLEQ(a, b) (fabs(a.dbl - b.dbl) < gEpsilon)

void
Interpreter::interpret()
{
	while (1) {
#define FETCH m_closure->m_func->m_bytecode[m_pc++]
		char op = FETCH;

		printf("about to execute %s\n", opName((VM::Op)op));

		switch (op) {
		case kPushArg: {
			uint8_t idx = FETCH;
			m_stack.push(m_env->m_params[idx]);
			break;
		}

		case kPushUndefined: {
			m_stack.push(JSValue());
			break;
		}

		case kPushLiteral: {
			uint8_t idx = FETCH;
			m_stack.push(m_closure->m_func->m_literals[idx]);
			break;
		}

		case kResolve: {
			uint8_t idx = FETCH;
			JSValue val = m_closure->m_func->m_literals[idx];
			m_stack.push(m_env->resolve(val.str));
			break;
		}

		case kResolvedStore: {
			uint8_t idx = FETCH;
			JSValue id = m_closure->m_func->m_literals[idx];
			JSValue obj = m_stack.top();

			m_env->resolveStore(id.str, obj);

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
			JSValue val = pop();

			if (val.JS_ToBoolean() == false)
				m_pc += offs;
			break;
		}

		case kAdd: {
			JSValue a = pop();
			JSValue b = pop();

			if (ISINT32(a) && ISINT32(b)) {
				int64_t res = a.i32 + b.i32;
				if (res <= gSmiMin || res >= gSmiMax)
					m_stack.push((double)res);
				else
					m_stack.push((int32_t)res);
			} else if (ISDOUBLE(a) && ISDOUBLE(b))
				m_stack.push(a.dbl + b.dbl);
			else
				abort();

			break;
		};

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

		case kCall: {
			uint8_t nArgs = FETCH;
			JSValue val = pop();
			JSClosure *closure = dynamic_cast<JSClosure *>(val.obj);
			Environment *env = new Environment(closure->m_func,
			    closure->m_baseEnv);
			for (int i = 0; i < nArgs; i++) {
				printf("ARG %d:", i);
				JSValue arg = pop();
				arg.print();
				printf("\n");

				env->m_params[i] = arg;
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
			JSValue val = pop();
			JSClosure *closure;

			closure = new JSClosure(dynamic_cast<JSFunction *>(
						    val.obj),
			    m_env);
			m_stack.push(closure);

			break;
		}

		case kReturn:
		{
			JSValue val = pop();

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
				m_env = dynamic_cast<Environment *>(pop().obj);
				m_closure = dynamic_cast<JSClosure *>(
				    pop().obj);
				m_bp = pop().i32;
				m_pc = pop().i32;
				assert(m_env);
				assert(m_closure);
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