all:
	@g++ -Og toggler.cpp -o toggler

debug:
	@g++ -Wall -O0 toggler.cpp -o toggler
