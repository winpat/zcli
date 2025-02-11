const std = @import("std");
const mem = std.mem;
const Kind = @import("value.zig").Kind;

pub const Option = struct {
    name: []const u8,
    kind: Kind,

    long: ?[]const u8 = null,
    short: ?[]const u8 = null,

    flag: bool = false,

    /// Check if argument matches the name of the option.
    pub fn match(self: Option, arg: []const u8) bool {
        return (self.long != null and mem.eql(u8, self.long.?, arg)) or
            (self.short != null and mem.eql(u8, self.short.?, arg));
    }
};
