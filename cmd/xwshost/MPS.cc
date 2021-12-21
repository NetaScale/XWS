#include <cassert>
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
		MPS_ARGS_ADD(args, MPS_KEY_FMT_SCAN, PrimDesc::mpsScan);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_SKIP, PrimDesc::mpsSkip);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_FWD, PrimDesc::mpsFwd);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_ISFWD, PrimDesc::mpsIsFwd);
		MPS_ARGS_ADD(args, MPS_KEY_FMT_PAD, PrimDesc::mpsPad);
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

#define ALIGNMENT 16
#define ALIGN(size) (((size) + ALIGNMENT - 1) & ~(ALIGNMENT - 1))

mps_res_t
PrimDesc::mpsScan(mps_ss_t ss, mps_addr_t base, mps_addr_t limit)
{
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

	switch (p->m_kind) {
	case kString:
	case kSymbol:
		if (p->m_len > 4)
			/** -6 not -7 due to final NULL */
			p = (PrimDesc *)((char *)p +
			    ALIGN(sizeof(PrimDesc) + p->m_len - 6));
		else
			base = (char *)base + sizeof(PrimDesc);

	case kDouble:
	case kPad16:
	case kFwd16:
		p++;

	case kPad:
		p = (PrimDesc *)((char *)p +
		    ALIGN(sizeof(PrimDesc) + p->m_len - 3));

	case kFwd:
		p = (PrimDesc *)((char *)p + p->m_fwdLength);
	}

	return p;
}

void
PrimDesc::mpsFwd(mps_addr_t old, mps_addr_t newAddr)
{
	PrimDesc *p = (PrimDesc *)old;
	mps_addr_t limit = mpsSkip(old);
	size_t size = (char *)limit - (char *)old;

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

	assert(size >= sizeof(PrimDesc));
	if (size == sizeof(PrimDesc))
		p->m_kind = kPad16;
	else {
		p->m_kind = kPad;
		p->m_len = size;
	}
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
	MPS_SCAN_BEGIN (ss) {
		mps_word_t *p = (mps_word_t *)base;
		while (p < (mps_word_t *)limit) {
			/* First check if this is of interest to MPS */
			if (MPS_FIX1(ss, p)) {
				Oop word = (Oop *)*p;
				if (word.isPtr()) {
					/* Extract the tag  */
					mps_word_t tag = word.tag();
					/* Untag */
					mps_addr_t ref = (mps_addr_t)
					    (word.m_full ^ tag);
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