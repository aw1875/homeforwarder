const std = @import("std");

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
};

/// SSH timeout in seconds
timeout: u8,

/// List of services to forward
services: []Service,

/// Hostname of forwarded system
forward_host: []const u8,
