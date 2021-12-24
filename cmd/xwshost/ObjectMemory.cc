#include <err.h>

#include "Object.inl.hh"

#define FATAL(...) errx(EXIT_FAILURE, __VA_ARGS__)

MemOop<PlainArray>
ObjectMemoryOSThread::makeArray(size_t nElements)
{
	size_t size = ALIGN(sizeof(PlainArray) + sizeof(Oop) * nElements);
	PlainArray *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsObjAP, size);
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeArray");
		obj->m_kind = ObjectDesc::kPlainArray;
		obj->m_nElements = nElements;
	} while (!mps_commit(m_mpsObjAP, ((void *)obj), size));

	return obj;
}

PrimOop
ObjectMemoryOSThread::makeDouble(double val)
{
	PrimDesc *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsLeafObjAP,
		    sizeof(PrimDesc));
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeArray");
		obj->m_kind = PrimDesc::kDouble;
		obj->m_dbl = val;
	} while (!mps_commit(m_mpsLeafObjAP, ((void *)obj), sizeof(PrimDesc)));

	return obj;
}

PrimOop
ObjectMemoryOSThread::makeString(const char *txt)
{
	size_t len = strlen(txt);
	size_t inlineLen = len >= 6 ? 6 : len;
	size_t extraLen = len > 6 ? len - 6 : 0;
	size_t size = ALIGN((sizeof(PrimDesc) + extraLen));

	PrimDesc *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsLeafObjAP,
		    sizeof(PrimDesc));
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeString");
		obj->m_kind = PrimDesc::kString;
		obj->m_strLen = len;
	} while (!mps_commit(m_mpsLeafObjAP, ((void *)obj), size));

	memcpy(obj->m_str, txt, inlineLen);
	memcpy(obj->m_str + 7, txt + 7, extraLen);

	return PrimOop(obj, Oop::kString);
}

MemOop<CharArray>
ObjectMemoryOSThread::makeCharArray(std::vector<char> &vec)
{
	size_t size = ALIGN(sizeof(CharArray) + sizeof(char) * vec.size());
	printf("RESULTANT SIZE: %d\n", size);
	CharArray *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsObjAP,
		    size);
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeCharArray");
		obj->m_kind = ObjectDesc::kCharArray;
		obj->m_nElements = vec.size();
	} while (!mps_commit(m_mpsObjAP, ((void *)obj), size));

	memcpy(obj->m_elements, vec.data(), vec.size());

	return obj;
}

MemOop<Closure>
ObjectMemoryOSThread::makeClosure(MemOop<Function> fun, MemOop<Environment> env)
{
	Closure *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsObjAP,
		    ALIGN(sizeof(Closure)));
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeClosure");
		obj->m_kind = ObjectDesc::kClosure;
		obj->m_func = fun;
		obj->m_baseEnv = env;
	} while (!mps_commit(m_mpsObjAP, ((void *)obj),
	    ALIGN(sizeof(Closure))));

	return obj;
}

MemOop<Environment>
ObjectMemoryOSThread::makeEnvironment(MemOop<Environment> prev,
    MemOop<EnvironmentMap> map, size_t nArgs)
{
	Environment *obj;
	MemOop<PlainArray> args = makeArray(nArgs < map->m_nParams ?
	    map->m_nParams : nArgs);
	MemOop<PlainArray> locals = makeArray(map->m_nLocals);

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsObjAP,
		    ALIGN(sizeof(Environment)));
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeEnvironment");
		obj->m_kind = ObjectDesc::kEnvironment;
		obj->m_map = map;
		obj->m_prev = prev;
		obj->m_args = args;
		obj->m_locals = locals;
		//new(obj) Environment(prev, map, args, locals);
	} while (!mps_commit(m_mpsObjAP, ((void *)obj),
	    ALIGN(sizeof(Environment))));

	return obj;
}

MemOop<EnvironmentMap>
ObjectMemoryOSThread::makeEnvironmentMap(const std::vector<char *> &paramNames,
    const std::vector<char *> &localNames)
{
	size_t nParams = paramNames.size();
	size_t nLocals = localNames.size();
	size_t nEntries = nParams + nLocals;
	size_t size = ALIGN(sizeof(EnvironmentMap) + sizeof(Oop) * nEntries);
	EnvironmentMap *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsObjAP, size);
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeEnvironmentMap");
		obj->m_kind = ObjectDesc::kEnvironmentMap;
		obj->m_nParams = nParams;
		obj->m_nLocals = nLocals;
	} while (!mps_commit(m_mpsObjAP, ((void *)obj), size));

	for (int i = 0; i < paramNames.size(); i++)
		obj->m_names[i] = makeString(paramNames[i]);
	for (int i = 0; i < localNames.size(); i++)
		obj->m_names[nParams + i] = makeString(localNames[i]);

	return obj;
}

MemOop<Function>
ObjectMemoryOSThread::makeFunction(MemOop<EnvironmentMap> map,
    MemOop<CharArray> bytecode, MemOop<PlainArray> literals)
{
	Function *obj;

	do {
		mps_res_t res = mps_reserve(((void **)&obj), m_mpsObjAP,
		    sizeof(Function));
		if (res != MPS_RES_OK)
			FATAL("out of memory in makeFunction");
		obj->m_kind = ObjectDesc::kFunction;
		obj->m_map = map;
		obj->m_bytecode = bytecode;
		obj->m_literals = literals;
	} while (!mps_commit(m_mpsObjAP, ((void *)obj), sizeof(Function)));

	return obj;
}