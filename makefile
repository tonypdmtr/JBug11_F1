################################################################################
# Makefile for JBug11 talker and overlay for the F1 Board
# Using Borland MAKE v5.43
################################################################################

O = -s+ -l- -m- $(O)

HELP:
 @echo "*********************************************************
 @echo "* Targets: ALL
 @echo "*********************************************************
 @echo "* Defines: DEBUG
 @echo "*        : MHZ (either 8 or 16)
 @echo "*********************************************************

!ifdef MHZ
O = -dMHZ=$(MHZ) $(O)
!else
O = -dMHZ=16 $(O)
!endif

################################################################################
all: jbug.boo at28c256.rec ee_f1.rec
################################################################################

jbug.boo: jbug.exp
 @asm11 $(O) jbug.asm -exp+
 @exbin -t jbug.s19
 @copy jbug.bin jbug.boo
 @del jbug.s19 jbug.bin

jbug.exp: jbug.asm
 @asm11 $(O) jbug.asm -exp+
 @m jbug.exp -r+ -ftalker_start -ftalker_idle -fswi_srv -fswi_jmp -fillop_jmp -l- > jbug.map
 @sr -f" set " -r jbug.map
 @sr -f,%d+ -r jbug.map

at28c256.rec: at28c256.asm jbug.exp
 @asm11 $(O) at28c256.asm -b$@

ee_f1.rec: ee_f1.asm jbug.exp
 @asm11 $(O) ee_f1.asm -b$@
