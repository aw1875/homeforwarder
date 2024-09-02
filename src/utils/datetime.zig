const std = @import("std");

const DateTime = @This();
const EpochSeconds = std.time.epoch.EpochSeconds;
const DaySeconds = std.time.epoch.DaySeconds;
const Instant = std.time.Instant;

years: u16,
months: u4,
day: u5,
hours: u5,
minutes: u6,
seconds: u6,

pub fn init(timestamp: i64) DateTime {
    // Year, month, day
    const epoch_seconds = EpochSeconds{ .secs = @as(u64, @intCast(timestamp)) };
    const epoch_day = epoch_seconds.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const years = year_day.year;
    const months = year_day.calculateMonthDay().month.numeric();
    const day = @as(u5, year_day.calculateMonthDay().day_index + 1);

    // Hours, minutes, seconds, ms
    const day_seconds = epoch_seconds.getDaySeconds();
    const hours = day_seconds.getHoursIntoDay();
    const minutes = day_seconds.getMinutesIntoHour();
    const seconds = day_seconds.getSecondsIntoMinute();

    return DateTime{
        .years = years,
        .months = months,
        .day = day,
        .hours = hours,
        .minutes = minutes,
        .seconds = seconds,
    };
}

/// Returns the ISO 8601 string representation of the date-time.
pub fn toISOString(self: DateTime, allocator: std.mem.Allocator) []u8 {
    // YYYY-MM-DD HH:mm:ss
    const buff = std.fmt.allocPrint(allocator, "{:0>4}-{:0>2}-{:0>2}T{d:0>2}:{d:0>2}:{d:0>2}", .{
        self.years,
        self.months,
        self.day,
        self.hours,
        self.minutes,
        self.seconds,
    }) catch @panic("Failed to format timestamp");

    const owned_buff = allocator.alignedAlloc(u8, null, buff.len) catch @panic("Failed to allocate memory");
    @memcpy(owned_buff, buff); // Copy the stack buffer to the heap buffer
    @memset(buff, undefined); // Zero out the stack buffer

    return owned_buff;
}

pub fn now(allocator: std.mem.Allocator) []u8 {
    const datetime = init(std.time.timestamp());

    return datetime.toISOString(allocator);
}

pub fn addSeconds(allocator: std.mem.Allocator, seconds: u6) []u8 {
    const timestamp = @as(i64, std.time.timestamp() + seconds);
    const datetime = init(timestamp);

    return datetime.toISOString(allocator);
}
