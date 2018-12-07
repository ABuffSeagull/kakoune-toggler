#include <iostream>
#include <algorithm>
#include <string>
#include <vector>
#include <wordexp.h>
#include "./cpptoml.h"

void
find_toggle(std::shared_ptr<cpptoml::table> config, std::string key, std::string word) {
	std::cerr << "key: " << key << ", word: " << word << std::endl;
	auto filetype_toggles = config->get_qualified_array_of<cpptoml::array>(key + ".toggles");
	if (filetype_toggles) {
		for (const auto &section : *filetype_toggles) {
			auto values = *section->get_array_of<std::string>();

			auto found = std::find(values.begin(), values.end(), word);
			if (found == values.end()) continue;

			found += 1;
			if (found == values.end()) {
				found = values.begin();
			}
			std::cout << *found;
			exit(0);
		}
	}
}

int
main(int argc, char *argv[]) {
	if (argc != 3) {
		std::cerr << "Usage:\n\t$ toggler <filetype> <word>\n";
		return EXIT_FAILURE;
	}
	std::string filetype(argv[1]);
	std::string word(argv[2]);

	wordexp_t expanded;
	wordexp("$HOME/.config/kak/toggles.toml", &expanded, 0);
	auto config = cpptoml::parse_file(expanded.we_wordv[0]);

	auto extends = config->get_qualified_array_of<std::string>(filetype + ".extends");
	for (const auto &extend : *extends) {
		find_toggle(config, extend, word);
	}
	find_toggle(config, filetype, word);

	find_toggle(config, "global", word);

	std::cout << word;
	std::cerr << "Toggler.kak: Word not found in toggles\n";
	return EXIT_FAILURE;
}
