#ifndef OBJECTMEMORY_HH_
#define OBJECTMEMORY_HH_

#include <vector>

#include "Object.h"

#define ALIGNMENT 16
#define ALIGN(size) (((size) + ALIGNMENT - 1) & ~(ALIGNMENT - 1))

class ObjectMemory {
	friend class ObjectMemoryOSThread;

	static UndefinedDesc s_undefinedDesc;
	static NullDesc s_nullDesc;
	static BooleanDesc s_trueDesc, s_falseDesc;

	/** Shared global arena. */
	static mps_arena_t m_mpsArena;
	/** Object format for ObjectDescs */
	mps_fmt_t m_mpsObjDescFmt;
	/** Object format for PrimDescs */
	mps_fmt_t m_mpsPrimDescFmt;
	/** Object chain. */
	mps_chain_t m_mpsChain;
	/** AMC pool for ObjectDescs. */
	mps_pool_t m_mpsObjDescPool;
	/** AMCZ pool for PrimDescs. */
	mps_pool_t m_mpsPrimDescPool;

    public:
	static PrimOop s_undefined, s_null, s_true, s_false;

	ObjectMemory();
};

/**
 * Per OS thread ObjectMemory.
 */
class ObjectMemoryOSThread {
	ObjectMemory &m_omem;
	/** Allocation point for regular objects. */
	mps_ap_t m_mpsObjAP;
	/** Allocation point for leaf objects. */
	mps_ap_t m_mpsLeafObjAP;
	/** Root for this thread's stack */
	mps_root_t m_mpsThreadRoot;
	/** MPS thread representation. */
	mps_thr_t m_mpsThread;

    public:
	ObjectMemoryOSThread(ObjectMemory &omem, void *marker);

	MemOop<PlainArray> makeArray(size_t size);
	PrimOop makeDouble(double val);
	PrimOop makeString(const char * txt);
	MemOop<Environment> makeEnvironment(MemOop<Environment> prev,
	    MemOop<EnvironmentMap> map, size_t nArgs);
	MemOop<EnvironmentMap> makeEnvironmentMap(
	    const std::vector<char *> &paramNames,
	    const std::vector<char *> &localNames);
};

#endif /* OBJECTMEMORY_HH_ */
