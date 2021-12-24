#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <err.h>

#include "Object.h"

#include "ObjectMemory.hh"

extern "C" {
#include "mps.h"
#include "mpsavm.h"
#include "mpscamc.h"
#include "mpstd.h" /* for MPS_BUILD_MV */
}

#define gcDbg(...) printf(__VA_ARGS__)
#define FATAL(...) errx(EXIT_FAILURE, __VA_ARGS__)
#define LENGTH(array) (sizeof(array) / sizeof(array[0]))

mps_arena_t ObjectMemory::m_mpsArena = NULL;

static mps_res_t scanArea(mps_ss_t ss, void *base, void *limit, void *closure);

ObjectMemory::ObjectMemory()
{
	mps_res_t res;
	static mps_gen_param_s obj_gen_params[] = {
	    { 6400, 0.80 },
	    { 6400, 0.80 },
	    { 6400, 0.80 }
	};

	if (m_mpsArena == NULL) {
		MPS_ARGS_BEGIN (args) {
			MPS_ARGS_ADD(args, MPS_KEY_ARENA_SIZE,
			    32 * 1024 * 1024);
			MPS_ARGS_DONE(args);
			res = mps_arena_create_k(&m_mpsArena,
			    mps_arena_class_vm(), args);
		}
		MPS_ARGS_END(args);
		if (res != MPS_RES_OK)
			FATAL("Couldn't create arena");
	}

	mps_message_type_enable(m_mpsArena, mps_message_type_gc());
	mps_message_type_enable(m_mpsArena, mps_message_type_gc_start());

	MPS_ARGS_BEGIN (args) {
		MPS_ARGS_ADD(args, MPS_KEY_FMT_ALIGN, 16);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_SCAN, PrimDesc::mpsScan);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_SKIP, PrimDesc::mpsSkip);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_FWD, PrimDesc::mpsFwd);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_ISFWD, PrimDesc::mpsIsFwd);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_PAD, PrimDesc::mpsPad);
		MPS_ARGS_DONE(args);
		res = mps_fmt_create_k(&m_mpsPrimDescFmt, m_mpsArena, args);
	}
	MPS_ARGS_END(args);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create primitive format");

	MPS_ARGS_BEGIN (args) {
		MPS_ARGS_ADD(args, MPS_KEY_FMT_ALIGN, 16);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_SCAN, ObjectDesc::mpsScan);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_SKIP, ObjectDesc::mpsSkip);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_FWD, ObjectDesc::mpsFwd);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_ISFWD, ObjectDesc::mpsIsFwd);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_PAD, ObjectDesc::mpsPad);
		MPS_ARGS_DONE(args);
		res = mps_fmt_create_k(&m_mpsObjDescFmt, m_mpsArena, args);
	}
	MPS_ARGS_END(args);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create object format");

	/** Create a generation chain. */
	res = mps_chain_create(&m_mpsChain, m_mpsArena, LENGTH(obj_gen_params),
	    obj_gen_params);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create generation chain");

	/** Create AMCZ pool for primitives. */
	MPS_ARGS_BEGIN (args) {
		MPS_ARGS_ADD(args, MPS_KEY_CHAIN, m_mpsChain);
		MPS_ARGS_ADD(args, MPS_KEY_FORMAT, m_mpsPrimDescFmt);
		MPS_ARGS_ADD(args, MPS_KEY_ALIGN, 32);
		MPS_ARGS_DONE(args);
		res = mps_pool_create_k(&m_mpsPrimDescPool, m_mpsArena,
		    mps_class_amcz(), args);
	}
	MPS_ARGS_END(args);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create leaf pool");

	/** Create AMC pool for objects. */
	MPS_ARGS_BEGIN (args) {
		MPS_ARGS_ADD(args, MPS_KEY_CHAIN, m_mpsChain);
		MPS_ARGS_ADD(args, MPS_KEY_FORMAT, m_mpsObjDescFmt);
		MPS_ARGS_ADD(args, MPS_KEY_ALIGN, 32);
		MPS_ARGS_DONE(args);
		res = mps_pool_create_k(&m_mpsObjDescPool, m_mpsArena,
		    mps_class_amc(), args);
	}
	MPS_ARGS_END(args);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create object pool");
}

