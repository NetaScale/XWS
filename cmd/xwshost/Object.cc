#include "Object.inl.hh"

void
Oop::print() const
{
	switch (type()) {
	case kSmi:
		printf("smi:%d", asI32());
		break;

	case kDouble:
		printf("dbl:%lf", *dblAddr());
		break;

	case kUndefined:
		printf("undefined");
		break;

	case kNull:
		printf("null");
		break;

	case kBoolean:
		printf("bool");
		break;

	case kBigInt:
		printf("bigint");
		break;

	case kSymbol:
		printf("sym:%s", addrT<PrimDesc>()->m_str);
		break;

	case kString:
		printf("str:%s", addrT<PrimDesc>()->m_str);
		break;

	case kObject:
		printf("object:%d", addrT<ObjectDesc>()->m_kind);
		break;
	}
}