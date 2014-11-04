#include "kernel.inc"
#include "corelib.inc"
    .db "KEXC"
    .db KEXC_ENTRY_POINT
    .dw start
    .db KEXC_STACK_SIZE
    .dw 100
    .db KEXC_NAME
    .dw program_name
    .db KEXC_HEADER_END
program_name:
    .db "Hello world!", 0
start:
    ; Get a lock on some hardware
    pcall(getLcdLock)
    pcall(getKeypadLock)

    ; Load corelib
    kld(de, corelib_path)
    pcall(loadLibrary)

    ; Allocate a display buffer
    pcall(allocScreenBuffer)
    pcall(clearBuffer)

    ; Draw a window
    xor a ; ld a, 0
    kld(hl, window_title)
    corelib(drawWindow)

    ; Draw "Hello, world!"
    ld b, 2
    ld de, 2 << 8 | 8
    kld(hl, window_title)
    pcall(drawStr)

.idle_loop:
    pcall(fastCopy)
    corelib(appWaitKey)
    cp kMODE
    ret z
    jr .idle_loop

window_title:
    .db "Hello, world!", 0
corelib_path:
    .db "/lib/core", 0