ObjectMemoryOSThread::ObjectMemoryOSThread(ObjectMemory &omem, void *marker)
    : m_omem(omem)
{
	mps_res_t res;

	res = mps_ap_create_k(&m_mpsObjAP, omem.m_mpsObjDescPool,
	    mps_args_none);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create allocation point!");

	res = mps_ap_create_k(&m_mpsLeafObjAP, omem.m_mpsPrimDescPool,
	    mps_args_none);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create allocation point!");

	res = mps_thread_reg(&m_mpsThread, omem.m_mpsArena);
	if (res != MPS_RES_OK)
		FATAL("Couldn't register thread");

	res = mps_root_create_thread_tagged(&m_mpsThreadRoot, omem.m_mpsArena,
	    mps_rank_ambig(), 0, m_mpsThread, scanArea, 0, 0, marker);
	if (res != MPS_RES_OK)
		FATAL("Couldn't create root");
}

mps_res_t
PrimDesc::mpsScan(mps_ss_t ss, mps_addr_t base, mps_addr_t limit)
{
	printf("\n\n\nSCANNING PRIM\n\n\n");
	MPS_SCAN_BEGIN (ss) {
		while (base < limit) {
			base = mpsSkip(base);
		}
	}
	MPS_SCAN_END(ss);
	return MPS_RES_OK;
}

mps_addr_t
PrimDesc::mpsSkip(mps_addr_t base)
{
	PrimDesc *p = (PrimDesc *)base;

	printf("Skipping prim %p\n", base);

	switch (p->m_kind) {
	case kString:
	case kSymbol:
		if (p->m_strLen > 6)
			/** -6 not -7 due to final NULL */
			base = (PrimDesc *)((char *)p +
			    ALIGN(sizeof(PrimDesc) + p->m_strLen - 6));
		else
			base = ((char *)p + sizeof(PrimDesc));
		break;

	case kDouble:
	case kPad16:
	case kFwd16:
		base = (char*)p + sizeof(PrimDesc);;
		break;

	case kPad:
		base = (PrimDesc *)((char *)p +
		    ALIGN(sizeof(PrimDesc) + p->m_padLen));
		break;

	case kFwd:
		base = (PrimDesc *)((char *)p + p->m_fwdLength);
		break;

	default:
		printf("%p does not appear to be a true prim: kind %d\n", p, p->m_kind);
	}

	return base;
}

void
PrimDesc::mpsFwd(mps_addr_t old, mps_addr_t newAddr)
{
	PrimDesc *p = (PrimDesc *)old;
	mps_addr_t limit = mpsSkip(old);
	size_t size = (char *)limit - (char *)old;

	printf("Fwd Prim %p to %p\n", old, newAddr);

	assert(size >= sizeof(PrimDesc));
	if (size == sizeof(PrimDesc)) {
		p->m_kind = kFwd16;
		p->m_fwd = (PrimDesc *)newAddr;
	} else {
		p->m_kind = kFwd;
		p->m_fwdLength = size;
	}
}

mps_addr_t
PrimDesc::mpsIsFwd(mps_addr_t addr)
{
	PrimDesc *p = (PrimDesc *)addr;
	return (p->m_kind == kFwd || p->m_kind == kFwd16) ? p->m_fwd : NULL;
}

void
PrimDesc::mpsPad(mps_addr_t addr, size_t size)
{
	PrimDesc *p = (PrimDesc *)addr;

	printf("Pad Prim %p to %lu\n", addr, size);

	assert(size >= sizeof(PrimDesc));
	if (size == sizeof(PrimDesc))
		p->m_kind = kPad16;
	else {
		p->m_kind = kPad;
		p->m_padLen = size;
	}
}

