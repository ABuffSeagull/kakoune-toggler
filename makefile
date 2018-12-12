all:
	@$(CXX) -std=c++11 -Og toggler.cpp -o toggler

debug:
	@$(CXX) -std=c++11 -Wall -O0 toggler.cpp -o toggler
