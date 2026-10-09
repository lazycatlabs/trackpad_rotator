// Thin C bridge over Apple's private MultitouchSupport.framework.
// Loaded with dlopen at runtime so the app still launches if it's missing.
#ifndef MTBRIDGE_H
#define MTBRIDGE_H
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    int32_t identifier;
    int32_t state;   // 1..7; 3,4,5 mean the finger is touching the surface
    float x;         // normalized 0..1, left -> right
    float y;         // normalized 0..1, bottom -> top
    float size;
    float angle;
} MTBTouch;

typedef struct {
    int32_t index;
    bool builtIn;
    int32_t familyID;
    int32_t width;   // sensor surface in 1/100 mm (0 if unknown)
    int32_t height;
} MTBDeviceInfo;

typedef void (*MTBTouchHandler)(int32_t deviceIndex, const MTBTouch *touches, int32_t count, double timestamp);

bool MTBAvailable(void);
/// Starts listening on every multitouch device. Returns device count, or -1 if unavailable.
int32_t MTBStart(MTBTouchHandler handler);
void MTBStop(void);
/// Number of devices currently being listened to.
int32_t MTBDeviceCount(void);
/// Fresh enumeration, used to detect devices being connected/disconnected.
int32_t MTBProbeDeviceCount(void);
bool MTBGetDeviceInfo(int32_t index, MTBDeviceInfo *out);

#endif
