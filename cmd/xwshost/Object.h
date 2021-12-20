#ifndef OBJECT_H_
#define OBJECT_H_

#include <stdint.h>

/**
 * Object Representation
 * =====================
 *
 * Oops
 * ----
 * An Oop (Object-Oriented Pointer) is the basic value type. On both 32-bit and
 * 64-bit platforms, these are tagged pointers with the lowest 3 bits for a tag.
 * If the least significant bit is 1, then is is a pointer, and the remaining 2
 * 2 bits encode the type of the heap object to which they point: 0 for a
 * Double, 1 for String, 2 for Symbol, and 3 for any other sort of heap object.
 *
 * Heap Objects
 * ------------
 * These include both primitives and proper Objects.
 */

#endif /* OBJECT_H_ */
