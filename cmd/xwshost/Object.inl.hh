#ifndef OBJECT_INL_H_
#define OBJECT_INL_H_

#include <cmath>
#include <cstdio>
#include <cstring>

#include "ObjectMemory.hh"

inline Oop::Oop()
    : m_full(ObjectMemory::s_undefined.m_full) {};

inline bool
Oop::isUndefined() const
{
	return m_full == ObjectMemory::s_undefined.m_full;
}

inline bool
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
			return strlen(addrT<PrimDesc>()->m_str) == 0;

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

inline Oop
Oop::JS_ToNumber(ObjectMemoryOSThread &omem)
{
	if (isSmi())
		return *(PrimOop*)this;
	else
		switch (tag()) {
		case kDouble:
			return *(PrimOop*)this;

		case kUndefined:
			return omem.makeDouble(nan(""));

		case kNull:
			return Smi(0);

		case kBoolean:
			return Oop((m_full == ObjectMemory::s_true.m_full
			    ? 1 : 0));

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

inline Oop&
Environment::lookup(const char *val)
{
	for (size_t max = m_map->m_nLocals + m_map->m_nParams;
	     max >= m_map->m_nParams; max--) {
		if (!strcmp(m_map->m_names[max]->m_str, val)) {
			printf("Resolved %s to local %lu\n", val,
			    max - m_map->m_nParams);
			return m_locals->m_elements[max];
		}
	}

	for (size_t max = m_map->m_nParams; max >= 0; max--) {
		if (!strcmp(m_map->m_names[max]->m_str, val)) {
			printf("Resolved %s to argument %lu\n", val,
			    max - m_map->m_nParams);
			return m_args->m_elements[max];
		}
	}

	return !m_prev.isUndefined() ? m_prev->lookup(val) : throw "Not resolved";
}

#endif /* OBJECT_INL_H_ */
