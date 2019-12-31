//
//  OSActivityShims.h
//  Etcetera
//
//  Created by Jared Sinclair on 5/10/18.
//

#ifndef etcetera_os_activity_shims_h
#define etcetera_os_activity_shims_h

#include <os/activity.h>
#include <os/log.h>

OS_INLINE OS_ALWAYS_INLINE
os_activity_t _Nonnull _etcetera_os_activity_none(void) {
    return OS_ACTIVITY_NONE;
}

OS_INLINE OS_ALWAYS_INLINE
os_activity_t _Nonnull _etcetera_os_activity_current(void) {
    return OS_ACTIVITY_CURRENT;
}

OS_INLINE OS_ALWAYS_INLINE
_Nonnull os_activity_t _etcetera_os_activity_create(const void *_Nonnull dso, const uint8_t *_Nullable description, os_activity_t _Nonnull parent, uint32_t flags) {
    // Use the internal version because the public-facing one is actually a
    // preprocessor macro not accessible to Swift.
    return _os_activity_create((void *)dso, (const char *)description, parent, flags);
}

OS_INLINE OS_ALWAYS_INLINE
void _etcetera_os_activity_label_useraction(const void *_Nonnull dso, const uint8_t *_Nullable name) {
    // Use the internal version because the public-facing one is actually a
    // preprocessor macro not accessible to Swift.
    _os_activity_label_useraction((void *)dso, (const char *)name);
}

OS_INLINE OS_ALWAYS_INLINE
void _etcetera_os_activity_scope_enter(os_activity_t _Nonnull activity, os_activity_scope_state_t _Nonnull state) {
    os_activity_scope_enter(activity, state);
}

OS_INLINE OS_ALWAYS_INLINE
void _etcetera_os_activity_scope_leave(os_activity_scope_state_t _Nonnull state) {
    os_activity_scope_leave(state);
}

#endif /* etcetera_os_activity_shims_h */
