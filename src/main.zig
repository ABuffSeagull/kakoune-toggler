const std = @import("std");

pub fn main() anyerror!void {
    // var arena = std.heap.arenaallocator.init(std.heap.page_allocator);
    // defer arena.deinit();

    var args = std.process.args();
    const isMoreArgs = args.skip();
    if (!isMoreArgs) {
        std.debug.warn("There are no more args", .{});
        return;
    }
    const configpath = args.nextPosix();
    std.debug.warn("Config path: {}", .{configpath});
}
