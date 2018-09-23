AFLAGS=-felf64
ASM=nasm

all: main

main: main.o lib.o
	ld -o main main.o lib.o

%.o: %.asm
	$(ASM) $(AFLAGS) -o $@ $<

clean:
	rm -f main *.o
