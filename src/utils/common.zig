const std = @import("std");

const Foreground = struct {
    pub const Black = "\x1b[30m";
    pub const Red = "\x1b[31m";
    pub const Green = "\x1b[32m";
    pub const Yellow = "\x1b[33m";
    pub const Blue = "\x1b[34m";
    pub const Magenta = "\x1b[35m";
    pub const Cyan = "\x1b[36m";
    pub const White = "\x1b[37m";
};

const Background = struct {
    pub const Black = "\x1b[40m";
    pub const Red = "\x1b[41m";
    pub const Green = "\x1b[42m";
    pub const Yellow = "\x1b[43m";
    pub const Blue = "\x1b[44m";
    pub const Magenta = "\x1b[45m";
    pub const Cyan = "\x1b[46m";
    pub const White = "\x1b[47m";
};

const Text = struct {
    pub const Bold = "\x1b[1m";
    pub const Underline = "\x1b[4m";
    pub const Normal = "\x1b[22m";
    pub const Blink = "\x1b[5m";
};

pub const Color = struct {
    pub const FG = Foreground;
    pub const BG = Background;
    pub const TEXT = Text;

    pub const Clear = "\x1b[0m";
    pub const Transparent = "\x1b[8m";

    pub fn formatForeground(allocator: std.mem.Allocator, color: []const u8, text: []const u8) []const u8 {
        return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ color, text, Color.Clear }) catch unreachable;
    }

    pub fn formatBackground(allocator: std.mem.Allocator, background: []const u8, foreground: []const u8, text: []const u8, is_bold: bool) []const u8 {
        if (is_bold) {
            return std.fmt.allocPrint(allocator, "{s}{s}{s}{s}{s}{s}", .{ Color.TEXT.Bold, background, foreground, text, Color.TEXT.Normal, Color.Clear }) catch unreachable;
        }

        return std.fmt.allocPrint(allocator, "{s}{s}{s}{s}", .{ background, foreground, text, Color.Clear }) catch unreachable;
    }
};

pub fn sleep(ms: u64) void {
    std.time.sleep(std.time.ns_per_ms * ms);
}

pub fn minify(allocator: std.mem.Allocator, input: []const u8) []u8 {
    var temp_buf: [1024]u8 = undefined;

    _ = std.mem.replace(u8, input, "\n", "", &temp_buf);
    return std.mem.replaceOwned(u8, allocator, &temp_buf, " ", "") catch unreachable;
}
