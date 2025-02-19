const std = @import("std");
const App = @import("app.zig").App;
const Context = @import("context.zig").Context;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = App{
        .name = "app",
        .root = .{
            .options = &.{.{
                .name = "test",
                .kind = .int,
            }},
            .commands = &.{
                .{
                    .name = "do",
                    .description = "Print hello world",
                    .handler = printHelloWorld,
                    .options = &.{
                        .{
                            .name = "verbose",
                            .description = "Print more.",
                            .long = "--verbose",
                            .short = "-v",
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
                            .short = "--short",
                            .kind = .float,
                            .description = "Ratio of stuff",
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
                .{
                    .name = "verylongcommand",
                    .handler = printHelloWorld,
                    .description = "Long command",
                },
            },
        },
    };

    try app.run(allocator);
}

fn printHelloWorld(ctx: *Context) !void {
    const name = ctx.args.get("file-id").?.int;
    std.debug.print("{any}\n", .{name});
}
