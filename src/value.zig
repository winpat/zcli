const std = @import("std");
const mem = std.mem;

pub const Kind = enum {
    boolean,
    int,
    float,
    string,
};

pub const Value = union(Kind) {
    boolean: bool,
    int: i64,
    float: f64,
    string: []const u8,

    pub fn parse(kind: Kind, arg: []const u8) !Value {
        return switch (kind) {
            .boolean => try parseBoolean(arg),
            .int => try parseInt(arg),
            .float => try parseFloat(arg),
            .string => try parseString(arg),
        };
    }
};

/// Parse boolean option.
fn parseBoolean(arg: []const u8) !Value {
    if (mem.eql(u8, arg, "true")) {
        return .{ .boolean = true };
    } else if (mem.eql(u8, arg, "false")) {
        return .{ .boolean = false };
    } else {
        return error.InvalidValue;
    }
}

/// Parse integer option.
fn parseInt(arg: []const u8) !Value {
    return .{
        .int = std.fmt.parseInt(i64, arg, 10) catch return error.InvalidValue,
    };
}

/// Parse float option.
fn parseFloat(arg: []const u8) !Value {
    return .{
        .float = std.fmt.parseFloat(f64, arg) catch return error.InvalidValue,
    };
}

/// Parse string option.
fn parseString(arg: []const u8) !Value {
    return .{ .string = arg };
}
