; GEOS KERNAL by Berkeley Softworks
; reverse engineered by Maciej Witkowiak, Michael Steil
;
; C64 keyboard driver

.include "const.inc"
.include "geossym.inc"
.include "geosmac.inc"
.include "kernal.inc"
.include "c64.inc"

; bitmask.s
.import BitMaskPow2

; var.s
.import KbdQueHead
.import KbdQueue
.import KbdQueTail
.import KbdDMltTab
.import KbdDBncTab
.import KbdNextKey
.import KbdQueFlag

; used by irq.s
.global _DoKeyboardScan

; used by mouse.s
.global KbdScanHelp3

; syscall
.global _GetNextChar

.segment "keyboard"

_DoKeyboardScan:
	lda KbdQueFlag
	bne @1
	lda KbdNextKey
	jsr KbdScanHelp2
	LoadB KbdQueFlag, 15
@1:	LoadB r1H, 0
	jsr KbdScanRow
	bne @5
	jsr KbdScanHelp5
	ldy #7
@2:	jsr KbdScanRow
	bne @5
	lda KbdTestTab,y
	sta cia1base+0
	lda cia1base+1
	cmp KbdDBncTab,y
	sta KbdDBncTab,y
	bne @4
	cmp KbdDMltTab,y
	beq @4
	pha
	eor KbdDMltTab,y
	beq @3
	jsr KbdScanHelp1
@3:	pla
	sta KbdDMltTab,y
@4:	dey
	bpl @2
@5:	rts

KbdScanRow:
	LoadB cia1base+0, $ff
	CmpBI cia1base+1, $ff
	rts

KbdScanHelp1:
	sta r0L
	LoadB r1L, 7
@1:	lda r0L
	ldx r1L
	and BitMaskPow2,x
	beq @A	; really dirty trick...
	tya
	asl
	asl
	asl
	adc r1L
	tax
	bbrf 7, r1H, @2
	lda KbdDecodeTab2,x
	bra @3
@2:	lda KbdDecodeTab1,x
@3:	sta r0H
	bbrf 5, r1H, @4
	lda r0H
	jsr KbdScanHelp6
	cmp #'A'
	bcc @4
	cmp #'Z'+1
	bcs @4
	subv $40
	sta r0H
@4:	bbrf 6, r1H, @5
	smbf_ 7, r0H
@5:	lda r0H
	sty r0H
	ldy #8
@6:	cmp KbdTab1,y
	beq @7
	dey
	bpl @6
	bmi @8
@7:	lda KbdTab2,y
@8:	ldy r0H
	sta r0H
	and #%01111111
	cmp #%00011111
	beq @9
	ldx r1L
	lda r0L
	and BitMaskPow2,x
	and KbdDMltTab,y
	beq @9
	LoadB KbdQueFlag, 15
	MoveB r0H, KbdNextKey
	jsr KbdScanHelp2
	bra @A
@9:	LoadB KbdQueFlag, $ff
	LoadB KbdNextKey, 0
@A:	dec r1L
	bmi @B
	jmp @1
@B:
	rts

KbdTab1:
	.byte $db, $dd, $de, $ad, $af, $aa, $c0, $ba, $bb
KbdTab2:
	.byte $7b, $7d, $7c, $5f, $5c, $7e, $60, $7b, $7d

KbdTestTab:
	.byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

KbdDecodeTab1:
	.byte KEY_DELETE, CR, KEY_RIGHT, KEY_F7, KEY_F1, KEY_F3, KEY_F5, KEY_DOWN
	.byte "3", "w", "a", "4", "z", "s", "e", KEY_INVALID
	.byte "5", "r", "d", "6", "c", "f", "t", "x"
	.byte "7", "y", "g", "8", "b", "h", "u", "v"
	.byte "9", "i", "j", "0", "m", "k", "o", "n"
	.byte "+", "p", "l", "-", ".", ":", "@", ","
	.byte KEY_BPS, "*", ";", KEY_HOME, KEY_INVALID, "=", "^", "/"
	.byte "1", KEY_LARROW, KEY_INVALID, "2", " ", KEY_INVALID, "q", KEY_STOP
KbdDecodeTab2:
	.byte KEY_INSERT, CR, BACKSPACE, KEY_F8, KEY_F2, KEY_F4, KEY_F6, KEY_UP
	.byte "#", "W", "A", "$", "Z", "S", "E", KEY_INVALID
	.byte "%", "R", "D", "&", "C", "F", "T", "X"
	.byte "'", "Y", "G", "(", "B", "H", "U", "V"
	.byte ")", "I", "J", "0", "M", "K", "O", "N"
	.byte "+", "P", "L", "-", ">", "[", "@", "<"
	.byte KEY_BPS, "*", "]", KEY_CLEAR, KEY_INVALID, "=", "^", "?"
	.byte "!", KEY_LARROW, KEY_INVALID, $22, " ", KEY_INVALID, "Q", KEY_RUN

KbdScanHelp2:
	php
	sei
	pha
	smbf KEYPRESS_BIT, pressFlag
	ldx KbdQueTail
	pla
	sta KbdQueue,x
	jsr KbdScanHelp4
	cpx KbdQueHead
	beq @1
	stx KbdQueTail
@1:	plp
	rts

KbdScanHelp3:
	php
	sei
	ldx KbdQueHead
	lda KbdQueue,x
	sta keyData
	jsr KbdScanHelp4
	stx KbdQueHead
	cpx KbdQueTail
	bne @2
	rmb KEYPRESS_BIT, pressFlag
@2:	plp
	rts

KbdScanHelp4:
	inx
	cpx #16
	bne @1
	ldx #0
@1:	rts

;---------------------------------------------------------------
;---------------------------------------------------------------
_GetNextChar:
	bbrf KEYPRESS_BIT, pressFlag, @1
	jmp KbdScanHelp3
@1:	lda #0
	rts

KbdScanHelp5:
	LoadB cia1base+0, %11111101
	lda cia1base+1
	eor #$ff
	and #%10000000
	bne @1
	LoadB cia1base+0, %10111111
	lda cia1base+1
	eor #$ff
	and #%00010000
	beq @2
@1:	smbf 7, r1H
@2:	LoadB cia1base+0, %01111111
	lda cia1base+1
	eor #$ff
	and #%00100000
	beq @3
	smbf 6, r1H
@3:	LoadB cia1base+0, %01111111
	lda cia1base+1
	eor #$ff
	and #%00000100
	beq @4
	smbf 5, r1H
@4:	rts

KbdScanHelp6:
	pha
	and #%01111111
	cmp #'a'
	bcc @1
	cmp #'z'+1
	bcs @1
	pla
	subv $20
	pha
@1:	pla
	rts

