// renderMember does render
// * all top level decls
// * all blocks (when {}-braces start)
// renderMember does not render
// * the stuff inside in blocks

const std = @import("std");
const io = std.io;

usingnamespace @import("test/foo.zig");
const C = struct {
    bruh: u1,
};
// A comment
test "first test" {
    // a comment
}

pub fn main() !void {
    std.debug.print("123\n", .{});
    const bla = @import("std");
    _ = bla;
}

test "second test" {
    // a comment
}

const testme = struct {
    fn testme() void {
        std.debug.print("123\n", .{});
        std.debug.print("123\n", .{});
    }
};

const test1 = struct {
    const test2 = struct {
        test "testinner1" {
            std.debug.print("123\n", .{});
        }
    };
    const test3 = struct {
        test "testinner2" {
            std.debug.print("123\n", .{});
        }
    };
};
