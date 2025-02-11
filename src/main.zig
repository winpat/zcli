const std = @import("std");
const App = @import("app.zig").App;
const Context = @import("context.zig").Context;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = App{
        .name = "app",
        .root = .{
            .commands = &.{
                .{
                    .name = "do",
                    .handler = printHelloWorld,
                    .options = &.{
                        .{
                            .name = "verbose",
                            .long = "--verbose",
                            .kind = .boolean,
                            .flag = true,
                        },
                        .{
                            .name = "count",
                            .long = "--count",
                            .kind = .int,
                        },
                        .{
                            .name = "ratio",
                            .long = "--ratio",
                            .kind = .float,
                        },
                        .{
                            .name = "name",
                            .long = "--name",
                            .kind = .string,
                        },
                    },
                    .args = &.{
                        .{
                            .name = "file-id",
                            .kind = .int,
                        },
                    },
                },
            },
        },
    };

    try app.run(allocator);
}

fn printHelloWorld(ctx: *Context) void {
    const name = ctx.args.get("file-id").?.int;
    std.debug.print("{any}\n", .{name});
}
