const std = @import("std");
const fs = std.fs;
const warn = std.debug.warn;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Allocator = std.mem.Allocator;
const HashMap = std.hash_map.StringHashMap;

const LangToggle = struct {
    extends: ?ArrayList([]const u8),
    toggles: ArrayList(ArrayList([]const u8)),
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const did_leak = gpa.deinit();
        std.debug.print("Leaked? {}\n", .{did_leak});
    }
    var arena = std.heap.ArenaAllocator.init(&gpa.allocator);
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

    const tokens = try tokenizeTOMLFile(allocator, contents);
    defer tokens.deinit();
    for (tokens.items) |token| {
        switch (token) {
            .OpenBracket => std.debug.print("Open Bracket\n", .{}),
            .CloseBracket => std.debug.print("Close Bracket\n", .{}),
            .EqualSign => std.debug.print("Equal Sign\n", .{}),
            .Comma => std.debug.print("Comma\n", .{}),
            .String => |string| std.debug.print("String: {}\n", .{string}),
            .Identifier => |ident| std.debug.print("Identifier: {}\n", .{ident}),
        }
    }
}

const TOMLToken = union(enum) {
    OpenBracket,
    CloseBracket,
    EqualSign,
    Comma,
    String: []const u8,
    Identifier: []const u8,
};

const ParseError = error{UnexpectedGlobalKey};

fn tokenizeTOMLFile(allocator: *Allocator, file_contents: []const u8) !ArrayList(TOMLToken) {
    var token_list = ArrayList(TOMLToken).init(allocator);

    var index: usize = 0;
    while (index < file_contents.len) : (index += 1) {
        switch (file_contents[index]) {
            // ignore whitespace
            ' ', '\t', '\r', '\n' => {},
            '[' => try token_list.append(.OpenBracket),
            ']' => try token_list.append(.CloseBracket),
            '=' => try token_list.append(.EqualSign),
            ',' => try token_list.append(.Comma),
            '"' => {
                var end_index = index + 1;
                while (file_contents[end_index] != '"') : (end_index += 1) {}
                try token_list.append(TOMLToken{ .String = file_contents[index + 1 .. end_index] });
                index = end_index + 1;
            },
            else => |char| {
                var end_index = index + 1;
                while (true) : (end_index += 1) {
                    switch (file_contents[end_index]) {
                        'a'...'z', 'A'...'Z', '-', '_' => {},
                        else => break,
                    }
                }
                try token_list.append(TOMLToken{ .Identifier = file_contents[index..end_index] });
                index = end_index;
            },
        }
    }
    return token_list;
}
