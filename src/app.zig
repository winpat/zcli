const std = @import("std");
const io = std.io;
const process = std.process;
const Allocator = std.mem.Allocator;

const Command = @import("command.zig").Command;
const Parser = @import("parser.zig").Parser;
const help = @import("help.zig");

pub const App = struct {
    name: []const u8,
    description: []const u8 = "",

    root: Command,

    pub fn run(self: App, allocator: Allocator) !void {
        const args = try process.argsAlloc(allocator);

        var parser = try Parser.init(allocator, self);
        const handler, const ctx = parser.parse(args) catch |err| {
            var stderr = io.getStdErr().writer();
            if (parser.err) |err_msg| {
                try stderr.print("{s}\n", .{err_msg});
            } else {
                try stderr.print("Unknown error: {any}\n", .{err});
            }

            process.exit(1);
        };

        try handler(ctx);
    }
};
