#ifndef __AE_H__
#define __AE_H__

#include <AE/AEDataModel.h>
#include <AE/AppleEvents.h>

OSErr AECreateDesc(DescType typeCode, const void *dataPtr, Size dataSize, AEDesc *result);
OSErr AEDisposeDesc(AEDesc *theAEDesc);


/* OSXER APPS (Apple Events): public ABI, with unsupported operations explicit. */
#ifdef __cplusplus
extern "C" {
#endif
typedef struct AEBuildError { UInt32 fError; UInt32 fErrorPos; } AEBuildError;
void AEInitializeDesc(AEDesc *desc);
OSErr AECoercePtr(DescType type, const void *data, Size size, DescType desiredType, AEDesc *result);
OSStatus AESendMessage(const AppleEvent *event, AppleEvent *reply, AESendMode mode, long timeout);
OSStatus AEBuildAppleEvent(AEEventClass eventClass, AEEventID eventID, DescType addressType,
    const void *address, Size addressSize, AEReturnID returnID, AETransactionID transactionID,
    AppleEvent *result, AEBuildError *error, const char *format, ...);
#ifdef __cplusplus
}
#endif

#endif /* __AE_H__ */