#define FIXOOP(oop)                                                     \
	if (MPS_FIX1(ss, oop.m_full)) {                                 \
		if (oop.isPtr()) {                                      \
			/* Extract the tag  */                          \
			mps_word_t tag = oop.tag();                     \
			/* Untag */                                     \
			mps_addr_t ref = (mps_addr_t)oop.addrT<void>(); \
			mps_res_t res = MPS_FIX2(ss, &ref);             \
                                                                        \
			if (res != MPS_RES_OK)                          \
				return res;                             \
                                                                        \
			oop.m_full = (mps_word_t)ref | tag;             \
		}                                                       \
	}

mps_res_t
ObjectDesc::mpsScan(mps_ss_t ss, mps_addr_t base, mps_addr_t limit)
{
	gcDbg("** Scan Object");
	MPS_SCAN_BEGIN (ss) {
		while (base < limit) {
			ObjectDesc * obj = (ObjectDesc*)base;
			char *addr = (char *)base;

			switch (obj->m_kind) {
			case kFwd: {
				Fwd *fwd = (Fwd *)obj;
				base = addr + fwd->m_fwdLen;
				break;
			}

			case kPad: {
				Pad *pad = (Pad *)obj;
				base = addr + pad->m_padLen;
				break;
			}

			case kEnvironmentMap: {
				EnvironmentMap *map = (EnvironmentMap *)obj;
				size_t nEntries = map->m_nLocals + map->m_nParams;

				for (int i = 0;
				     i < map->m_nLocals + map->m_nParams; i++)
					FIXOOP(map->m_names[i]);

				base = addr + ALIGN(sizeof(EnvironmentMap) +
				    sizeof(Oop) * nEntries);

				break;
			}

			case kEnvironment: {
				Environment * env = (Environment*) obj;

				FIXOOP(env->m_prev);
				FIXOOP(env->m_map);
				FIXOOP(env->m_args);
				FIXOOP(env->m_locals);

				base = addr + ALIGN(sizeof(Environment));

				break;
			}

			case kPlainArray: {
				PlainArray * arr = (PlainArray*)obj;

				for (int i = 0; i < arr->m_nElements; i++)
					FIXOOP(arr->m_elements[i]);

				base = addr + ALIGN(sizeof(PlainArray) +
				    sizeof(Oop) * arr->m_nElements);

				break;
			}

			case kMap: {
				abort();
				break;
			}

			case kCharArray: {
				CharArray * arr = (CharArray*)obj;
				base = addr + ALIGN(sizeof(CharArray) +
				    sizeof(char) * arr->m_nElements);
				break;
			}

			/* these are pseudo for now but need to be promoted */
			case kFunction: {
				Function * fun = (Function*) obj;

				FIXOOP(fun->m_map);
				FIXOOP(fun->m_bytecode);
				FIXOOP(fun->m_literals);

				base = addr + ALIGN(sizeof(Function));

				break;
			}

			case kClosure: {
				Closure * closure = (Closure*) obj;

				FIXOOP(closure->m_baseEnv);
				FIXOOP(closure->m_func);

				base = addr + ALIGN(sizeof(Closure));

				break;
			}

			default: {
				printf("Bad Object\n");
				abort();
			}
			}
		}
	}
	MPS_SCAN_END(ss);
	return MPS_RES_OK;
}

