################################################################################
# Makefile for JBug11 talker and overlay for the F1 Board
# Using Borland MAKE v5.2
################################################################################

OPTS = -s+ -l- -m-

HELP:
 @echo *********************************************************
 @echo * Targets: ALL
 @echo *********************************************************
 @echo * Defines: DEBUG
 @echo *********************************************************

################################################################################
all: jbug.boo at28c256.rec ee_f1.rec
################################################################################

jbug.boo: jbug.exp
 $(ASM11) $(OPTS) jbug.asm -exp+
 @exbin jbug.s19
 @copy jbug.bin jbug.boo
 @del jbug.s19 jbug.bin

jbug.exp: jbug.asm
 $(ASM11) $(OPTS) jbug.asm -exp+

at28c256.rec: at28c256.asm jbug.exp
 $(ASM11) $(OPTS) at28c256.asm
 @copy at28c256.s19 at28c256.rec
 @del at28c256.s19

ee_f1.rec: ee_f1.asm jbug.exp
 $(ASM11) $(OPTS) ee_f1.asm
 @copy ee_f1.s19 ee_f1.rec
 @del ee_f1.s19
