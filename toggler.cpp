#include <iostream>
#include <algorithm>
#include <string>
#include <vector>
#include "./cpptoml.h"

int
main(int argc, char *argv[]) {
	if (argc != 3) {
		std::cerr << "Usage:\n\t$ toggler <filetype> <word>\n";
		return EXIT_FAILURE;
	}
	std::string filetype(argv[1]);
	std::string word(argv[2]);

	auto config = cpptoml::parse_file("toggles.toml");
	auto filetype_toggles = config->get_array_of<cpptoml::array>(filetype);
	if (filetype_toggles) {
		for (const auto &section : *filetype_toggles) {
			auto values = *section->get_array_of<std::string>();

			auto found = std::find(values.begin(), values.end(), word);
			if (found == values.end()) continue;

			found++;
			if (found == values.end()) {
				found = values.begin();
			}
			std::cout << *found << '\n';
			return EXIT_SUCCESS;
		}
	}

	auto global_toggles = config->get_array_of<cpptoml::array>("global");
	if (global_toggles) {
		for (const auto &section : *global_toggles) {
			auto values = *section->get_array_of<std::string>();

			auto found = std::find(values.begin(), values.end(), word);
			if (found == values.end()) continue;

			found++;
			if (found == values.end()) {
				found = values.begin();
			}
			std::cout << *found << '\n';
			return EXIT_SUCCESS;
		}
	}
	return EXIT_FAILURE;
}
