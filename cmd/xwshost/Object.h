#ifndef OBJECT_H_
#define OBJECT_H_

#include <iostream>
#include <map>
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

class Smi;
class ObjectDesc;
class PrimDesc;
class ObjectMemory;
class ObjectMemoryOSThread;
template <class T> class MemOop;
typedef MemOop<PrimDesc> PrimOop;

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

	Oop();
	Oop(ObjectDesc * val) : m_full((uintptr_t) val | kObject) {};
	Oop(void *val)
	    : m_full((uintptr_t)val) {};
	Oop(void *val, Type tag)
	    : m_full((uintptr_t)val | tag) {};

	static Oop getUndefined();

	/** is it a SmallInteger? */
	inline bool isSmi() const { return (m_full & 1); }
	/** is it the undefined singleton? */
	inline bool isUndefined() const;
	/** is it a pointer? */
	inline bool isPtr() const { return !(m_full & 1); }
	/** what is its type? */
	inline Type type() const { return isSmi() ? kSmi : tag(); }
	/** for a pointer, what is its tag? */
	inline Type tag() const { return (Type)(m_full & 15); }

	void print() const;

	/** ES2022 7.1.1 */
	inline PrimOop JS_toPrimitive(ObjectMemory &omem);
	/** ES2022 7.1.2 */
	inline bool JS_ToBoolean();
	/** ES2022 7.1.3 */
	inline Oop JS_ToNumeric(ObjectMemory &omem);
	/** ES2022 7.1.3 */
	inline Oop JS_ToNumber(ObjectMemoryOSThread &omem);

	/** quick access to a known double; no need to mask off tag */
	inline double *dblAddr() const { return (double *)m_full; }
	/** the Oop as a pointer; masks off tag bits */
	template <class T2> inline T2 *addrT() const
	{
		return (T2 *)(m_full & ~15);
	}
};

class Smi : public Oop {
    public:
	Smi(int32_t i32)
	    : Oop(i32) {};
};

template <class T = PrimDesc> class MemOop : public Oop {
    public:
	MemOop() { }
	MemOop(ObjectDesc *val)
	    : Oop(val) {};
	MemOop(void *val)
	    : Oop(val) {};
	MemOop(void *val, Type tag)
	    : Oop(val, tag) {};

	inline T &operator*() { return *Oop::template addrT<T>(); }

	inline T *operator->() { return Oop::template addrT<T>(); }
};

/** Singleton undefined. */
class UndefinedDesc {
	int64_t padding1, padding2;
};

/** Singleton null. */
class NullDesc {
	int64_t padding1, padding2;
};

/** Singleton true and false. */
class BooleanDesc {
	int64_t padding1, padding2;
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
		/**
		 * String length, minus NULL byte.
		 */
		size_t m_strLen;
		/**
		 * Length of whole padding object.
		 */
		size_t m_padLen;
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
	public:

	enum Kind {
		/* these are pseudo-objects */
		kFwd,
		kPad,
		kEnvironmentMap,
		kEnvironment,
		kPlainArray,
		kMap,
		kCharArray,
		/* these are pseudo for now but need to be promoted */
		kFunction,
		kClosure,

		/*
		 * the following are proper objects (subclass ProperObjectDesc)
		 */
	};

	struct {
		Kind m_kind: 16;
		int64_t m_bits: 48;
	};

	ObjectDesc(Kind kind): m_kind(kind) {};

	static mps_res_t mpsScan(mps_ss_t ss, mps_addr_t base,
	    mps_addr_t limit);
	static mps_addr_t mpsSkip(mps_addr_t base);
	static void mpsFwd(mps_addr_t old, mps_addr_t newAddr);
	static mps_addr_t mpsIsFwd(mps_addr_t addr);
	static void mpsPad(mps_addr_t addr, size_t size);
};

class Fwd : public ObjectDesc {
	ObjectDesc *m_ptr;
	size_t m_size;
};

struct Pad : public ObjectDesc {
	size_t m_size;
};

struct CharArray: public ObjectDesc {
	size_t m_nElements;
	char m_elements[0];
};

struct PlainArray: public ObjectDesc {
	size_t m_nElements;
	Oop m_elements[0];
};

struct EnvironmentMap : public ObjectDesc {
	size_t m_nParams;
	size_t m_nLocals;
	PrimOop m_names[0]; /* param names followed by locals */

	EnvironmentMap(size_t nParams, size_t nLocals)
	    : ObjectDesc(kEnvironmentMap)
	    , m_nParams(nParams)
	    , m_nLocals(nLocals) {};
};

struct Environment : public ObjectDesc {
	MemOop<EnvironmentMap> m_map;
	MemOop<Environment> m_prev;
	MemOop<PlainArray> m_args;
	MemOop<PlainArray> m_locals;

	Environment(MemOop<Environment> prev, MemOop<EnvironmentMap> map,
	    MemOop<PlainArray> args, MemOop<PlainArray> locals)
	    : ObjectDesc(kEnvironment)
	    , m_prev(prev)
	    , m_map(map)
	    , m_args(args)
	    , m_locals(locals) {};

	Oop &lookup(const char *val);
};

/**
 * Describes the structure of a ProperObject.
 */
struct Map : public ObjectDesc {
	enum Reason {
		kAddProp,
		kDelProp,
	};

	struct PropertyDesc {
		uint32_t m_idx; /**< index in objects' namedVals array */
		struct {
			bool esWritable : 1;
			bool esEnumerable : 1;
			bool esConfigurable : 1;
		} m_attributes;

		PrimOop m_name;
	};

	/**
	 * Oop to transitions array. It is an array laid out in this pattern:
	 * [ Smi reason, Oop<Map> to ]
	 * where `reason` is a value from enum #Reason.
	 */
	MemOop<PlainArray> m_transitions;
	/**
	 * Property descriptions stored inline.
	 */
	PropertyDesc m_props[0];
};

/**
 * An underlying JavaScript function object.
 */
class Function : public ObjectDesc  {
    public:
	MemOop<EnvironmentMap> m_map;
	MemOop<CharArray> m_bytecode;
	MemOop<PlainArray> m_literals;

	void disassemble(); /* bytecode.cc */
};

/**
 * An instantiated function object.
 */
class Closure : public ObjectDesc {
    public:
	MemOop<Function> m_func;
	MemOop<Environment> m_baseEnv;
};

struct ProperObject: public ObjectDesc {
	MemOop<Map> m_map;
	MemOop<PlainArray> m_indexedVals;
	MemOop<PlainArray> m_namedVals;
};


#endif /* OBJECT_H_ */
