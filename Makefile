all:
	dasm eog.asm -v0 -f3 -oeog.bin
run:
	stella eog.bin
