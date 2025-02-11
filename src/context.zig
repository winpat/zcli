const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;
const Value = @import("value.zig").Value;

/// Context for storing parsed arguments and options.
/// Will be passed to handler function.
pub const Context = struct {
    allocator: Allocator,
    opts: StringHashMap(Value),
    args: StringHashMap(Value),

    pub fn init(allocator: Allocator) Context {
        return .{
            .allocator = allocator,
            .opts = StringHashMap(Value).init(allocator),
            .args = StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Context) void {
        self.opts.deinit();
        self.args.deinit();
    }
};
