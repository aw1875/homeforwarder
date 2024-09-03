const std = @import("std");

const Config = @This();

const Protocol = enum(u8) { TCP, UNIX };
pub const Service = struct {
    /// Service name
    name: []const u8,

    /// Hostname of service host system
    hostname: []const u8,

    /// Port of service running on host system
    connect_port: u16,

    /// Port of service to forward to forwarded system
    forward_port: u16,

    /// Protocol of service - TCP or UNIX
    protocol: Protocol,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, hostname: []const u8, connect_port: u16, forward_port: u16, protocol: Protocol) !Service {
        return Service{
            .name = try allocator.dupe(u8, name),
            .hostname = try allocator.dupe(u8, hostname),
            .connect_port = connect_port,
            .forward_port = forward_port,
            .protocol = protocol,
        };
    }

    pub fn deinit(self: *Service, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.hostname);
    }
};

/// SSH timeout in seconds
timeout: u8,

/// List of services to forward
services: []Service,

/// Hostname of forwarded system
forward_host: []const u8,

pub fn init(allocator: std.mem.Allocator, timeout: u8, services: []Service, forward_host: []const u8) !*Config {
    var config = try allocator.create(Config);

    config.timeout = timeout;

    config.services = try allocator.alloc(Service, services.len);
    for (services, 0..) |service, i| {
        config.services[i] = try Service.init(allocator, service.name, service.hostname, service.connect_port, service.forward_port, service.protocol);
    }

    config.forward_host = try allocator.dupe(u8, forward_host);

    return config;
}

pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
    for (self.services) |*service| {
        service.deinit(allocator);
    }

    allocator.free(self.services);
    allocator.free(self.forward_host);
    allocator.destroy(self);
}
