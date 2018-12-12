all:
	@$(CXX) -Og toggler.cpp -o toggler

debug:
	@$(CXX) -Wall -O0 toggler.cpp -o toggler
