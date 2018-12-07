#include <iostream>
#include <algorithm>
#include <string>
#include <vector>
#include <locale>
#include <wordexp.h>
#include "./cpptoml.h"

bool isTitle = false;
bool isScream = false;
std::locale loc("");

void
find_toggle(std::shared_ptr<cpptoml::table> config, std::string key, std::string word) {
	std::cerr << "key: " << key << ", word: " << word << '.' << std::endl;
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
			std::string new_found("");
			new_found += isTitle ? std::toupper(found->at(0), loc) : found->at(0);
			if (isScream) {
				for (const auto &ch : found->substr(1)) {
					new_found += std::toupper(ch, loc);
				}
			} else {
				new_found += found->substr(1);
			}
			std::cout << new_found;
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

	if (std::isupper(word[0], loc)) isTitle = true;
	if (std::isupper(word[1], loc)) isScream = true;
	std::string lower_word("");
	for (auto &ch : word) {
		lower_word += std::tolower(ch, loc);
	}

	wordexp_t expanded;
	wordexp("$HOME/.config/kak/toggles.toml", &expanded, 0);
	auto config = cpptoml::parse_file(expanded.we_wordv[0]);

	auto extends = config->get_qualified_array_of<std::string>(filetype + ".extends");
	for (const auto &extend : *extends) {
		find_toggle(config, extend, lower_word);
	}
	find_toggle(config, filetype, lower_word);

	find_toggle(config, "global", lower_word);

	std::cout << word;
	std::cerr << "Toggler.kak: Word not found in toggles\n";
	return EXIT_FAILURE;
}
