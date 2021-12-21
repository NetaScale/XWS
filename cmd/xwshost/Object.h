#ifndef OBJECT_H_
#define OBJECT_H_

#include <iostream>
#include <stdint.h>

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
 *
 * Heap Objects
 * ------------
 * These include both primitives and proper Objects.
 */

#define XWS_64_BIT_WORD

class Oop {
    public:
	enum PtrType {
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
	};

	Oop(void *val)
	    : m_full((uintptr_t)val) {};
	Oop(void *val, PtrType tag)
	    : m_full((uintptr_t)val | tag) {};

	inline bool isPtr() { return !(m_full & 1); }
	/** if val is a pointer, return its type */
	inline PtrType ptrType() { return (PtrType)(m_full & 7); }

	void print()
	{
		if (isPtr())
			std::cout << "Pointer, type " << ptrType()
				  << ", target " << asPtr() << "\n";
		else
			std::cout << "Int32, value " << asI32() << "\n";
	}

	/** quick access to a known double; no need to mask off tag */
	inline double *asDblPtr() { return (double *)m_full; }
	inline void *asPtr() { return (void *)(m_full & ~15); }

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

	inline int32_t asI32() { return m_i32a; }
#endif
};

/** Heap-allocated double. */
class DoubleDesc {
	union {
		double m_dbl;
		void *m_fwd;
	};
	bool m_isFwd;
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

/** Heap-allocated string or symbol. */
class StringDesc {
	union {
		char *m_str;
		StringDesc *m_fwd;
	};
	bool m_isFwd;
};

/** Heap-allocated object. */
class ObjectDesc {
	struct {

		bool isFwd : 1;
	};
};

#endif /* OBJECT_H_ */
