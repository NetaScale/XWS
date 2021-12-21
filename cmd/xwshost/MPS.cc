
#include "Object.h"

extern "C" {
#include "mps.h"
#include "mpstd.h" /* for MPS_BUILD_MV */
}

/**
 * An MPS area scanner; it scans the area between \p base and \p limit one word
 * at-a-time and submits it to MPS if it appears to be a pointer Oop.
 *
 * As this is used for conservative scanning of stack and registers, it must be
 * liberal and submit Oops regardless of whether they are marked as pointers or
 * not, as optimising compilers may remove the tag component of pointers for an
 * optimisation.
 *
 * Though MPS_FIX2 is called, which can ordinarily update a pointer, it won't
 * happen here since this function is invoked for conservative scans.
 */
mps_res_t
scanArea(mps_ss_t ss, void *base, void *limit, void *closure)
{
	MPS_SCAN_BEGIN (ss) {
		mps_word_t *p = (mps_word_t *)base;
		while (p < (mps_word_t *)limit) {
			/* First check if this is of interest to MPS */
			if (MPS_FIX1(ss, p)) {
				Oop word = (Oop *)*p;
				/* if (word.isPtr()) { */
				/* Extract the tag  */
				mps_word_t tag = word.ptrType();
				mps_addr_t ref = (mps_addr_t)(word.m_full ^
				    tag);
				mps_res_t res = MPS_FIX2(ss, &ref);

				if (res != MPS_RES_OK)
					return res;

				/*
				 * Should not be strictly-speaking necessary as
				 * this function should only be invoked for
				 * conservative scans that don't change
				 * references, but just in case, reapply the
				 * tag.
				 */
				*p = (mps_word_t)ref | tag;
				/* } */
			}
			++p;
		}
	}
	MPS_SCAN_END(ss);

	return MPS_RES_OK;
}