################################################################################
# Makefile for JBug11 talker and overlay for the F1 Board
# Using Borland MAKE v5.41
################################################################################

OPTS = -s+ -l- -m-

HELP:
 @echo "*********************************************************
 @echo "* Targets: ALL
 @echo "*********************************************************
 @echo "* Defines: DEBUG
 @echo "*        : MHZ (either 8 or 16)
 @echo "*********************************************************

!ifdef MHZ
OPTS = $(OPTS) -dMHZ=$(MHZ)
!else
OPTS = $(OPTS) -dMHZ=16
!endif

################################################################################
all: jbug.boo at28c256.rec ee_f1.rec
################################################################################

jbug.boo: jbug.exp
 @asm11 $(OPTS) jbug.asm -exp+
 @exbin -t jbug.s19
 @copy jbug.bin jbug.boo
 @del jbug.s19 jbug.bin

jbug.exp: jbug.asm
 @asm11 $(OPTS) jbug.asm -exp+
 @m jbug.exp -r -ftalker_start -ftalker_idle -fswi_srv -fswi_jmp -fillop_jmp > jbug.map
 @sr -f" set " -r jbug.map
 @sr -f,%d+ -r jbug.map


at28c256.rec: at28c256.asm jbug.exp
 @asm11 $(OPTS) at28c256.asm
 @copy at28c256.s19 at28c256.rec
 @del at28c256.s19

ee_f1.rec: ee_f1.asm jbug.exp
 @asm11 $(OPTS) ee_f1.asm
 @copy ee_f1.s19 ee_f1.rec
 @del ee_f1.s19
