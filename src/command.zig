const std = @import("std");
const Allocator = std.mem.Allocator;

const Option = @import("option.zig").Option;
const Context = @import("context.zig").Context;
const Value = @import("value.zig").Value;
const Arg = @import("arg.zig").Arg;

pub const HandlerFn = *const fn (*Context) anyerror!void;

pub const Command = struct {
    name: []const u8 = "root",
    description: []const u8 = "",

    handler: ?HandlerFn = null,

    commands: ?[]const Command = null,
    options: ?[]const Option = null,
    args: ?[]const Arg = null,
};
