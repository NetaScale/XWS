#ifndef OBJECT_H_
#define OBJECT_H_

#include <iostream>
#include <stdint.h>

extern "C" {
#include "mps.h"
#include "mpstd.h" /* for MPS_BUILD_MV */
}

class ObjectMemory;

namespace VM {
class Interpreter;
}

/**
 * Object Representation
 * =====================
 *
 * Oops
 * ----
 * An Oop (Object-Oriented Pointer) is the basic value type. On both 32-bit and
 * 64-bit platforms, these are tagged pointers with the lowest 4 bits for a tag.
 * If the least significant bit is 0, then it is a pointer to a heap object.

 * This leaves 3 bits to store type. Having established that the LSB is 0, we
 * now interpert the 4-bit tag component thus:
 *
 * - 0: Double
 * - 2: Undefined
 * - 4: Null
 * - 6: Boolean
 * - 8: BigInt
 * - 10: Symbol
 * - 12: String
 * - 14: Object
 *
 * Heap Objects
 * ------------
 * These include both primitives and proper Objects.
 */

#define XWS_64_BIT_WORD

class Oop {
    public:
	/**
	 * These differ between 32- and 64-bit platforms.
	 */
#ifdef XWS_64_BIT_WORD
	union {
		uintptr_t m_full;
		struct {
			int32_t m_i32a;
			int32_t m_i32b;
		};
	};

	Oop(int32_t i32)
	    : m_i32a(i32)
	    , m_i32b(1) {};

	inline int32_t asI32() const { return m_i32a; }
#endif

	/**
	 * Enumeration of types. The first eight (values 0 to 14) are pointer
	 * types; the 9th, value 1 (#kSmi), is a SmallInteger (a 31-bit integer
	 * on 32-bit platforms and a 32-bit integer on 64-bit platforms.)
	 */
	enum Type {
		kDouble = 0,

		/*
		 * These three could be elided in the future since they are
		 * singletons and a simple equality test of the pointer should
		 * suffice.
		 */
		kUndefined = 2,
		kNull = 4,
		kBoolean = 6,

		kBigInt = 8,
		kSymbol = 10,
		kString = 12,
		kObject = 14,

		kSmi = 1,
	};

	Oop(void *val)
	    : m_full((uintptr_t)val) {};
	Oop(void *val, Type tag)
	    : m_full((uintptr_t)val | tag) {};

	/** is it a SmallInteger? */
	inline bool isSmi() const { return (m_full & 1); }
	/** is it a pointer? */
	inline bool isPtr() const { return !(m_full & 1); }
	/** what is its type? */
	inline Type type() const { return isSmi() ? kSmi : tag(); }
	/** for a pointer, what is its tag? */
	inline Type tag() const { return (Type)(m_full & 15); }

	void print() const;

	/** ES2022 7.1.1 */
	inline Oop JS_toPrimitive(ObjectMemory &omem);
	/** ES2022 7.1.2 */
	inline bool JS_ToBoolean();
	/** ES2022 7.1.3 */
	inline Oop JS_ToNumeric(ObjectMemory &omem);
	/** ES2022 7.1.3 */
	inline Oop JS_ToNumber(ObjectMemory &omem);

	/** quick access to a known double; no need to mask off tag */
	inline double *dblAddr() const { return (double *)m_full; }
	/** the Oop as a pointer; masks off tag bits */
	template <class T> inline T *addr() const
	{
		return (T *)(m_full & ~15);
	}
};

/** Singleton undefined. */
class UndefinedDesc {
};

/** Singleton null. */
class NullDesc {
};

/** Singleton true and false. */
class BooleanDesc {
};

/** Heap-allocated primitive. */
struct PrimDesc {
	enum Kind {
		kString,
		kSymbol,
		kDouble,
		kPad16,
		kPad,
		kFwd16,
		kFwd,
	};

	union {
		double m_dbl;
		/** string or padding length */
		size_t m_len;
		PrimDesc *m_fwd;
	};
	struct {
		Kind m_kind : 8;
		union {
			int m_fwdLength;
			char m_str[7]; /* may be longer than 3 bytes! */
		} __attribute__((packed));
	} __attribute__((packed));

	static mps_res_t mpsScan(mps_ss_t ss, mps_addr_t base,
	    mps_addr_t limit);
	static mps_addr_t mpsSkip(mps_addr_t base);
	static void mpsFwd(mps_addr_t old, mps_addr_t newAddr);
	static mps_addr_t mpsIsFwd(mps_addr_t addr);
	static void mpsPad(mps_addr_t addr, size_t size);
};

/** Heap-allocated object. */
class ObjectDesc {
	union {
		ObjectDesc *m_fwd;
	};

	static mps_res_t mpsScan(mps_ss_t ss, mps_addr_t base,
	    mps_addr_t limit);
	static mps_addr_t mpsSkip(mps_addr_t base);
	static void mpsFwd(mps_addr_t old, mps_addr_t newAddr);
	static mps_addr_t mpsIsFwd(mps_addr_t addr);
	static void mpsPad(mps_addr_t addr, size_t size);
};

//#include "Object.inl.hh"

#endif /* OBJECT_H_ */
