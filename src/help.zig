const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const Allocator = std.mem.Allocator;

const Context = @import("context.zig").Context;
const Command = @import("command.zig").Command;
const Option = @import("option.zig").Option;

/// Print help for command.
pub fn printHelp(ctx: *Context) !void {
    const cmd = ctx.path.getLast();
    var writer = io.getStdOut().writer();

    try writer.print("{s}\n", .{cmd.name});
    if (cmd.commands) |cmds| try printCommands(writer, cmds);
    if (cmd.options) |opts| try printOptions(ctx.allocator, writer, opts);
}

fn printCommands(writer: anytype, cmds: []const Command) !void {
    try writer.writeAll("\nCommands:\n");
    const pad_width = findLongestCommandName(cmds);

    for (cmds) |cmd| {
        try writer.writeAll("  ");
        try printAligned(writer, cmd.name, pad_width);
        try writer.print("  {s}\n", .{cmd.description});
    }
}

fn findLongestCommandName(cmds: []const Command) usize {
    var max_length: usize = 0;
    for (cmds) |cmd| {
        const len = cmd.name.len;
        if (len > max_length) max_length = len;
    }
    return max_length;
}

fn printOptions(allocator: Allocator, writer: anytype, opts: []const Option) !void {
    try writer.writeAll("\nOptions:\n");
    const pad_width = try findLongestOptionName(allocator, opts);

    for (opts) |opt| {
        const usage_str = try buildOptionUsageStr(allocator, opt);
        defer allocator.free(usage_str);

        try writer.writeAll("  ");
        try printAligned(writer, usage_str, pad_width);
        try writer.print("  {s}\n", .{opt.description});
    }
}

fn findLongestOptionName(allocator: Allocator, opts: []const Option) !usize {
    var max_length: usize = 0;
    for (opts) |opt| {
        const usage_str = try buildOptionUsageStr(allocator, opt);
        defer allocator.free(usage_str);

        const len = usage_str.len;
        if (len > max_length) max_length = len;
    }
    return max_length;
}

fn buildOptionUsageStr(allocator: Allocator, opt: Option) ![]u8 {
    if (opt.flag) {
        if (opt.long != null and opt.short != null) {
            return try fmt.allocPrint(allocator, "{s}, {s}", .{ opt.short.?, opt.long.? });
        } else if (opt.short) |short| {
            return try fmt.allocPrint(allocator, "{s}", .{short});
        } else if (opt.long) |long| {
            return try fmt.allocPrint(allocator, "{s}", .{long});
        }
    } else {
        if (opt.long != null and opt.short != null) {
            return try fmt.allocPrint(allocator, "{s}, {s} <{s}>", .{ opt.short.?, opt.long.?, opt.name });
        } else if (opt.short) |short| {
            return try fmt.allocPrint(allocator, "{s} <{s}>", .{ short, opt.name });
        } else if (opt.long) |long| {
            return try fmt.allocPrint(allocator, "{s} <{s}>", .{ long, opt.name });
        }
    }
    unreachable;
}

fn printAligned(writer: anytype, msg: []const u8, width: usize) !void {
    try fmt.formatText(
        msg,
        "s",
        fmt.FormatOptions{ .width = width, .alignment = .left },
        writer,
    );
}
