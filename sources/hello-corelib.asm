; This example is like the "hello world" example, but it uses corelib to draw
; a KnightOS GUI window around the message.

#include "kernel.inc"
#include "corelib.inc"
    .db "KEXC"
    .db KEXC_ENTRY_POINT
    .dw start
    .db KEXC_STACK_SIZE
    .dw 100
    .db KEXC_HEADER_END
window_title:
    .db "Hello, Title!", 0
hello_world_message:
    .db "Hello, world!", 0 ; <--- Try changing this string
corelib_path:
    .db "/lib/core", 0 ; Path to corelib in the filesystem
start:
    pcall(getLcdLock)
    pcall(allocScreenBuffer)
    pcall(clearBuffer)

    ; Load corelib
    kld(de, corelib_path)
    pcall(loadLibrary)

    ; Draw a corelib GUI window
    kld(hl, window_title)
    xor a
    corelib(drawWindow)

    ; Draw "Hello, world!"
    ld de, 0x0208 ; D, E == X, Y
    kld(hl, hello_world_message)
    pcall(drawStr)

    ; Copy buffer to display
    pcall(fastCopy)
    jr $ ; hang
