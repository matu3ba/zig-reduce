const std = @import("std");
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
    bruh: u1,
    fn testme() void {
        std.debug.print("123\n", .{});
    }
    test "test3" {
        {
            std.debug.print("123\n", .{});
            std.debug.print("123\n", .{});
        }
        std.debug.print("123\n", .{});
        std.debug.print("123\n", .{});
        // a comment
    }
};
