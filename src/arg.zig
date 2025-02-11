const Kind = @import("value.zig").Kind;

pub const Arg = struct {
    name: []const u8,
    kind: Kind,
};
