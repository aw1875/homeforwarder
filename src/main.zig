const std = @import("std");

const Common = @import("utils/common.zig");
const Config = @import("config.zig");
const Console = @import("utils/console.zig");
const DateTime = @import("utils/datetime.zig");

const Color = Common.Color;
var console = Console{};

fn startService(allocator: std.mem.Allocator, service: Config.Service, forward_host: []const u8, timeout: u8) !void {
    while (true) {
        console.infof("Forwarding service {s} from {s}:{d} to {s}:{d} via {s}", .{
            Color.formatForeground(allocator, Color.FG.Magenta, service.name),
            service.hostname,
            service.connect_port,
            forward_host,
            service.forward_port,
            Color.formatForeground(allocator, Color.FG.Yellow, @tagName(service.protocol)),
        });

        switch (service.protocol) {
            .TCP => {
                const args = [_][]const u8{
                    "ssh",
                    "-N",
                    "-o",
                    "ExitOnForwardFailure=yes",
                    "-o",
                    try std.fmt.allocPrint(allocator, "ServerAliveInterval={d}", .{timeout}),
                    "-o",
                    "ServerAliveCountMax=1",
                    "-R",
                    try std.fmt.allocPrint(allocator, "{d}:{s}:{d}", .{ service.forward_port, service.hostname, service.connect_port }),
                    forward_host,
                };

                var process = std.process.Child.init(&args, allocator);
                process.spawn() catch |err| {
                    console.errorf("Couldn't spawn process {s}: {}", .{ service.name, err });
                    Common.sleep(5000);
                    continue;
                };

                _ = try process.wait();
            },
            .UNIX => return error.Unimplemented,
        }

        console.warnf("Service {s} has exited, restarting at {s}", .{
            Color.formatForeground(allocator, Color.FG.Magenta, service.name),
            Color.formatForeground(allocator, Color.FG.Yellow, DateTime.addSeconds(allocator, 5)),
        });
        Common.sleep(5000);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    console.allocator = allocator;

    // TODO: Figure out why cwd has issues when running as a service
    var path: [std.fs.max_path_bytes]u8 = undefined;
    _ = try std.posix.getcwd(&path);

    // TODO: Make this dynamic after fixing the above issue
    const config_file = std.fs.openFileAbsolute("/opt/homeforwarder/config.json", .{}) catch |err| {
        switch (err) {
            error.FileNotFound => console.@"error"("Config file not found"),
            else => console.errorf("Failed to open config file: {}", .{err}),
        }

        std.process.exit(1);
    };
    defer config_file.close();

    const source = try config_file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(source);

    var parsed_config = std.json.parseFromSlice(Config, allocator, source, .{}) catch |e| {
        switch (e) {
            error.MissingField => console.@"error"("Failed to parse config: Missing field"),
            error.DuplicateField, error.UnknownField => console.@"error"("Failed to parse config: Duplicate or unknown field"),
            else => console.errorf("Failed to parse config: {}", .{e}),
        }

        std.process.exit(1);
    };
    defer parsed_config.deinit();

    const config = parsed_config.value;

    var threads: std.ArrayList(std.Thread) = std.ArrayList(std.Thread).init(allocator);
    defer threads.deinit();

    console.printf("{s}", .{Color.formatBackground(allocator, Color.BG.Yellow, Color.FG.Black, " Homeforwarder - SSH Forwarder ", true)});
    console.infof("Watching {s} services", .{Color.formatForeground(
        allocator,
        Color.FG.Green,
        try std.fmt.allocPrint(allocator, "{d}", .{config.services.len}),
    )});

    for (config.services) |service| {
        const thread = try std.Thread.spawn(.{}, startService, .{ allocator, service, config.forward_host, config.timeout });
        try threads.append(thread);
    }

    for (threads.items) |thread| thread.join();
}
