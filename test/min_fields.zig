test "fields" {
    const std = @import("std");
    _ = @import("./bla1");
    std.debug.print("field1\n", .{});
}
