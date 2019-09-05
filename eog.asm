    processor 6502

    include "vcs.h"
    include "macro.h"

;;; ---------------------------------------------------------------------------
;;; Define vars starting from mem address $80
    seg.u vars
    org $80

PxPos               byte        ; player x position
PyPos               byte        ; player y position
PSpritePtr          word        ; pointer to player sprite
PColorPtr           word        ; pointer to player color

;;; ---------------------------------------------------------------------------
;;; Define constants
P_HEIGHT = 8                    ; Number of rows in lookup table

;;; ---------------------------------------------------------------------------
;;; Start ROM code at mem address $F000
    seg Code
    org $F000

Reset:
    CLEAN_START                 ; macro to clean mem and registers

;;; ---------------------------------------------------------------------------
;;; Init RAM vars and TIA registers
    lda #50
    sta PyPos                   ; player y position = 50

    lda #65                     ; player x position = 65
    sta PxPos

;;; ---------------------------------------------------------------------------
;;; Init pointers to correct lookup table addresses
    lda #<PSprite
    sta PSpritePtr              ; low byte pointer for sprite lookup table
    lda #>PSprite
    sta PSpritePtr+1            ; high byte pointer for sprite lookup table
    lda #<PColor
    sta PColorPtr               ; low byte pointer for color lookup table
    lda #>PColor
    sta PColorPtr+1             ; high byte pointer for color lookup table

;;; ---------------------------------------------------------------------------
;;; Main display loop
StartFrame:

;;; ---------------------------------------------------------------------------
;;; Tasks performed before VBLANK
    lda PxPos
    ldy #0
    jsr SetObjXPos              ; set player horizontal position
    sta WSYNC
    sta HMOVE                   ; apply the horizontal offset set before

;;; ---------------------------------------------------------------------------
;;; Display VSYNC and VBLANK
    lda #02
    sta VBLANK                  ; VBLANK on
    sta VSYNC                   ; VSYNC on
    REPEAT 3
        sta WSYNC               ; 3 scanlines for VSYNC
    REPEND
    lda #0
    sta VSYNC                   ; VSYNC off
    REPEAT 37
        sta WSYNC
    REPEND
    sta VBLANK                  ; VBLANK off

;;; ---------------------------------------------------------------------------
;;; 192 visible scanlines
VisibleLines:
    lda #$00
    sta COLUBK                  ; BG color to black
    lda #$1C
    sta COLUPF                  ; playfield color yellow
    lda #%00000001
    sta CTRLPF                  ; playfield reflection
    lda #$F0
    sta PF0                     ; PF0 bit pattern
    lda #$FB
    sta PF1
    lda #0
    sta PF2

    ldx #192                    ; number of remaining scanlines
.GameLineLoop:
.OnPSprite:
    txa                         ; transfer X to A
    sec                         ; checks if carry flag is set before subtraction
    sbc PyPos                   ; subtract sprite Y
    cmp P_HEIGHT                ; inside the sprite height bounds
    bcc .DrawP                  ; if result < player height call draw subroutine
    lda #0
.DrawP:
    tay                         ; load Y to work with the pointer
    lda (PSpritePtr),Y          ; load player data from lookup table
    sta WSYNC                   ; wait scanline
    sta GRP0                    ; set graphics for the player
    lda (PColorPtr),Y           ; load player color from lookup table
    sta COLUP0                  ; set color of the player

    dex                         ; X--
    bne .GameLineLoop           ; repeat next main game scanline until finished

;;; ---------------------------------------------------------------------------
;;; Overscan
    lda #2
    sta VBLANK                  ; VBLANK on
    REPEAT 30
        sta WSYNC               ; 30 scanlines for VBLANK Overscan
    REPEND
    lda #0
    sta VBLANK                  ; VBLANK off

;;; ---------------------------------------------------------------------------
;;; joystick input
CheckPUP:
    lda #%00010000              ; player up
    bit SWCHA
    bne CheckPDown              ; if doesn't match, bypass up
    inc PyPos
CheckPDown:
    lda #%00100000              ; player down
    bit SWCHA
    bne CheckPLeft              ; if doesn't match, bypass down
    dec PyPos
CheckPLeft:
    lda #%01000000              ; player left
    bit SWCHA
    bne CheckPRight              ; if doesn't match, bypass left
    dec PxPos
CheckPRight:
    lda #%10000000              ; player right
    bit SWCHA
    bne CheckNoInput            ; if doesn't match, bypass right
    inc PxPos
CheckNoInput:                   ; fallback when no input

;;; ---------------------------------------------------------------------------
;;; Loop back to start frame
    jmp StartFrame              ; To display the next frame

;;; ---------------------------------------------------------------------------
;;; Handles object horizontal position
SetObjXPos subroutine
    sta WSYNC                   ; start a new scanline
    sec                         ; checks carry flag before subtraction
.DivLoop
    sbc #15                     ; minus 15 from the accumulator
    bcs .DivLoop                ; loop until carry flag clear
    eor #7                      ; handle offset range from -8 to 7
    REPEAT 4                    ; 4 shift left to get the top 4 bits
        asl
    REPEND
    sta HMP0,Y                  ; store the fine offset to the correct register
    sta RESP0,Y                 ; fix obj position in 15 step increment
    rts

;;; ----------------------------------------------------- ----------------------
;;; ROM Lookup tables
PSprite:
    .byte #%00000000
    .byte #%00000000
    .byte #%00000000
    .byte #%00111100
    .byte #%00111100
    .byte #%00111100
    .byte #%00111100
    .byte #%00000000
    .byte #%00000000
PColor:
    .byte #$1A
    .byte #$1A
    .byte #$1A
    .byte #$1A
    .byte #$1A
    .byte #$1A
    .byte #$1A
    .byte #$1A

;;; ---------------------------------------------------------------------------
;;; Complete ROM size with 4KB
    org $FFFC                   ; Move to position $FFF
    .word Reset                 ; Write 2 bytes with the program reset address
    .word Reset                 ; Write 2 bytes with the interruption vector
