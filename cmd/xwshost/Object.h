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
 * 64-bit platforms, these are tagged pointers with the lowest 3 bits for a tag.
 * If the least significant bit is 0, then it is a pointer, and the remaining 2
 * 2 bits encode the type of the heap object to which they point: 0 for a
 * Double, 1 for String, 2 for Symbol, and 3 for any other sort of heap object.
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
		kString = 2,
		kSymbol = 4,
		kObject = 6,
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
	inline void *asPtr() { return (void *)(m_full & ~7); }

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

class DoubleDesc {
	double m_dbl;
	int64_t space;
};

#endif /* OBJECT_H_ */
