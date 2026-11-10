#include <AE/AE.h>

static int verbose = 0;
__attribute__((constructor)) static void initme(void) {
    verbose = getenv("STUB_VERBOSE") != NULL;
}

OSErr AECreateDesc(DescType typeCode, const void *dataPtr, Size dataSize, AEDesc *result) {
    if (verbose) puts("STUB: AECreateDesc called");
    return noErr;
}

OSErr AEDisposeDesc(AEDesc *theAEDesc) {
    if (verbose) puts("STUB: AEDisposeDesc called");
    return noErr;
}

OSErr AEInstallEventHandler(
  AEEventClass theAEEventClass,
  AEEventID theAEEventID,
  AEEventHandlerUPP handler,
  SRefCon handlerRefcon,
  Boolean isSysHandler
) {
    if (verbose) puts("STUB: AEInstallEventHandler called");
    return noErr;
}

/* OSXER APPS (Apple Events): initialize all output descriptors before failing. */
#include <darling/osxer-apps.h>
void AEInitializeDesc(AEDesc *desc) {
    if (desc) { desc->descriptorType = 'null'; desc->dataHandle = NULL; }
}
OSErr AECoercePtr(DescType type, const void *data, Size size, DescType desiredType, AEDesc *result) {
    OSXER_APPS_STUB("descriptor coercion unavailable");
    AEInitializeDesc(result);
    if (!result || size < 0 || (size && !data)) return paramErr;
    return errAECoercionFail;
}
OSStatus AESendMessage(const AppleEvent *event, AppleEvent *reply, AESendMode mode, long timeout) {
    OSXER_APPS_STUB("Apple Event delivery unavailable");
    AEInitializeDesc(reply);
    return event ? errAEEventNotHandled : paramErr;
}
OSStatus AEBuildAppleEvent(AEEventClass eventClass, AEEventID eventID, DescType addressType,
    const void *address, Size addressSize, AEReturnID returnID, AETransactionID transactionID,
    AppleEvent *result, AEBuildError *error, const char *format, ...) {
    OSXER_APPS_STUB("Apple Event format parsing unavailable");
    AEInitializeDesc(result);
    if (error) { error->fError = 0; error->fErrorPos = 0; }
    if (!result || !format || addressSize < 0 || (addressSize && !address)) return paramErr;
    return errAEEventNotHandled;
}
