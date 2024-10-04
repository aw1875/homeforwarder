const std = @import("std");

const Daemon = @import("daemon.zig");
const DaemonError = Daemon.DaemonError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var daemon = try Daemon.init(allocator);
    defer daemon.deinit();

    daemon.startDaemon() catch |err| {
        switch (err) {
            DaemonError.NoServices => std.process.exit(0),
            else => return err,
        }
    };
}
