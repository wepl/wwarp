#
# Makefile for WWarp
# ©2019-2020 Bert Jahn, All Rights Reserved
#
# 2019-06-06 created
# 2020-04-03 added vasm support
# 2020-08-23 td added
#
# $@ target
# $< first dependency
# $^ all dependencies

# enable a non-debug assemble:
# 'setenv DEBUG=0' or 'make DEBUG=0'

# different commands for build under Amiga or Vamos
ifdef AMIGA

# basm options: -x+ = use cachefile.library -s1+ = create SAS/D1 debug hunks
BASMOPT=-x+
BASMOPTDBG=-s1+
CP=Copy Clone
DEST=C:
RM=Delete
DATE=wdate >.date

# on Amiga default=DEBUG
ifndef DEBUG
DEBUG=1
endif

else

# basm options: -x- = don't use cachefile.library -sa+ = create symbol hunks
BASMOPT=-x-
BASMOPTDBG=-sa+
VASMOPT=-I$(INCLUDEOS3)
CP=cp -p
DEST=../sys/c/
RM=rm
DATE=date "+(%d.%m.%Y)" | xargs printf >.date
VAMOS=vamos -qC68020 -m4096 -s128 --

# on Vamos default=NoDEBUG
ifndef DEBUG
DEBUG=0
endif

endif

DEPEND=vasm -depend=make -quiet

ifeq ($(DEBUG),1)

# Debug options
# ASM creates executables, ASMB binary files, ASMO object files
# BASM: -H to show all unused Symbols/Labels, requires -OG-
ASM=$(VAMOS) basm -v+ $(BASMOPT) $(BASMOPTDBG) -O+ -ODc- -ODd- -wo- -dDEBUG=1
ASMB=$(ASM)
ASMO=$(ASM)
ASMDEF=-d
ASMOUT=-o

else

# normal options
# VASM: -wfail -warncomm -databss
ASMBASE=vasmm68k_mot $(VASMOPT) -ignore-mult-inc -nosym -quiet -wfail -opt-allbra -opt-clr -opt-lsl -opt-movem -opt-nmoveq -opt-pea -opt-size -opt-st
ASM=$(ASMBASE) -Fhunkexe
ASMB=$(ASMBASE) -Fbin
ASMO=$(ASMBASE) -Fhunk
ASMDEF=-D
ASMOUT=-o 

endif

all : WWarp encode mfm td

WWarp : wwarp.asm cmdc.s cmdd.s cmdw.s \
	fmt_beast1.s fmt_beast2.s fmt_beyond.s fmt_bloodmoney.s \
	fmt_elite.s fmt_goliath.s fmt_gremlin.s fmt_hitec.s \
	fmt_mason.s fmt_ocean.s fmt_primemover.s fmt_psygnosis1.s \
	fmt_rncopylock.s fmt_rncopylockold.s fmt_robnorthen.s \
	fmt_slackskin.s fmt_specialfx.s fmt_std.s fmt_thalamus.s fmt_tiertex.s \
	fmt_turrican1.s fmt_turrican2.s fmt_turrican3a_1800.s fmt_turrican3b_1A00.s \
	fmt_twilight.s fmt_vision.s fmt_zzkj.s formats.s \
	include/libraries include/wwarp.i \
	io.s macros/ntypes.i macros/sprint.i \
	sources/devices.i sources/dosio.i sources/error.i sources/files.i sources/strings.i
	$(DATE)
	$(ASM) $(ASMOUT)$@ $<
	$(CP) $@ $(DEST)

encode : encode.asm macros/sprint.i sources/dosio.i sources/strings.i sources/error.i sources/devices.i sources/files.i
	$(DATE)
	$(ASM) $(ASMOUT)$@ $<
	$(CP) $@ $(DEST)

mfm : mfm.asm macros/ntypes.i macros/sprint.i sources/dosio.i sources/strings.i sources/error.i sources/devices.i
	$(DATE)
	$(ASM) $(ASMOUT)$@ $<
	$(CP) $@ $(DEST)

td : td.asm macros/sprint.i sources/dosio.i sources/strings.i sources/files.i sources/error.i sources/devices.i
	$(DATE)
	$(ASM) $(ASMOUT)$@ $<
	$(CP) $@ $(DEST)

clean :
	$(RM) .date WWarp encode mfm td

depend :
	$(DEPEND) wwarp.asm
	$(DEPEND) encode.asm
	$(DEPEND) mfm.asm
	$(DEPEND) td.asm

