
	IFND SPRINT_I
SPRINT_I EQU 1

; workaround for vasm not supporting sprintx
; supported arguments for sprint:
; string, value, string, value, string, string
; third and more arguments are optional

sprint	MACRO
	IFD BARFLY
		db	\1
		sprintx	"%ld",\2
	ELSE
sprintval	SET	\2
		db	\1,"\<sprintval>"
	ENDC
	IFGT NARG-2
		db	\3
	ENDC
	IFGT NARG-3
	IFD BARFLY
		sprintx	"%ld",\4
	ELSE
sprintval	SET	\4
		db	"\<sprintval>"
	ENDC
	ENDC
	IFGT NARG-4
		db	\5
	ENDC
	IFGT NARG-5
		db	\6
	ENDC
	IFGT NARG-6
		FAIL	to many args for sprint
	ENDC
	ENDM

	ENDC

