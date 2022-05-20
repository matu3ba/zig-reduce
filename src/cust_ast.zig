// customizations to Ast.zig and rendering.zig
const std = @import("std");
const render = @import("render.zig");
const mem = std.mem;
const Ast = std.zig.Ast;

const indent_delta = 4;
const asm_indent_delta = 2;
const Error = Ast.RenderError;
const Ais = render.AutoIndentingStream(std.ArrayList(u8).Writer);

pub fn renderNormal(tree: Ast, gpa: mem.Allocator) Error![]u8 {
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    try render.renderTree(&buffer, tree);
    return buffer.toOwnedSlice();
}

pub fn renderCustom(tree: Ast, gpa: mem.Allocator, skiplist: []u16) Error![]u8 {
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    //try render.renderTree(&buffer, tree);
    try renderTreeSkipBlock(&buffer, tree, skiplist);

    return buffer.toOwnedSlice();
}

pub fn renderTreeSkipBlock(buffer: *std.ArrayList(u8), tree: Ast, skiplist: []u16) Error!void {
    std.debug.assert(tree.errors.len == 0); // Cannot render an invalid tree.
    var auto_indenting_stream = Ais{
        .indent_delta = indent_delta,
        .underlying_writer = buffer.writer(),
    };
    const ais = &auto_indenting_stream;

    const members = tree.rootDecls();
    std.debug.assert(members.len > 0);
    var i_skiplist: u32 = 0;
    if (skiplist[i_skiplist] == 0) {
        i_skiplist += 1;
    } else {
        try render.renderMember(buffer.allocator, ais, tree, members[0], .newline);
    }
    for (members[1..]) |member, i| {
        std.debug.print("i_skiplist: {d}, i: {d}\n", .{ i_skiplist, i });
        std.debug.assert(skiplist[i_skiplist] >= i);
        if (skiplist[i_skiplist] == i + 1) {} else {
            std.debug.print("i_skiplist: {d}\n", .{i_skiplist});
            try render.renderExtraNewline(ais, tree, member);
            try render.renderMember(buffer.allocator, ais, tree, member, .newline);
        }
    }
}
