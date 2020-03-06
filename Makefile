#
# Makefile for WWarp
# ©2019 Bert Jahn, All Rights Reserved
#
# 2019-06-06 created
#
# $@ target
# $< first dependency
# $^ all dependencies

# enable a non-debug assemble:
# 'setenv DEBUG=0' or 'make DEBUG=0'

# different commands for build under Amiga or Vamos
ifdef AMIGA
ASMOPT=-x+
CP=Copy Clone
DEST=C:
RM=Delete
else
ASMOPT=-x-
CP=cp -p
DEST=../sys/c/
RM=rm
VAMOS=vamos -qC68020 -m4096 -s128 --
endif

DEPEND=vasm -depend=make -quiet

ifndef DEBUG
DEBUG=1
endif

ifeq ($(DEBUG),1)
# debug options
ASMOPTDBG=-sa+ -dDEBUG=1
else
# normal options
ASMOPTDBG=-OG+
endif

ASM=$(VAMOS) basm -v+ -O+ -ODc- -ODd- -wo- -iinclude $(ASMOPT) $(ASMOPTDBG)

all : WWarp encode mfm

WWarp : wwarp.asm cmdc.s cmdd.s cmdw.s \
	fmt_beast1.s fmt_beast2.s fmt_beyond.s fmt_bloodmoney.s \
	fmt_elite.s fmt_goliath.s fmt_gremlin.s fmt_hitec.s \
	fmt_mason.s fmt_ocean.s fmt_primemover.s fmt_psygnosis1.s \
	fmt_rncopylock.s fmt_rncopylockold.s fmt_robnorthen.s \
	fmt_slackskin.s fmt_specialfx.s fmt_std.s fmt_thalamus.s fmt_tiertex.s \
	fmt_turrican1.s fmt_turrican2.s fmt_turrican3a_1800.s fmt_turrican3b_1A00.s \
	fmt_twilight.s fmt_vision.s fmt_zzkj.s formats.s \
	include/libraries include/wwarp.i \
	io.s macros/ntypes.i \
	sources/devices.i sources/dosio.i sources/error.i sources/files.i sources/strings.i
	$(VAMOS) wdate >.date
	$(ASM) -o$@ $<
	$(CP) $@ $(DEST)

encode : encode.asm macros/ntypes.i sources/dosio.i sources/strings.i sources/error.i sources/devices.i sources/files.i
	$(VAMOS) wdate >.date
	$(ASM) -o$@ $<
	$(CP) $@ $(DEST)

mfm : mfm.asm macros/ntypes.i sources/dosio.i sources/strings.i sources/error.i sources/devices.i
	$(VAMOS) wdate >.date
	$(ASM) -o$@ $<
	$(CP) $@ $(DEST)

clean :
	$(RM) WWarp encode mfm

depend :
	$(DEPEND) wwarp.asm
	$(DEPEND) encode.asm
	$(DEPEND) mfm.asm
