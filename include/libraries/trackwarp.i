;*---------------------------------------------------------------------------
;  :Module.	trackwarp.i
;  :Contens.	include file for trackwarp.library
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :Version.	$Id: trackwarp.i 1.3 2005/07/13 16:39:24 wepl Exp wepl $
;  :History.	13.10.04 started
;		13.07.05 TWT_MFM added
;  :Language.	68000 Assembler
;---------------------------------------------------------------------------*

 IFND TRACKWARP_I
TRACKWARP_I=1

	IFND	EXEC_TYPES_I
	INCLUDE	exec/types.i
	ENDC

;=============================================================================
;	trackwarp track info
;=============================================================================

	STRUCTURE	TrackWarpTrackInfo,0
		ULONG	twti_flags
		ULONG	twti_length		;length of track data in bits
		UWORD	twti_type		;type of track
		UWORD	twti_sync		;mfm sync word
		LABEL	twti_SIZEOF

	BITDEF	TWTI,INDEX,0			;track data starts with index signal
	BITDEF	TWTI,RAWSINGLE,1		;raw mfm data is saved in exact bit length

;=============================================================================
;	trackwarp file types
;=============================================================================

		ENUM	1
		EITEM	TWT_ADF			;plain diskimage 901120 bytes
		EITEM	TWT_UAEADF		;special UAE DOS/MFM images (factor5 stuff)
		EITEM	TWT_UAE1ADF		;special UAE DOS/MFM images (with write support)
		EITEM	TWT_IPF			;CAPS/IPF (*.ipf)
		EITEM	TWT_WWARP		;WWarp (*.wwp)
		EITEM	TWT_MFMWARP		;MFMWarp Ferox (*.mfm)
		EITEM	TWT_NOMAD		;N.O.M.A.D Warp (*.wrp)
		EITEM	TWT_MFM			;unknown warper (*.mfm)

;=============================================================================
;	trackwarp track types
;=============================================================================

		ENUM	1
		EITEM	TWTT_RAW		;raw mfm data
		EITEM	TWTT_DOS		;AmigaDOS
		EITEM	TWTT_undefined		;dummy, end of list

;=============================================================================
;	trackwarp errors
;=============================================================================

TWE_MINERRORCODE	= 1000

		ENUM	TWE_MINERRORCODE
		EITEM	TWE_ArgErr		;invalid arguments
		EITEM	TWE_UnknownFileType	;alien file format
		EITEM	TWE_NoMsgPort
		EITEM	TWE_NoIoReq
		EITEM	TWE_NoCAPSDev
		EITEM	TWE_NoReadRaw
		EITEM	TWE_NoReadForm
		EITEM	TWE_WrongFormat
		EITEM	TWE_TrackNotPresent
		EITEM	TWE_InternalBufferSmall
		EITEM	TWE_BufferSmall
		EITEM	TWE_CheckSum
		EITEM	TWE_Alignment
		EITEM	TWE_CAPSInit
		EITEM	TWE_CAPSAddImage
		EITEM	TWE_CAPSLockImage
		EITEM	TWE_CAPSLockTrack
		EITEM	TWE_CAPSGetImageInfo
		EITEM	TWE_UAE1ADF_FormatError
		EITEM	TWE_NOMAD_HeaderError
		EITEM	TWE_NOMAD_StructError
		EITEM	TWE_NOMAD_FormatError
		EITEM	TWE_NOMAD_Unpack
		EITEM	TWE_NOMAD_PackMode
		EITEM	TWE_MFMWARP_StructError
		EITEM	TWE_MFMWARP_FormatError
		EITEM	TWE_MFMWARP_DIPUnpack
		EITEM	TWE_MFMWARP_MC1Unpack
		EITEM	TWE_XpkLibMissing
		EITEM	TWE_XpkSubLibMissing
		EITEM	TWE_XpkUnpack
		EITEM	TWE_WWARP_BadFileVersion
		EITEM	TWE_WWARP_BadTTVersion	;track table version
		EITEM	TWE_WWARP_BadTHVersion	;track header version
		EITEM	TWE_WWARP_StructError
		EITEM	TWE_WWARP_UnknownTrackType
		EITEM	TWE_WWARP_NoTrackEncoder
		EITEM	TWE_WWARP_ErrorTrackEncoder
		EITEM	TWE_undefined		;dummy, end of list


;=============================================================================

 ENDC
