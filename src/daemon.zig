const std = @import("std");

const Common = @import("utils/common.zig");
const Config = @import("config.zig");
const Console = @import("utils/console.zig");
const DateTime = @import("utils/datetime.zig");

const Color = Common.Color;
const Daemon = @This();

allocator: std.mem.Allocator,
config: *Config,
console: Console,

pub fn init(allocator: std.mem.Allocator) !Daemon {
    var console = Console{ .allocator = allocator };

    const config_file = std.fs.cwd().openFileZ("config.json", .{}) catch |err| {
        switch (err) {
            error.FileNotFound => console.@"error"("Config file not found"),
            else => console.errorf("Failed to open config file: {}", .{err}),
        }

        return err;
    };
    defer config_file.close();

    const config_source = try config_file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(config_source);

    var parsed_config = std.json.parseFromSlice(Config, allocator, config_source, .{}) catch |err| {
        switch (err) {
            error.MissingField => console.@"error"("Failed to parse config: Missing field"),
            error.DuplicateField, error.UnknownField => console.@"error"("Failed to parse config: Duplicate or unknown field"),
            else => console.errorf("Failed to parse config: {}", .{err}),
        }

        return err;
    };
    defer parsed_config.deinit();

    const config = try Config.init(allocator, parsed_config.value.timeout, parsed_config.value.services, parsed_config.value.forward_host);

    return .{
        .allocator = allocator,
        .config = config,
        .console = console,
    };
}

pub fn deinit(self: Daemon) void {
    self.config.deinit(self.allocator);
}

pub fn startDaemon(self: Daemon) !void {
    var threads: std.ArrayList(std.Thread) = std.ArrayList(std.Thread).init(self.allocator);
    defer threads.deinit();

    self.console.printf("{s}", .{Color.formatBackground(self.allocator, Color.BG.Yellow, Color.FG.Black, " Homeforwarder - SSH Forwarder ", true)});
    self.console.infof("Watching {s} services", .{Color.formatForeground(
        self.allocator,
        Color.FG.Green,
        try std.fmt.allocPrint(self.allocator, "{d}", .{self.config.services.len}),
    )});

    for (self.config.services) |service| {
        const thread = try std.Thread.spawn(.{ .allocator = self.allocator }, runService, .{ self, service });

        try threads.append(thread);
    }

    for (threads.items) |thread| thread.join();
}

fn runService(self: Daemon, service: Config.Service) !void {
    while (true) {
        self.console.infof("Forwarding service {s} from {s}:{d} to {s}:{d} via {s}", .{
            Color.formatForeground(self.allocator, Color.FG.Magenta, service.name),
            service.hostname,
            service.connect_port,
            self.config.forward_host,
            service.forward_port,
            Color.formatForeground(self.allocator, Color.FG.Yellow, @tagName(service.protocol)),
        });

        switch (service.protocol) {
            .TCP => {
                const args = [_][]const u8{
                    "ssh",
                    "-N",
                    "-o",
                    "ExitOnForwardFailure=yes",
                    "-o",
                    try std.fmt.allocPrint(self.allocator, "ServerAliveInterval={d}", .{self.config.timeout}),
                    "-o",
                    "ServerAliveCountMax=1",
                    "-R",
                    try std.fmt.allocPrint(self.allocator, "{d}:{s}:{d}", .{ service.forward_port, service.hostname, service.connect_port }),
                    self.config.forward_host,
                };

                var process = std.process.Child.init(&args, self.allocator);
                process.spawn() catch |err| {
                    self.console.errorf("Couldn't spawn process {s}: {}", .{ service.name, err });
                    Common.sleep(5000);
                    continue;
                };

                _ = try process.wait();
            },
            .UNIX => return error.Unimplemented,
        }

        self.console.warnf("Daemon {s} has exited, restarting at {s}", .{
            Color.formatForeground(self.allocator, Color.FG.Magenta, service.name),
            Color.formatForeground(self.allocator, Color.FG.Yellow, DateTime.addSeconds(self.allocator, 5)),
        });
        Common.sleep(5000);
    }
}
