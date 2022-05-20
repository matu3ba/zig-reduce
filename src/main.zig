const std = @import("std");
const File = std.io.File;
const render = @import("render.zig");
const cust_ast = @import("cust_ast.zig");

// 0. build up data structure to know status
// 1. compile file (ie for testing, etc)
// 2. run file and compare output. depending on strategy goto 6.
// 3. store tmp copy to backtrack
// 4. reduce
// 5. goto 1.
// 6. write result file(s) into folder

const usage =
    \\ usage: zred 'compile_cmd' 'run_cmd' file.zig [opt]
    \\
    \\ with opt having leading dashes and being
    \\ TODO
;

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

pub fn main() anyerror!void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();
    // Note that info level log messages are by default printed only in Debug
    // and ReleaseSafe build modes.
    //std.log.info("All your codebase are belong to us.", .{});

    const file_name = "test/min.zig";
    var f = std.fs.cwd().openFile(file_name, .{}) catch |err| {
        fatal("unable to open file for zig-reduce '{s}': {s}", .{ file_name, @errorName(err) });
    };
    defer f.close();
    const stat = try f.stat();
    if (stat.size > std.math.maxInt(u32))
        return error.FileTooBig;
    const source = try arena.allocSentinel(u8, @intCast(usize, stat.size), 0);
    const amt = try f.readAll(source);
    if (amt <= 1)
        return error.EmptyFile;
    if (amt != stat.size)
        return error.UnexpectedEndOfFile;

    var tree = try std.zig.parse(arena, source);
    defer tree.deinit(arena);

    render.next_tree_i = 1; // initialize for children

    // print tree with libstd
    //const rendered_ast = try tree.render(arena);
    //defer arena.free(rendered_ast);
    //std.debug.print("tree:\n{s}", .{rendered_ast});

    const rendered_ast = try cust_ast.renderNormal(tree, arena);
    defer arena.free(rendered_ast);
    std.debug.print("tree:\n{s}", .{rendered_ast});

    // problem: render.zig is not referenced from std.zig
    // => rely on renderer and do operations on Ast.

    // TODO
    // 1. implement DFS traversal from rendering (stack, set)
    // 2. figure out if renderMember is sufficient
    //    - try to remove all writer commands
    //    - simplify traversing logic
    //    - more stuff?

    //var cnt_testdecls: u16 = 0;
    //const tree_rootdecls = tree.rootDecls();
    //for (tree_rootdecls) |tree_rootdecl| {
    //    switch (tree.nodes.items(.tag)[tree_rootdecl]) {
    //        .test_decl => {
    //            cnt_testdecls += 1;
    //        },
    //        else => {},
    //    }
    //}
    //std.debug.print("cnt_testdecls: {d}\n", .{cnt_testdecls});

    //var test_decl_indeces = try arena.alloc(u16, cnt_testdecls);
    //defer arena.free(test_decl_indeces);
    //{
    //    var next_index: u16 = 0;
    //    for (tree_rootdecls) |tree_rootdecl, i| {
    //        switch (tree.nodes.items(.tag)[tree_rootdecl]) {
    //            .test_decl => {
    //                test_decl_indeces[next_index] = @intCast(u16, i);
    //                next_index += 1;
    //            },
    //            else => {},
    //        }
    //    }
    //    // TODO analyze inner blocks
    //}
    //for (test_decl_indeces) |i|
    //    std.debug.print("i: {d}\n", .{i});
    //const rendered_ast_cust = try cust_ast.renderCustom(tree, arena, test_decl_indeces);
    //defer arena.free(rendered_ast_cust);
    //std.debug.print("tree:\n{s}", .{rendered_ast_cust});

    // option 1: delete blocks (Ast has no mark to delete stuff) => nope
    // option 2: ignore specific top level decl during rendering
    // => option 3: copy-paste rendering code + adjust it
    // use m-tree to represent code sections that must be skipped
    // NOTE: m-tree can not be used for overlapping segments
    // TODO fixup render.zig to provide a trackable id for each block
    // TODO think about how to tell render.zig what parts blocks to ignore

    // test blocks: .test_decl
    // usingnamespace:
}
