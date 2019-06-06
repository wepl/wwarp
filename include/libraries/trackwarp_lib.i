;*---------------------------------------------------------------------------
;  :Module.	trackwarp_lib.i
;  :Contens.	include file for trackwarp.library
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :Version.	$Id: trackwarp_lib.i 1.1 2005/03/10 07:51:05 wepl Exp wepl $
;  :History.	03.01.05 started
;  :Language.	68000 Assembler
;---------------------------------------------------------------------------*

	IFND LIBRARIES_TRACKWARP_LIB_I
LIBRARIES_TRACKWARP_LIB_I	SET	1

_LVOtwOpen		EQU	-30
_LVOtwClose		EQU	-36
_LVOtwReadRaw		EQU	-42
_LVOtwReadForm		EQU	-48
_LVOtwAllocTrackInfo	EQU	-54
_LVOtwFreeTrackInfo	EQU	-60
_LVOtwTrackInfo		EQU	-66
_LVOtwFault		EQU	-72

	ENDC
