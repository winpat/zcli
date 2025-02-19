# zcli

A Zig library for building command-line interfaces.

* Parse options
  * Short `-s` and `long` names
  * Stop parsing options when encountering `--` delimiter
* Parse positional arguments
* Support for arbitrary sub commands
* Print help on `-h` and `--help`


This library is under development.

## Usage

1. Define an App struct with all your commands, options and arguments

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = App{
        .name = "calc",
        .root = .{
            .commands = &.{
                .{
                    .name = "add",
                    .handler = addTwo,
                    .options = &.{
                        .{ .name = "verbose", .short = "-v", .kind = .boolean },
                    },
                    .args = &.{
                        .{ .name = "a", .kind = .int },
                        .{ .name = "b", .kind = .int },
                    },
                },
            },
        },
    };

    try app.run(allocator);
}
```

1. `app.run()` will the dispatch parsed options/arguments to handler
   function of the command.

```zig
fn addTwo(ctx: *Context) void {
    const verbose = ctx.opts.get("verbose").?.boolean;

    const a = ctx.args.get("a").?.int;
    const b = ctx.args.get("b").?.int;
    const sum = a + b;

    if (verbose) {
        std.debug.print("Sum: {}", sum);
    } else {
        std.debug.print("{}", sum);
    }
}
```

## License

[MIT](./LICENSE)
