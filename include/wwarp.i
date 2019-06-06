;*---------------------------------------------------------------------------
;  :Module.	wwarp.i
;  :Contens.	include file for the WWarp file format
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :Version.	$Id: wwarp.i 1.12 2006/01/30 21:21:00 wepl Exp wepl $
;  :History.	23.04.02 separated from WWarp.asm
;		01.11.02 TF_SLEQ added
;		21.12.03 TT_GOLIATH added (Codetapper)
;		01.01.04 TT_THALAMUS added (Codetapper)
;		09.01.04 TT_BEYOND added (Codetapper)
;		30.01.06 TT_SLACKSKIN added (Codetapper)
;  :Language.	68000 Assembler
;---------------------------------------------------------------------------*

 IFND WWARP_I
WWARP_I=1

	IFND	EXEC_TYPES_I
	INCLUDE	exec/types.i
	ENDC
	IFND	DOS_DATETIME_I
	INCLUDE	dos/datetime.i
	ENDC

;=============================================================================
;	File Header
;=============================================================================

FILEID		= "WWRP"
FILEVER		= 1
CREATORLEN	= 42

	STRUCTURE	WWarpFileHeader,0
		ULONG	wfh_id			;FILEID
		UWORD	wfh_ver			;structure format version
		STRUCT	wfh_creator,CREATORLEN	;creator of wwarp file
		STRUCT	wfh_ctime,ds_SIZEOF	;date of creation
		STRUCT	wfh_mtime,ds_SIZEOF	;date of last modification
		LABEL	wfh_SIZEOF

;=============================================================================
;	Track Table Header
;=============================================================================

TABLEID		= "TABL"
TABLEVER	= 1

	STRUCTURE	WWarpTrackTable,0
		ULONG	wtt_id			;TABLEID
		UWORD	wtt_ver			;structure format version
		UWORD	wtt_first		;first track in list
		UWORD	wtt_last		;last track in list
		LABEL	wtt_tab			;track table, one bit for each track,
						;length depends on wtt_first and wtt_last!
;=============================================================================
;	Track Header
;=============================================================================

TRACKID		= "TRCK"
TRACKVER	= 2
SYNCLEN		= 16

	STRUCTURE	WWarpTrackHeader,0
		ULONG	wth_id			;TRACKID
		UWORD	wth_ver			;structure format version
		UWORD	wth_num			;track number
		UWORD	wth_type		;track data format type
		UWORD	wth_flags		;flags
		ULONG	wth_len			;length of data contained in wwp in bits!
		ULONG	wth_wlen		;lengtn of data to write back in bytes!
		STRUCT	wth_sync,SYNCLEN	;sync
		STRUCT	wth_mask,SYNCLEN	;sync mask (used bits in wth_sync)
		LABEL	wth_data_v1		;track data for wth_ver == 1
	;the following is new for version 2
		UWORD	wth_syncnum		;number of sync to use for write back
		LABEL	wth_data		;track data

;track types

 ENUM 0
 EITEM TT_RAW		;raw mfm data
 EITEM TT_STD		;standard dos format ($1600 bytes)
 EITEM TT_GREM		;gremlin format ($1800 bytes)
 EITEM TT_ROB		;rob northen format (4+$1800 bytes)
 EITEM TT_PMOVER	;Prime Mover format ($18A0 bytes)
 EITEM TT_BEAST1	;Beast1 format ($1838 bytes)
 EITEM TT_BEAST2	;Beast2 format ($189C bytes)
 EITEM TT_BLOODMONEY	;Blood Money format ($1838 bytes)
 EITEM TT_PSYGNOSIS1	;psygnosis1 format ($1800 bytes)
 EITEM TT_TURRICAN1	;Turrican1 format ($1978 bytes)
 EITEM TT_TURRICAN2	;Turrican2 format ($1A90 bytes)
 EITEM TT_TURRICAN3A	;Turrican3 format ($1800 bytes)
 EITEM TT_TURRICAN3B	;Turrican3 format ($1A00 bytes)
 EITEM TT_STDF		;standard dos format in force mode ($1600 bytes)
 EITEM TT_OCEAN		;Ocean format ($1800 bytes)
 EITEM TT_VISION	;Vision format ($1800 bytes)
 EITEM TT_TWILIGHT	;Twilight format ($1400 bytes)
 EITEM TT_ZZKJA		;ZZKJ format ($800 bytes)
 EITEM TT_ZZKJB		;ZZKJ format ($1000 bytes)
 EITEM TT_ZZKJC		;ZZKJ format ($1600 bytes)
 EITEM TT_ZZKJD		;ZZKJ format ($1600 bytes)
 EITEM TT_SPECIALFX	;SpecialFX format ($1800 bytes)
 EITEM TT_TIERTEX	;Tiertex format ($1800 bytes)
 EITEM TT_ELITE		;Elite format ($1800 bytes)
 EITEM TT_GOLIATH	;Goliath format ($1600 bytes)
 EITEM TT_THALAMUS	;Thalamus format ($1810 bytes)
 EITEM TT_BEYOND	;Beyond the Ice Palace format ($1400 bytes)
 EITEM TT_RNCL		;Rob Northen CopyLock ($32 bytes)
 EITEM TT_HITEC		;HiTec format ($180c bytes)
 EITEM TT_MASON		;Mason format ($1600 bytes)
 EITEM TT_TWILIGHT2	;Twilight format ($1520 bytes)
 EITEM TT_TWILIGHT3	;Twilight format ($1800 bytes)
 EITEM TT_RNCLOLD	;standard dos + Rob Northen CopyLock Old (22+$1600 bytes)
 EITEM TT_SLACKSKIN	;SlackSkinAndFlint format ($1400 bytes)

TT_CNT = EOFFSET-1	;number of supported custom formats

;track flags

 BITDEF TF,INDEX,0	;track data starts with index signal (only TT_RAW)
 BITDEF TF,BZIP2,1	;compressed wih bzip2 (unused currently and probably for ever)
 BITDEF TF,RAWSINGLE,2	;raw mfm data is saved in exact bit length
 BITDEF TF,LEQ,3	;all longs of the trackdata are equal, stored is only one long
 BITDEF TF,SLINC,4	;each sector (512 byte) contains longs which will
			;incremented, stored are the first long for each sector
 BITDEF TF,SLEQ,5	;each sector (512 byte) contains equal longs,
			;stored is one long for each sector

;=============================================================================

 ENDC
