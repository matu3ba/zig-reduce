// customizations to Ast.zig and rendering.zig
const std = @import("std");
const render = @import("render.zig");
const mem = std.mem;
const Ast = std.zig.Ast;

const indent_delta = 4;
const asm_indent_delta = 2;
const Error = Ast.RenderError;
const Ais = render.AutoIndentingStream(std.ArrayList(u8).Writer);

pub fn renderCustom(tree: Ast, gpa: mem.Allocator) Error![]u8 {
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    //try render.renderTree(&buffer, tree);
    try renderTreeSkipBlock(&buffer, tree);

    return buffer.toOwnedSlice();
}

pub fn renderTreeSkipBlock(buffer: *std.ArrayList(u8), tree: Ast) Error!void {
    std.debug.assert(tree.errors.len == 0); // Cannot render an invalid tree.
    var auto_indenting_stream = Ais{
        .indent_delta = indent_delta,
        .underlying_writer = buffer.writer(),
    };
    const ais = &auto_indenting_stream;

    const members = tree.rootDecls();
    std.debug.assert(members.len > 0);
    //if(
    try render.renderMember(buffer.allocator, ais, tree, members[0], .newline);
    for (members[1..]) |member| {
        try render.renderExtraNewline(ais, tree, member);
        try render.renderMember(buffer.allocator, ais, tree, member, .newline);
    }
}
