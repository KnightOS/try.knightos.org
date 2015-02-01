#include "kernel.inc"
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

    xor a

.idle_loop:
    ; Allocate a display buffer
    pcall(allocScreenBuffer)
    pcall(clearBuffer)

    ld de, 0x0010
    pcall(drawHexA)
    
    ; Draw "Hello, world!"
    ld de, 0x0000
    kld(hl, window_title)
    pcall(drawStr)
    
    pcall(fastCopy)
    pcall(flushKeys)
    pcall(waitKey)
    cp kMODE
    ret z
    jr .idle_loop

window_title:
    .db "Hello, world!", 0
