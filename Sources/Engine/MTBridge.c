#include "MTBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>

typedef struct { float x, y; } mtPoint;
typedef struct { mtPoint pos, vel; } mtReadout;
typedef struct {
    int frame;
    double timestamp;
    int identifier, state, fingerID, handID;
    mtReadout normalized;
    float size;
    int zero1;
    float angle, majorAxis, minorAxis;
    mtReadout mm;
    int zero2[2];
    float unk2;
} MTFinger;

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, MTFinger *, int, double, int);

static CFMutableArrayRef (*pCreateList)(void);
static void (*pRegister)(MTDeviceRef, MTContactCallback);
static void (*pUnregister)(MTDeviceRef, MTContactCallback);
static int (*pStart)(MTDeviceRef, int);
static int (*pStop)(MTDeviceRef);
static bool (*pIsBuiltIn)(MTDeviceRef);
static int (*pGetFamilyID)(MTDeviceRef, int *);
static int (*pGetDims)(MTDeviceRef, int *, int *);

static pthread_mutex_t gLock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableArrayRef gDevices;
static MTBTouchHandler gHandler;
static int gLoadState; // 0 = not tried, 1 = ok, -1 = failed

#define MTB_MAX_TOUCHES 32

static bool load(void) {
    if (gLoadState) return gLoadState > 0;
    gLoadState = -1;
    void *h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!h) return false;
    pCreateList = dlsym(h, "MTDeviceCreateList");
    pRegister = dlsym(h, "MTRegisterContactFrameCallback");
    pUnregister = dlsym(h, "MTUnregisterContactFrameCallback");
    pStart = dlsym(h, "MTDeviceStart");
    pStop = dlsym(h, "MTDeviceStop");
    pIsBuiltIn = dlsym(h, "MTDeviceIsBuiltIn");
    pGetFamilyID = dlsym(h, "MTDeviceGetFamilyID");
    pGetDims = dlsym(h, "MTDeviceGetSensorSurfaceDimensions");
    if (!pCreateList || !pRegister || !pStart) return false;
    gLoadState = 1;
    return true;
}

static int contactCallback(MTDeviceRef dev, MTFinger *fingers, int count, double ts, int frame) {
    (void)frame;
    pthread_mutex_lock(&gLock);
    MTBTouchHandler handler = gHandler;
    int32_t index = -1;
    if (gDevices) {
        CFIndex n = CFArrayGetCount(gDevices);
        for (CFIndex i = 0; i < n; i++) {
            if (CFArrayGetValueAtIndex(gDevices, i) == dev) { index = (int32_t)i; break; }
        }
    }
    pthread_mutex_unlock(&gLock);
    if (!handler || index < 0) return 0;

    MTBTouch buf[MTB_MAX_TOUCHES];
    int n = count < MTB_MAX_TOUCHES ? count : MTB_MAX_TOUCHES;
    for (int i = 0; i < n; i++) {
        buf[i].identifier = fingers[i].identifier;
        buf[i].state = fingers[i].state;
        buf[i].x = fingers[i].normalized.pos.x;
        buf[i].y = fingers[i].normalized.pos.y;
        buf[i].size = fingers[i].size;
        buf[i].angle = fingers[i].angle;
    }
    handler(index, buf, n, ts);
    return 0;
}

bool MTBAvailable(void) { return load(); }

int32_t MTBStart(MTBTouchHandler handler) {
    if (!load()) return -1;
    MTBStop();
    CFMutableArrayRef list = pCreateList();
    if (!list) return 0;
    pthread_mutex_lock(&gLock);
    gDevices = list;
    gHandler = handler;
    pthread_mutex_unlock(&gLock);
    CFIndex n = CFArrayGetCount(list);
    for (CFIndex i = 0; i < n; i++) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(list, i);
        pRegister(dev, contactCallback);
        pStart(dev, 0);
    }
    return (int32_t)n;
}

void MTBStop(void) {
    pthread_mutex_lock(&gLock);
    CFMutableArrayRef list = gDevices;
    gDevices = NULL;
    gHandler = NULL;
    pthread_mutex_unlock(&gLock);
    if (!list) return;
    CFIndex n = CFArrayGetCount(list);
    for (CFIndex i = 0; i < n; i++) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(list, i);
        if (pUnregister) pUnregister(dev, contactCallback);
        if (pStop) pStop(dev);
    }
    // The old list is intentionally not released: MultitouchSupport may still be
    // delivering a final frame on its own thread. Rescans are rare, so the leak is tiny.
}

int32_t MTBDeviceCount(void) {
    pthread_mutex_lock(&gLock);
    int32_t n = gDevices ? (int32_t)CFArrayGetCount(gDevices) : 0;
    pthread_mutex_unlock(&gLock);
    return n;
}

int32_t MTBProbeDeviceCount(void) {
    if (!load()) return -1;
    CFMutableArrayRef list = pCreateList();
    if (!list) return 0;
    int32_t n = (int32_t)CFArrayGetCount(list);
    CFRelease(list);
    return n;
}

bool MTBGetDeviceInfo(int32_t index, MTBDeviceInfo *out) {
    if (!out) return false;
    pthread_mutex_lock(&gLock);
    bool ok = gDevices && index >= 0 && index < CFArrayGetCount(gDevices);
    if (ok) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(gDevices, index);
        int family = 0, w = 0, h = 0;
        if (pGetFamilyID) pGetFamilyID(dev, &family);
        if (pGetDims) pGetDims(dev, &w, &h);
        out->index = index;
        out->builtIn = pIsBuiltIn ? pIsBuiltIn(dev) : false;
        out->familyID = family;
        out->width = w;
        out->height = h;
    }
    pthread_mutex_unlock(&gLock);
    return ok;
}
