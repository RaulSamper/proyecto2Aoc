mkdir -p WORK
ghdl -i --ieee=synopsys -fexplicit --workdir=WORK *.vhd
ghdl --gen-makefile -fexplicit --ieee=synopsys --workdir=WORK testbench > Makefile
ghdl -m --ieee=synopsys -fexplicit --workdir=WORK testbench
ghdl -r --ieee=synopsys -fexplicit --workdir=WORK testbench --stop-time=50us --wave=test.ghw
gtkwave test.ghw &
ghdl --clean --workdir=WORK