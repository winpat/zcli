const std = @import("std");
const tst = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const Context = @import("context.zig").Context;
const Arg = @import("arg.zig").Arg;
const Value = @import("value.zig").Value;
const Option = @import("option.zig").Option;
const Command = @import("command.zig").Command;
const App = @import("app.zig").App;
const HandlerFn = @import("command.zig").HandlerFn;

/// Iterator over process arguments.
/// We call them tokens to avoid naming conflicts when parsing
/// positional arguments.
const TokenIterator = struct {
    tokens: []const [:0]const u8 = undefined,
    pos: usize = 0,

    /// Return next token.
    fn next(self: *TokenIterator) ?[:0]const u8 {
        if (self.pos == self.tokens.len) return null;
        defer self.pos += 1;
        return self.tokens[self.pos];
    }

    /// Peek at next token but don't advance.
    fn peek(self: *TokenIterator) ?[:0]const u8 {
        if (self.pos == self.tokens.len) return null;
        return self.tokens[self.pos];
    }

    /// Skip the next token.
    fn skip(self: *TokenIterator) void {
        if (self.pos != self.tokens.len) self.pos += 1;
    }
};

fn hasPrefix(string: []const u8, prefix: []const u8) bool {
    for (0..prefix.len) |idx| {
        if (prefix[idx] != string[idx]) {
            return false;
        }
    }
    return true;
}

fn isOption(arg: []const u8) bool {
    return hasPrefix(arg, "-");
}

const ParseError = error{
    /// Option was not expected.
    CommandUnknown,
    /// Command is required but not provided.
    CommandMissing,
    /// Command is missing handler.
    CommandMissingHandler,
    /// Option was not expected.
    OptionUnknown,
    /// Option is required but not provided.
    OptionMissing,
    /// Option value was of wrong type.
    OptionValueInvalid,
    /// Option value was not provided.
    OptionValueMissing,
    /// Argument was not expected.
    ArgUnknown,
    /// Argument is required but not provided.
    ArgMissing,
    /// Argument was of wrong type.
    ArgInvalid,
} || Allocator.Error;

