;*---------------------------------------------------------------------------
;  :Program.	fmt_turrican2.s
;  :Contents.	decode/encode custom track format "Turrican 2" (Factor 5)
;  :Author.	Psygore
;  :Version	$Id: fmt_turrican2.s 1.5 2005/04/07 23:35:14 wepl Exp wepl $
;  :History.	15.14.02 created
;		02.11.02 rework for new sync-search
;		27.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $9521 (sync)
;   $2AAA (unused)
;   $1A90 mfm-words (data)
;   2 mfm-longwords (checksum)
;------------------------------------------

		dc.l	_decode_turrican2	;decode
		dc.l	_encode_turrican2	;encode
		dc.l	0			;info
		dc.l	_name_turrican2		;name
		dc.l	_sync_turrican1		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1A90			;datalen
		dc.w	4+($1A90*2)+8		;minimal rawlen
		dc.w	4+($1A90*2)+8		;writelen
		dc.w	TT_TURRICAN2		;type
		dc.w	0			;flags

_name_turrican2	dc.b	"turrican2",0
		EVEN

;----------------------------------------
; decode Turrican2 track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_turrican2
		move.w	#$1A90,d1
		bra	_decode_tur

;----------------------------------------
; encode Turrican 2 track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_turrican2
		move.w	#$1A90,d1
		bra	_encode_tur
