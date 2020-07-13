use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::HashMap;
use std::env::args;
use std::fs;
use std::io;
use std::path::PathBuf;

// enum Casing {
//     IsOriginal,
//     IsTitle,
//     IsUpper,
// }

#[derive(Deserialize)]
struct LanguageToggle {
    extends: Option<Vec<String>>,
    toggles: Vec<Vec<String>>,
}

fn main() -> Result<()> {
    // Skip the first arg, since this is just the binary
    let mut args = args().skip(1);
    let config_path = args.next().context("Not given a config directory")?;
    // This is not always needed, then we'll just check global toggles
    let filetype = args.next();

    // Get the search_word to be toggled
    let mut buffer = String::new();
    io::stdin()
        .read_line(&mut buffer)
        .context("Need a word to toggle")?;
    let search_word = buffer.trim();

    // Get the casing of the search word
    // let word_casing = {
    //     let mut is_upper_iter = search_word.chars().map(|c| c.is_uppercase());
    //     let is_title = is_upper_iter
    //         .next()
    //         .context("You can't pass an empty string")?;
    //     if let Some(true) = is_upper_iter.next() {
    //         Casing::IsUpper
    //     } else if is_title {
    //         Casing::IsTitle
    //     } else {
    //         Casing::IsLower
    //     }
    // };

    let table = parse_toggles_file(&config_path)?;

    let found_word = get_toggled_word(&table, search_word, filetype);

    // Print out found toggle or original if not found
    print!("{}", found_word.unwrap_or(&buffer));

    Ok(())
}

fn parse_toggles_file(config_path: &str) -> Result<HashMap<String, LanguageToggle>> {
    // Make the toggle file path
    let path: PathBuf = [config_path, "toggles.toml"].iter().collect();

    // Read the toggle file
    let bytes = fs::read(&path).with_context(|| {
        format!(
            "Something went wrong with reading the toggle file: {}",
            path.to_string_lossy()
        )
    })?;

    // Parse the toggle file into a table
    toml::from_slice(&bytes).with_context(|| {
        format!(
            "Something went wrong parsing the toggle file: {}",
            path.to_string_lossy()
        )
    })
}

fn get_toggled_word<'a>(
    language_map: &'a HashMap<String, LanguageToggle>,
    search_word: &str,
    filetype: Option<String>,
) -> Option<&'a String> {
    // Queue of each file to check in sequence
    let mut filetype_stack = vec!["global".to_string()];

    // Add the (possible) filetype
    if let Some(typ) = filetype {
        filetype_stack.push(typ);
    }

    // Check each type in sequence
    loop {
        // Grab the next type
        if let Some(lang_type) = filetype_stack.pop() {
            // Try and grab the filetype
            if let Some(lang_toggles) = language_map.get(&lang_type) {
                // Find the search word
                if let Some(found_word) = lang_toggles
                    .toggles
                    .iter()
                    .find_map(|arr| get_next_word(arr, &search_word))
                {
                    // If found, break out of loop
                    break Some(found_word);
                };
                // If it has any extensions, add it to the queue
                if let Some(extra_filetypes) = &lang_toggles.extends {
                    filetype_stack.append(&mut extra_filetypes.clone());
                }
            }
        } else {
            break None;
        }
    }
}

fn get_next_word<'a>(word_array: &'a [String], search_word: &str) -> Option<&'a String> {
    // Find the position of search_word
    word_array
        .iter()
        .position(|current_word| current_word == search_word)
        .map(move |found_index| {
            let next_index = found_index + 1;
            if next_index == word_array.len() {
                &word_array[0]
            } else {
                &word_array[next_index]
            }
        })
}
