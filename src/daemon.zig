const std = @import("std");

const Common = @import("utils/common.zig");
const Config = @import("config.zig");
const Console = @import("utils/console.zig");
const DateTime = @import("utils/datetime.zig");

const Color = Common.Color;
const Daemon = @This();

pub const DaemonError = error{NoServices} || std.fmt.AllocPrintError || std.Thread.SpawnError;

allocator: std.mem.Allocator,
config: *Config,
console: Console,

pub fn init(allocator: std.mem.Allocator) !Daemon {
    var console = Console{ .allocator = allocator };

    const config_file = std.fs.cwd().openFileZ("config.json", .{}) catch |err| {
        var cwd: [std.fs.max_path_bytes]u8 = undefined;
        _ = std.posix.getcwd(&cwd) catch unreachable;
        console.logf("Failed to find config file in path: {s} with error: {}", .{ cwd, err });

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
        const minified_json = Common.minify(allocator, config_source);
        defer allocator.free(minified_json);
        console.logf("Failed to parse config: {s}", .{minified_json});

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

pub fn startDaemon(self: Daemon) DaemonError!void {
    var threads: std.ArrayList(std.Thread) = std.ArrayList(std.Thread).init(self.allocator);
    defer threads.deinit();

    const colored_start_message = Color.formatBackground(self.allocator, Color.BG.Yellow, Color.FG.Black, " Homeforwarder - SSH Forwarder ", true);
    defer self.allocator.free(colored_start_message);

    self.console.printf("{s}", .{colored_start_message});

    if (self.config.services.len == 0) {
        self.console.warn("No services to watch, exiting");

        return DaemonError.NoServices;
    }

    const formatted_services = try std.fmt.allocPrint(self.allocator, "{d}", .{self.config.services.len});
    const colored_services = Color.formatForeground(self.allocator, Color.FG.Green, formatted_services);

    defer {
        self.allocator.free(formatted_services);
        self.allocator.free(colored_services);
    }

    self.console.infof("Watching {s} {s}", .{
        colored_services,
        if (self.config.services.len == 1) "service" else "services",
    });

    for (self.config.services) |service| {
        const thread = try std.Thread.spawn(.{ .allocator = self.allocator }, runService, .{ self, service });

        try threads.append(thread);
    }

    for (threads.items) |thread| thread.join();
}

fn runService(self: Daemon, service: Config.Service) !void {
    while (true) {
        var colored_service_name = Color.formatForeground(self.allocator, Color.FG.Magenta, service.name);
        const colored_protocol = Color.formatForeground(self.allocator, Color.FG.Yellow, @tagName(service.protocol));

        defer {
            self.allocator.free(colored_service_name);
            self.allocator.free(colored_protocol);
        }

        self.console.infof("Forwarding service {s} from {s}:{d} to {s}:{d} via {s}", .{
            colored_service_name,
            service.hostname,
            service.connect_port,
            self.config.forward_host,
            service.forward_port,
            colored_protocol,
        });

        const formatted_timeout = try std.fmt.allocPrint(self.allocator, "ServerAliveInterval={d}", .{self.config.timeout});
        const formatted_forwarding_info = try std.fmt.allocPrint(self.allocator, "{d}:{s}:{d}", .{ service.forward_port, service.hostname, service.connect_port });

        defer {
            self.allocator.free(formatted_timeout);
            self.allocator.free(formatted_forwarding_info);
        }

        switch (service.protocol) {
            .TCP => {
                const args = [_][]const u8{
                    "ssh",
                    "-N",
                    "-o",
                    "ExitOnForwardFailure=yes",
                    "-o",
                    formatted_timeout,
                    "-o",
                    "ServerAliveCountMax=1",
                    "-R",
                    formatted_forwarding_info,
                    self.config.forward_host,
                };

                var process = std.process.Child.init(&args, self.allocator);

                // Don't care about stdout, but we want to handle stderr more gracefully
                process.stdout_behavior = .Ignore;
                process.stderr_behavior = .Pipe;

                process.spawn() catch |err| {
                    self.console.errorf("Couldn't spawn process {s}: {}", .{ service.name, err });
                    Common.sleep(5000);
                    continue;
                };

                var ebuf: [1024]u8 = undefined;
                if (process.stderr) |stderr| {
                    const reader = stderr.reader();
                    const size = try reader.read(&ebuf);

                    colored_service_name = Color.formatForeground(self.allocator, Color.FG.Magenta, service.name);
                    const colored_error = Color.formatForeground(self.allocator, Color.FG.Red, std.mem.trim(u8, ebuf[0..size], "\n"));

                    defer {
                        self.allocator.free(colored_service_name);
                        self.allocator.free(colored_error);
                    }

                    self.console.errorf("Service {s} received error: {s}", .{
                        colored_service_name,
                        colored_error,
                    });
                }

                _ = try process.wait();
            },
            .UNIX => return error.Unimplemented,
        }

        colored_service_name = Color.formatForeground(self.allocator, Color.FG.Magenta, service.name);
        const colored_sleep_time = Color.formatForeground(self.allocator, Color.FG.Yellow, DateTime.addSeconds(self.allocator, 5));

        defer {
            self.allocator.free(colored_service_name);
            self.allocator.free(colored_sleep_time);
        }

        self.console.warnf("Service {s} has exited, restarting at {s}", .{
            colored_service_name,
            colored_sleep_time,
        });
        Common.sleep(5000);
    }
}
