use std::env::args;
use std::io::{self, ErrorKind};
use std::path::PathBuf;
use std::{fs, process};

#[derive(Debug)]
struct WordOptions {
    is_title: bool,
    is_scream: bool,
}

fn main() {
    // Skip the first arg, since this is just the binary
    let mut args = args().skip(1);
    let config_path = args.next().expect("Not given a config directory");
    let filetype = args.next();

    let mut buffer = String::new();
    io::stdin().read_line(&mut buffer).unwrap_or_else(|_| {
        eprintln!("Need a word to toggle");
        process::exit(1);
    });
    let word = buffer.trim();

    let _word_options = {
        let mut is_upper = word.chars().map(|c| c.is_uppercase());
        let is_title = is_upper.next().expect("You can't pass an empty string");
        WordOptions {
            is_title,
            is_scream: is_title && is_upper.next().unwrap_or(false),
        }
    };

    let mut path = PathBuf::new();
    path.push(config_path);
    path.push("toggles.toml");

    let bytes = fs::read(&path).unwrap_or_else(|error| {
        match error.kind() {
            ErrorKind::NotFound => eprintln!("{} not found", path.to_string_lossy()),
            err => eprintln!("Something went wrong reading the toggle file: {:#?}", err),
        }
        process::exit(1);
    });

    let value = toml::from_slice::<toml::Value>(&bytes).unwrap_or_else(|error| {
        eprintln!("Something went wrong parsing the toggle file: {}", error);
        process::exit(1);
    });
    let table = value
        .as_table()
        .expect("Top level TOML should always be a table");

    let mut all_types = Vec::new();

    if let Some(typ) = filetype {
        // all_types.push(typ.as_str());

        if let Some(extra_filetypes) = table
            .get(&typ)
            .and_then(|file| file.get("extends"))
            .and_then(|value| value.as_array())
        {
            let mut parsed_types = extra_filetypes
                .iter()
                .filter_map(|value| value.as_str())
                .collect::<Vec<&str>>();
            all_types.append(&mut parsed_types);
        }
    }

    all_types.push("global");

    let possible_word = all_types.into_iter().find_map(|typ| {
        table
            .get(typ)
            .and_then(|some| some.as_table())
            .and_then(|table| table.get("toggles"))
            .and_then(|value| dbg!(dbg!(value.clone()).try_into::<Vec<Vec<&str>>>()).ok())
            .and_then(|toggles| get_toggle(toggles, word))
    });

    if let Some(new_word) = possible_word {
        print!("{}", new_word);
    }
}

fn get_toggle<'a>(toggles: Vec<Vec<&'a str>>, word: &str) -> Option<&'a str> {
    toggles
        .into_iter()
        .map(|array| get_next_word(array, word))
        .find_map(|option| option)
}

fn get_next_word<'a>(word_array: Vec<&'a str>, word: &str) -> Option<&'a str> {
    word_array
        .iter()
        .cycle()
        .take(word_array.len() + 1)
        .position(|value| *value == word)
        .map(|index| word_array[index + 1])
}
