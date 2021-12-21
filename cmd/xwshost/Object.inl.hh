#ifndef OBJECT_INL_H_
#define OBJECT_INL_H_

#include <cmath>
#include <cstring>

#include "Object.h"

#include "ObjectMemory.hh"

bool
Oop::JS_ToBoolean()
{
	if (isSmi())
		return asI32() != 0;
	else
		switch (tag()) {
		case kDouble: {
			int cls = std::fpclassify(*dblAddr());
			return cls != FP_NAN && cls != FP_ZERO;
		}

		case kUndefined:
		case kNull:
			return false;

		case kBoolean:
			return m_full == ObjectMemory::s_true.m_full;

		case kString:
			return strlen(addr<StringDesc>()->m_str) == 0;

		case kObject:
			return true;

		/* never reached - tested above */
		case kSmi:
		/* never reached: all symbol Oops point into symbol table */
		case kSymbol:
		/* bigInts not supported yet */
		case kBigInt:
			abort();
		}
}

Oop Oop::JS_ToNumber(ObjectMemory & omem)
{
	if (isSmi())
		return *this;
	else
		switch (tag()) {
		case kDouble:
			return *this;

		case kUndefined:
			return omem.makeDouble(nan(""));

		case kNull:
			return Oop(0);

		case kBoolean:
			return Oop(m_full == ObjectMemory::s_true.m_full ? 1 : 0);

		case kString:
			abort();

		case kObject:
			abort();

		/* never reached - tested above */
		case kSmi:
		/* never reached: all symbol Oops point into symbol table */
		case kSymbol:
		/* bigInts not supported yet */
		case kBigInt:
			abort();
		}
}

#endif /* OBJECT_INL_H_ */
