To use JBug11 v5.2.1.0912 (and, possibly, later ones) with the ASPiSYS F1 Board:
(Last updated on 2011.02.18 by Tony G. Papadimitriou <tonyp@acm.org>)

*** THIS IS AN IMPROVED VERSION AUTOMATICALLY TAKING CARE OF BOOTSTRAP ROM ***
(All talkers are rewritten for ASM11 v8.00+ so that they can be easily altered
and automatically linked together based on the produced .EXP file of the main
talker.  This makes altering the source code of the talkers a lot simpler.)

Note: If you make changes to any of the source code of either talker, run MAKE
      (Borland MAKE v5.2+) to recreate the needed files before proceeding.

1. Create a new subdirectory under JBug11 installation, called ASPiSYS

2. Copy all files from the distribution ZIP file into that directory.

3. Run MAKE ALL (*only* if any of the .ASM source files were updated).

4. Goto JBug11's menu "Settings" and adjust/enable only the following options:
   (What is not mentioned you should leave as is)

   In the "General" tab:                MCU Type: 11F1
   In the "COM Port" tab:               COMx where you have F1 Board attached
                                        MCU Crystal Freq: 8MHz or 16MHz accordingly
                                        (If you select 8MHz, you may also choose
                                        the faster 7680 talker upload baud rate.)
   In the "Macros" tab:                 R HPRIO=E5
                                        R BPROT=00
                                        R CONFIG=0F
                                        R CSSTRH=00
                                        R CSGADR=00
                                        R CSGSIZ=01
                                        R CSCTL=45
                                        and select option: After Booting
   In the "Talkers" tab:                Talker: [JBug11]\ASPiSYS\JBug.boo
                                        MapFile: [JBug11]\ASPiSYS\JBug.exp
   In the "Overlays" tab:               On-chip EEPROM: [JBug11]\ASPiSYS\ee_f1.rec
                                        Ext. Page Written: [JBug11]\ASPiSYS\at28c256.rec
   In the "Memory" tab:
                                        RAM window should contain:
                                                  On-chip  RAM=0000..03FF
                                                  External RAM=0400..0DFF
                                                  External RAM=1060..7FFF
                                        Control Registers:
                                                  1000-105F
                                        EEPROM: 0E00..0FFF
                                        External Byte-Written:
                                                  8000..FFFF
                                        External Page-Written:
                                                  8000..FFFF
                                                  Data Page Size: 64
                                                  (Deselect "Writes are page-only")

          Make Mask ROM, EPROM/OTP ROM, External Byte-Written, non-visible.
          Everything else should be visible.

5. Press F12 (or File/Save Project As) to save your configuration by giving it
   an appropriate name, such as "ASPiSYS F1 Board"

With this latest update, there are no known issues.

Let me know of any issues (and possible workarounds) you've discovered so
that they might help others.

Tony Papadimitriou <tonyp@acm.org>
