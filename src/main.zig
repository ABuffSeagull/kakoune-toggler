const std = @import("std");
const fs = std.fs;
const warn = std.debug.warn;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Allocator = std.mem.Allocator;

const String = []const u8;

const LangToggle = struct {
    extends: ?[]String,
    toggles: [][]String,
};

const LangMap = std.hash_map.StringHashMap(LangToggle);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var args = std.process.args();

    // Skip the binary location
    const is_more_args = args.skip();
    // Grab the config path
    const config_path: String = args.nextPosix() orelse {
        std.debug.warn("Need a config path!\n", .{});
        std.process.exit(1);
    };
    // Get the filetype, although it's optional
    const filetype = args.nextPosix();

    // Resolve full file path and open it
    const file_path = try fs.path.resolve(allocator, &[_]String{ config_path, "toggles.toml" });
    const file = try fs.openFileAbsolute(file_path, .{});
    defer file.close();

    // Read in the file
    const contents = try file.inStream().readAllAlloc(allocator, 1 * 1024 * 1024);

    // Tokenize the file
    var token_list = ArrayList(TOMLToken).init(allocator);
    defer token_list.deinit();
    try tokenizeTOMLFile(&token_list, contents);

    // Parse the file
    var lang_map = LangMap.init(allocator);
    defer token_list.deinit();
    try parseTokenList(&lang_map, token_list.items);

    const stdin = std.io.getStdIn();
    defer stdin.close();

    const in_word = try stdin.readToEndAlloc(allocator, 2 << 8);
    const toggle_word = std.mem.trim(u8, in_word, &std.ascii.spaces);

    const found_word = try findToggleWord(&lang_map, toggle_word, filetype);

    const stdout = std.io.getStdOut();
    defer stdout.close();

    _ = try stdout.write(found_word orelse toggle_word);
}

const TOMLToken = union(enum) {
    open_bracket,
    close_bracket,
    equal_sign,
    comma,
    string: String,
    identifier: String,
};

fn tokenizeTOMLFile(token_list: *ArrayList(TOMLToken), file_contents: String) !void {
    var index: usize = 0;
    // loop over the file
    while (index < file_contents.len) : (index += 1) {
        switch (file_contents[index]) {
            // ignore whitespace
            ' ', '\t', '\r', '\n', std.ascii.control_code.VT, std.ascii.control_code.FF => {},
            '[' => try token_list.append(.open_bracket),
            ']' => try token_list.append(.close_bracket),
            '=' => try token_list.append(.equal_sign),
            ',' => try token_list.append(.comma),
            '"' => {
                // start the end_index one after
                var end_index = index + 1;
                // Advance till the other quote
                // TODO: make it ignore quoted strings
                while (file_contents[end_index] != '"') : (end_index += 1) {}
                // Add the string to the list
                try token_list.append(.{ .string = file_contents[index + 1 .. end_index] });
                // Set index to the quote, since we'll advance one
                index = end_index;
            },
            else => |char| {
                // Start one after current index
                var end_index = index + 1;
                // Advance to first non-valid key character
                while (true) : (end_index += 1) {
                    switch (file_contents[end_index]) {
                        'a'...'z', 'A'...'Z', '-', '_' => {},
                        else => break,
                    }
                }
                // Add the identifier to the list
                try token_list.append(.{ .identifier = file_contents[index..end_index] });
                // Set one before, since we advance one in loop
                index = end_index - 1;
            },
        }
    }
}

const ParseState = union(enum) {
    global,
    extends_value,
    toggles_value,
};

fn parseTokenList(lang_map: *LangMap, tokens: []TOMLToken) !void {
    var allocator = lang_map.allocator;

    // What state we're in while parsing
    var current_state = ParseState.global;

    // The current entry of the language map we're dealing with
    // It's (hopefully) guarenteed that we'll initialize this before accessing it
    var current_entry: *LangMap.Entry = undefined;

    var index: usize = 0;
    while (index < tokens.len) : (index += 1) {
        switch (current_state) {
            // We're in the global scope
            .global => switch (tokens[index]) {
                // We're defining a new language
                .open_bracket => {
                    // Make sure that it follows `[identifier]` and nothing else
                    assert(tokens[index + 1] == .identifier and tokens[index + 2] == .close_bracket);
                    // grab out the identifier and make a new LangToggle for it
                    switch (tokens[index + 1]) {
                        .identifier => |language| {
                            current_entry = try lang_map.getOrPutValue(language, .{ .extends = null, .toggles = undefined });
                        },
                        else => return error.BadTableDecleration,
                    }
                    // skip identifier and close bracket
                    index += 2;
                },
                // Either gonna be `extends` or `toggles` for a given language
                .identifier => |identifier| {
                    if (std.mem.eql(u8, identifier, "extends")) {
                        current_state = .extends_value;
                    } else if (std.mem.eql(u8, identifier, "toggles")) {
                        current_state = .toggles_value;
                    }
                    assert(tokens[index + 1] == .equal_sign);
                    // skip the equals sign
                    index += 1;
                },
                // You done messed up
                else => return error.BadGlobalToken,
            },
            // Making a language extend array
            .extends_value => {
                // Make sure it's the start of an array
                assert(tokens[index] == .open_bracket);

                var extends_array = ArrayList(String).init(allocator);

                index += 1;

                while (tokens[index] != .close_bracket) : (index += 1) {
                    switch (tokens[index]) {
                        .string => |value| try extends_array.append(value),
                        .comma => continue,
                        else => unreachable,
                    }
                }

                current_entry.value.extends = extends_array.toOwnedSlice();

                // We back in global scope
                current_state = .global;
            },
            .toggles_value => {
                // Make sure that the array only contains arrays
                assert(tokens[index] == .open_bracket and tokens[index + 1] == .open_bracket);

                var toggles_array = ArrayList([]String).init(allocator);

                // Advance to inner array
                index += 1;

                // Go until we find the outer close bracket (we consume all the inner ones)
                while (tokens[index] != .close_bracket) : (index += 1) {
                    switch (tokens[index]) {
                        // Start of a new array!
                        .open_bracket => {
                            // Skip the bracket
                            index += 1;

                            // Make the new string list
                            var string_list = ArrayList(String).init(allocator);

                            // Loop till we find the inner close bracket
                            while (tokens[index] != .close_bracket) : (index += 1) {
                                switch (tokens[index]) {
                                    // Add the string to the string list
                                    .string => |value| try string_list.append(value),
                                    // Skip all commas
                                    .comma => continue,
                                    // Shouldn't hit
                                    else => unreachable,
                                }
                            }
                            // Add it to the toggles array
                            try toggles_array.append(string_list.toOwnedSlice());
                        },
                        .comma => continue,
                        else => unreachable,
                    }
                }

                current_entry.value.toggles = toggles_array.toOwnedSlice();
                current_state = .global;
            },
        }
    }
}

fn findToggleWord(lang_map: *LangMap, toggle_word: String, filetype: ?String) !?String {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var language_list = ArrayList(String).init(&arena.allocator);
    defer language_list.deinit();

    try language_list.append("global");

    if (filetype) |ft| try language_list.append(ft);

    while (language_list.popOrNull()) |language| {
        if (lang_map.get(language)) |current_language| {
            for (current_language.toggles) |toggle_list| {
                for (toggle_list) |toggle, toggle_index| {
                    if (std.mem.eql(u8, toggle, toggle_word)) {
                        return toggle_list[(toggle_index + 1) % toggle_list.len];
                    }
                }
            }
            if (current_language.extends) |extends| {
                try language_list.appendSlice(extends);
            }
        }
    }
    return null;
}