pub const Parser = struct {
    allocator: Allocator,
    app: App,
    ctx: *Context,

    err: ?[]const u8 = null,

    pub fn init(allocator: Allocator, app: App) Allocator.Error!Parser {
        const ctx = try allocator.create(Context);
        ctx.* = Context.init(allocator);
        return .{
            .allocator = allocator,
            .app = app,
            .ctx = ctx,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.ctx.deinit();
        self.allocator.destroy(self.ctx);
    }

    /// Indicate that parsing has failed by storing an error message
    /// and return error.
    pub fn fail(self: *Parser, err: ParseError, comptime fmt: []const u8, args: anytype) ParseError {
        self.err = try std.fmt.allocPrint(self.allocator, fmt, args);
        return err;
    }

    /// Parse arguments and options.
    /// Returns the handler function to call and a context with
    /// the parsed data.
    pub fn parse(self: *Parser, input: []const [:0]const u8) ParseError!struct { HandlerFn, *Context } {

        // The first argument to an execetuable is the path to the
        // executable itself. We don't need it, so we omit it.
        var iter = TokenIterator{ .tokens = input[1..] };

        var cmd = self.app.root;
        // TODO Refactor this so we don't have to do this outside of the loop.
        if (cmd.options) |opts| try self.parseOptions(opts, &iter);

        while (cmd.commands != null) {
            if (cmd.commands) |cmds| cmd = try self.parseSubcommand(cmds, &iter);
            if (cmd.options) |opts| try self.parseOptions(opts, &iter);
        }

        if (cmd.args) |args| {
            try self.parseArgs(args, &iter);
        }

        if (cmd.handler) |handler| {
            return .{ handler, self.ctx };
        } else {
            return self.fail(
                error.CommandMissingHandler,
                "Command \"{s}\" is missing a handler function.",
                .{cmd.name},
            );
        }
    }

    /// Parse subcommand.
    fn parseSubcommand(self: *Parser, cmds: []const Command, iter: *TokenIterator) ParseError!Command {
        const tk = iter.next() orelse {
            return self.fail(error.CommandMissing, "Expected command.", .{});
        };

        for (cmds) |cmd| {
            if (mem.eql(u8, cmd.name, tk)) {
                return cmd;
            }
        }

        return self.fail(error.CommandUnknown, "Unknown command \"{s}\".", .{tk});
    }

    /// Parse options and push them to context.
    fn parseOptions(self: *Parser, opts: []const Option, iter: *TokenIterator) ParseError!void {
        // Save the option default values to context.
        for (opts) |opt| {
            switch (opt.kind) {
                .boolean => try self.ctx.opts.put(opt.name, Value{ .boolean = false }),
                else => continue,
            }
        }

        while (iter.peek()) |opt_name| {
            // On POSIX systems "--" is the delimiter to indicate that
            // we can stop trying to parse options.
            if (mem.eql(u8, opt_name, "--")) {
                iter.skip();
                return;
            }

            if (!isOption(opt_name)) return;
            iter.skip();

            const opt = for (opts) |opt| {
                if (opt.match(opt_name)) break opt;
            } else {
                return self.fail(error.OptionUnknown, "Unknown option \"{s}\"", .{opt_name});
            };

            if (opt.flag) {
                // Options who's presence indicate a truthy value.
                try self.ctx.opts.put(opt.name, .{ .boolean = true });
            } else {
                // Options which expect an additional token holding the value.
                const opt_val = iter.next() orelse {
                    return self.fail(error.OptionValueMissing, "Option \"{s}\" is missing value.", .{opt.name});
                };

                const val = Value.parse(opt.kind, opt_val) catch {
                    return self.fail(error.OptionValueInvalid, "Invalid value \"{s}\" to option \"{s}\"", .{ opt_val, opt.name });
                };
                try self.ctx.opts.put(opt.name, val);
            }
        }
    }

    /// Parse arguments and push them to context.
    fn parseArgs(self: *Parser, args: []const Arg, iter: *TokenIterator) ParseError!void {
        for (args) |arg| {
            const tk = iter.next() orelse {
                return self.fail(error.ArgMissing, "Required argument \"{s}\" was not provided.", .{arg.name});
            };

            const val = Value.parse(arg.kind, tk) catch {
                return self.fail(error.ArgInvalid, "Invalid value \"{s}\" to argument \"{s}\"", .{ tk, arg.name });
            };

            try self.ctx.args.put(arg.name, val);
        }

        if (iter.next()) |tk| {
            return self.fail(error.ArgUnknown, "Unexpected argument \"{s}\".", .{tk});
        }
    }
};

fn printHelloWorld(ctx: *Context) void {
    _ = ctx;
    std.debug.print("Hello World\n", .{});
}

test "Parse command" {
    const app = App{
        .name = "app",
        .root = .{
            .commands = &.{
                .{
                    .name = "do",
                    .handler = printHelloWorld,
                },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "do" };
    const handler, _ = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
}

test "Parse arg" {
    const app = App{
        .name = "app",
        .root = .{
            .handler = printHelloWorld,
            .args = &.{
                .{
                    .name = "a",
                    .kind = .int,
                },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "12" };
    const handler, const ctx = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
    try tst.expectEqual(12, ctx.args.get("a").?.int);
}

test "Parse multiple args" {
    const app = App{
        .name = "app",
        .root = .{
            .handler = printHelloWorld,
            .args = &.{
                .{ .name = "a", .kind = .int },
                .{ .name = "b", .kind = .boolean },
                .{ .name = "c", .kind = .string },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "12", "true", "test" };
    const handler, const ctx = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
    try tst.expectEqual(12, ctx.args.get("a").?.int);
    try tst.expectEqual(true, ctx.args.get("b").?.boolean);
    try tst.expectEqual("test", ctx.args.get("c").?.string);
}

test "Parse option" {
    const app = App{
        .name = "app",
        .root = .{
            .handler = printHelloWorld,
            .options = &.{
                .{
                    .name = "count",
                    .long = "--count",
                    .kind = .int,
                },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "--count", "12" };
    const handler, const ctx = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
    try tst.expectEqual(12, ctx.opts.get("count").?.int);
}

test "Parse multiple options" {
    const app = App{
        .name = "app",
        .root = .{
            .handler = printHelloWorld,
            .options = &.{
                .{
                    .name = "count",
                    .long = "--count",
                    .kind = .int,
                },
                .{
                    .name = "verbose",
                    .short = "-v",
                    .kind = .boolean,
                },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "--count", "12", "-v", "true" };
    const handler, const ctx = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
    try tst.expectEqual(12, ctx.opts.get("count").?.int);
    try tst.expectEqual(true, ctx.opts.get("verbose").?.boolean);
}

test "Parse command with args and options" {
    const app = App{
        .name = "calc",
        .root = .{
            .commands = &.{
                .{
                    .name = "add",
                    .handler = printHelloWorld,
                    .options = &.{
                        .{
                            .name = "verbose",
                            .short = "-v",
                            .kind = .boolean,
                        },
                    },
                    .args = &.{
                        .{ .name = "a", .kind = .int },
                        .{ .name = "b", .kind = .int },
                    },
                },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "add", "-v", "true", "12", "42" };
    const handler, const ctx = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
    try tst.expectEqual(true, ctx.opts.get("verbose").?.boolean);
    try tst.expectEqual(12, ctx.args.get("a").?.int);
    try tst.expectEqual(42, ctx.args.get("b").?.int);
}

test "Stop option parsing on --" {
    const app = App{
        .name = "calc",
        .root = .{
            .handler = printHelloWorld,
            .options = &.{
                .{
                    .name = "file",
                    .short = "--file",
                    .kind = .string,
                },
            },
            .args = &.{
                .{ .name = "file", .kind = .string },
            },
        },
    };

    var parser = try Parser.init(tst.allocator, app);
    defer parser.deinit();

    const args: []const [:0]const u8 = &.{ "cli", "--", "--file" };
    const handler, const ctx = try parser.parse(args);

    try tst.expectEqual(printHelloWorld, handler);
    try tst.expectEqual(0, ctx.opts.count());
    try tst.expectEqual("--file", ctx.args.get("file").?.string);
}
