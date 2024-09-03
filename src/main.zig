const std = @import("std");

const Daemon = @import("daemon.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var daemon = try Daemon.init(allocator);
    defer daemon.deinit();

    try daemon.startDaemon();
}
