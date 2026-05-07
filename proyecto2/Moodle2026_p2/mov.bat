@echo off
if not exist WORK mkdir WORK
ghdl -i --ieee=synopsys -fexplicit --workdir=WORK *.vhd
ghdl --gen-makefile -fexplicit --ieee=synopsys --workdir=WORK testbench > Makefile
ghdl -m --ieee=synopsys -fexplicit --workdir=WORK testbench
ghdl -r --ieee=synopsys -fexplicit --workdir=WORK testbench --stop-time=5us --wave=test.ghw
start gtkwave test.ghw