mps_addr_t
ObjectDesc::mpsSkip(mps_addr_t base)
{
	gcDbg("Skip Object %p\n", base);
	ObjectDesc *obj = (ObjectDesc *)base;
	char *addr = (char *)obj;

	switch (obj->m_kind) {
	case kFwd: {
		Fwd *fwd = (Fwd *)obj;
		return addr + fwd->m_fwdLen;
	}

	case kPad: {
		Pad *pad = (Pad *)obj;
		return addr + pad->m_padLen;
	}

	case kEnvironmentMap: {
		EnvironmentMap *map = (EnvironmentMap *)obj;
		size_t nEntries = map->m_nLocals + map->m_nParams;
		return addr + ALIGN(sizeof(EnvironmentMap) + sizeof(Oop) *
		    nEntries);
	}

	case kEnvironment: {
		Environment *env = (Environment *)obj;
		return addr + ALIGN(sizeof(Environment));
	}

	case kPlainArray: {
		PlainArray *arr = (PlainArray *)obj;
		return addr + ALIGN(sizeof(PlainArray) + sizeof(Oop) *
		    arr->m_nElements);
	}

	case kMap: {
		abort();
	}

	case kCharArray: {
		CharArray *arr = (CharArray *)obj;
		return addr + ALIGN(sizeof(CharArray) + sizeof(char) *
		    arr->m_nElements);
	}

	/* these are pseudo for now but need to be promoted */
	case kFunction: {
		Function *fun = (Function *)obj;
		return addr + ALIGN(sizeof(Function));
	}

	case kClosure: {
		Closure *closure = (Closure *)obj;
		return addr + ALIGN(sizeof(Closure));
	}

	default:
		printf("Bad object %p\n", obj);
		abort();
	}
}

void
ObjectDesc::mpsFwd(mps_addr_t old, mps_addr_t newAddr)
{
	Fwd *p = (Fwd *)old;
	mps_addr_t limit = mpsSkip(old);
	size_t size = (char *)limit - (char *)old;

	gcDbg("Fwd Object %p to %p\n", old, newAddr);

	assert(size >= sizeof(Fwd));
	p->m_kind = kFwd;
	p->m_fwdLen = size;
}

mps_addr_t
ObjectDesc::mpsIsFwd(mps_addr_t addr)
{
	Fwd *p = (Fwd *)addr;
	return p->m_kind == kFwd ? p->m_fwdPtr : NULL;
}

void
ObjectDesc::mpsPad(mps_addr_t addr, size_t size)
{
	Pad *p = (Pad *)addr;

	gcDbg("Pad Obj %p to %lu\n", addr, size);

	assert(size >= sizeof(Pad));
	p->m_kind = kPad;
	p->m_padLen = size;
}

/**
 * An MPS area scanner; it scans the area between \p base and \p limit one word
 * at-a-time and submits it to MPS if it appears to be a pointer Oop.
 *
 * Though MPS_FIX2 is called, which can ordinarily update a pointer, it won't
 * happen here since this function is invoked for conservative scans.
 */
static mps_res_t
scanArea(mps_ss_t ss, void *base, void *limit, void *closure)
{
	printf("Scanning stack/register (region %p-%p)\n", base, limit);

	MPS_SCAN_BEGIN (ss) {
		mps_word_t *p = (mps_word_t *)base;
		while (p < (mps_word_t *)limit) {
			/* First check if this is of interest to MPS */
			if (MPS_FIX1(ss, *p)) {
				Oop* oop = (Oop *)p;
				printf("Found potential pointer %p\n", (void*)*p);
				if (oop->isPtr()) {
					/* Extract the tag  */
					mps_word_t tag = oop->tag();
					/* Untag */
					mps_addr_t ref = (mps_addr_t)
					    (oop->m_full ^ tag);
					mps_res_t res = MPS_FIX2(ss, &ref);

					if (res != MPS_RES_OK)
						return res;

					/*
					 * Should not be strictly-speaking
					 * necessary as this function should
					 * only be invoked for conservative
					 * scans that don't change references,
					 * but just in case, reapply the tag.
					 */
					*p = (mps_word_t)ref | tag;
				}
			}
			++p;
		}
	}
	MPS_SCAN_END(ss);

	return MPS_RES_OK;
}

mps_res_t
scanOopVec(mps_ss_t ss, void *p, size_t s)
{
	std::vector<Oop> *vec = (std::vector<Oop> *)p;

	MPS_SCAN_BEGIN (ss) {
		for (int i = 0; i < vec->size(); i++) {
			FIXOOP((*vec)[i]);
		}
	}
	MPS_SCAN_END(ss);

	return MPS_RES_OK;
}