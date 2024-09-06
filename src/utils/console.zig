const std = @import("std");

const Color = @import("common.zig").Color;
const DateTime = @import("datetime.zig");

pub const LogLevel = enum(usize) {
    Debug,
    Info,
    Warn,
    Error,

    fn getColor(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => Color.FG.White,
            .Info => Color.FG.Cyan,
            .Warn => Color.FG.Yellow,
            .Error => Color.FG.Red,
        };
    }

    fn getString(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "[DEBG]",
            .Info => "[INFO]",
            .Warn => "[WARN]",
            .Error => "[EROR]",
        };
    }
};

const Self = @This();
allocator: std.mem.Allocator,

fn writeLog(
    self: Self,
    log_level: LogLevel,
    comptime message: []const u8,
    args: anytype,
) void {
    const file = switch (log_level) {
        .Debug, .Info => std.io.getStdOut(),
        .Warn, .Error => std.io.getStdErr(),
    };

    file.lock(.exclusive) catch unreachable;
    defer file.unlock();

    var bw = std.io.bufferedWriter(file.writer());
    const output = bw.writer();

    const timestamp = DateTime.now(self.allocator);
    defer self.allocator.free(timestamp);

    const colored_output = Color.formatForeground(self.allocator, log_level.getColor(), log_level.getString());
    defer self.allocator.free(colored_output);

    output.print("{s} ({s}) ", .{ colored_output, timestamp }) catch unreachable;
    output.print(message, args) catch unreachable;
    output.print("\n", .{}) catch unreachable;

    bw.flush() catch unreachable;
}

fn writeMessage(
    _: Self,
    comptime message: []const u8,
    args: anytype,
) void {
    const file = std.io.getStdOut();

    file.lock(.exclusive) catch unreachable;
    defer file.unlock();

    var bw = std.io.bufferedWriter(file.writer());
    const output = bw.writer();

    output.print(message, args) catch unreachable;
    output.print("\n", .{}) catch unreachable;

    bw.flush() catch unreachable;
}

pub fn print(self: Self, comptime message: []const u8) void {
    self.writeMessage(message, .{});
}

pub fn printf(self: Self, comptime message: []const u8, args: anytype) void {
    self.writeMessage(message, args);
}

pub fn log(self: Self, comptime message: []const u8) void {
    if (std.posix.getenv("DEBUG")) |_| {
        self.writeLog(LogLevel.Debug, message, .{});
    }
}

pub fn logf(self: Self, comptime message: []const u8, args: anytype) void {
    if (std.posix.getenv("DEBUG")) |_| {
        self.writeLog(LogLevel.Debug, message, args);
    }
}

pub fn info(self: Self, comptime message: []const u8) void {
    self.writeLog(LogLevel.Info, message, .{});
}

pub fn infof(self: Self, comptime message: []const u8, args: anytype) void {
    self.writeLog(LogLevel.Info, message, args);
}

pub fn warn(self: Self, comptime message: []const u8) void {
    self.writeLog(LogLevel.Warn, message, .{});
}

pub fn warnf(self: Self, comptime message: []const u8, args: anytype) void {
    self.writeLog(LogLevel.Warn, message, args);
}

pub fn @"error"(self: Self, comptime message: []const u8) noreturn {
    self.writeLog(LogLevel.Error, message, .{});
    std.posix.exit(1);
}

pub fn errorf(self: Self, comptime message: []const u8, args: anytype) void {
    self.writeLog(LogLevel.Error, message, args);
}
