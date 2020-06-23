use anyhow::{Context, Result};
use serde::Deserialize;
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
    let search_word = buffer.trim().to_lowercase();

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

    // Make the toggle file path
    let mut path = PathBuf::new();
    path.push(config_path);
    path.push("toggles.toml");

    // Read the toggle file
    let bytes = fs::read(&path).with_context(|| {
        format!(
            "Something went wrong with reading the toggle file: {}",
            path.to_string_lossy()
        )
    })?;

    // Parse the toggle file into a table
    let value = toml::from_slice::<toml::Value>(&bytes).with_context(|| {
        format!(
            "Something went wrong parsing the toggle file: {}",
            path.to_string_lossy()
        )
    })?;
    let table = value
        .as_table()
        .context("Top level TOML should always be a table")?;

    // Queue of each file to check in sequence
    let mut filetype_queue = vec![String::from("global")];

    // Add the (possible) filetype
    if let Some(typ) = filetype {
        filetype_queue.push(typ);
    }

    // Check each type in sequence
    let found_word = loop {
        // Grab the next type
        if let Some(lang_type) = filetype_queue.pop() {
            // Try and grab the filetype
            if let Some(lang_value) = table.get(&lang_type) {
                // If found then put into the struct
                let lang_toggles = lang_value.clone().try_into::<LanguageToggle>()?;
                // Find the search word
                if let Some(found_word) = lang_toggles
                    .toggles
                    .iter()
                    .find_map(|arr| get_next_word(arr, &search_word))
                {
                    // If found, break out of loop
                    break Some(found_word.clone());
                };
                // If it has any extensions, add it to the queue
                if let Some(extra_filetypes) = lang_toggles.extends {
                    filetype_queue.append(&mut extra_filetypes.clone());
                }
            }
        } else {
            break None;
        }
    };

    // If found, print out the word without a newline
    if let Some(found_word) = found_word {
        print!("{}", found_word);
    }

    Ok(())
}

fn get_next_word<'a>(word_array: &'a [String], search_word: &str) -> Option<&'a String> {
    // Find the position of search_word
    let index = word_array
        .iter()
        .map(|value| value.to_lowercase())
        .position(|value| value == search_word);
    // If found, grab next in sequence
    index.and_then(|index| word_array.iter().cycle().nth(index + 1))
}
