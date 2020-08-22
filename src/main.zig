const std = @import("std");
const fs = std.fs;
const warn = std.debug.warn;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Allocator = std.mem.Allocator;
const HashMap = std.hash_map.StringHashMap;

const LangToggle = struct {
    extends: ?ArrayList([]u8),
    toggles: ArrayList(ArrayList([]u8)),
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var args = std.process.args();

    // Skip the binary location
    const is_more_args = args.skip();
    const config_path: []const u8 = args.nextPosix() orelse {
        std.debug.warn("Need a config path!\n", .{});
        std.process.exit(1);
    };
    const filetype = args.nextPosix();

    const file_path = try fs.path.resolve(allocator, &[_][]const u8{ config_path, "toggles.toml" });
    const file = try fs.openFileAbsolute(file_path, .{});
    defer file.close();

    // TODO: probably something better than max size
    const contents = try file.inStream().readAllAlloc(allocator, std.math.maxInt(usize));

    const lang_map = try parseLangToggles(allocator, contents);
}

const ParseError = error{UnexpectedGlobalKey};

fn parseLangToggles(allocator: *Allocator, file_contents: []const u8) ParseError!HashMap(LangToggle) {
    const lang_map = HashMap(LangToggle).init(allocator);
    const first_char_index = eatWhitespace(file_contents, 0);
    if (file_contents[first_char_index] != '[') return ParseError.UnexpectedGlobalKey;
    std.debug.warn("first char '{c}' at position {}\n", .{ file_contents[first_char_index], first_char_index });
    return lang_map;
}

fn eatWhitespace(buffer: []const u8, position: u64) u64 {
    var offset: u64 = 0;
    while (true) {
        switch (buffer[position + offset]) {
            ' ', '\t', '\r', '\n' => offset += 1,
            else => return position + offset,
        }
    }
}
