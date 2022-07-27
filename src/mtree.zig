//! Access time optimized MultiTree (MTree)
const std = @import("std");
const mem = std.mem;

// Motiviation
// renderMember recursively called
//                a
//         b               b
//      c1     c         c     c    c
//     d1 d2   d d       d d   d d  d d
// Good strategy requires not to search through c and d, if removing b with
// children of b could not reproduce the issue.

// Principle
// COUNT STUFF - step 1
// - count for each node number of children
//   + space to annotate number of children
// - count total nodes
// DFS - step 2
// global:
// - counter
// - next free cell
// 1. originaddress_nodes[counter]
// 2. address_nodes[counter]
//                      |  |  |
// 1. a cnt_children:3 c1 c2 c3, address to modify: &c1
// 2. a cnt_children:3 c1 c2 c3, c1 cnt_children:2 c1c1 c1c2,
//    u32    u8      u32 u32 u32 u32     u8        u32  u32
// => temporary 2x memory necessary and 2x iterations necessary

// Alternative principle (operate on reverse tree)
// construct inverse tree + separate hash map with
// key a/b/c1/c2 to value count + offset
// a b|a c1|b d1|c1 d2|c1 c2|b d1|c2 d2|c2
// leafs: d1d2 d1d2 d1d2
// apply backwards bfs => unecessary

const Con = struct {
    from: u32,
    to: u32,
};

// example for BFS traversal (ids are shown)
//                0
//         5               7
//      4  3  1          2   6
const example_tree = [_]Con{
    .{ .from = 0, .to = 5 },
    .{ .from = 0, .to = 7 },
    .{ .from = 5, .to = 4 },
    .{ .from = 5, .to = 3 },
    .{ .from = 5, .to = 1 },
    .{ .from = 7, .to = 2 },
    .{ .from = 7, .to = 6 },
};

// each entry is form form <id len child_id1 child_id2 ..>
// with child_id1, child_id2 being absolute positions

//              0 1 2 3 4 5 6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
// BFS result: [0 2 4 9 5 3 19 17 13 7 2  15 21 1  0  2  0  3  0  4  0  6  0]
//  addresses   0   5 7     4  3  1       2  6

/// Returns MultiTree.
/// Requires cnt_parent_nodes*T*2 + cnt_children_nodes*T memory.
/// and during construction additonally cnt_children_nodes*T memory
/// Root id is 0 and starts at index 0.
/// assume: IDs are continuous set 0..id_cnt-1
/// assume: each child has exactly 1 incoming edge.
/// assume: parent has at most 2^(15)-1 children.
/// assume: T can hold all slice addresses and ids
fn initMTree(comptime T: type, alloc: mem.Allocator, tree: []const Con, id_cnt: u32) error{OutOfMemory}![]u32 {
    //const type_i = @typeInfo(T);
    //comptime std.debug.assert(type_i == .Int and type_i.?.signedness == .unsigned);
    //const sizeT = @sizeOf(T);

    var children_per_parent = try std.ArrayList(u8).initCapacity(alloc, 1);
    defer children_per_parent.deinit();
    var size: u32 = 1;

    // for API simplicity we compute size, but this is known t caller
    for (tree) |con| {
        if (con.from > size)
            size = con.from;
    }
    size += 1; // take into account 0-based indexing for size
    try children_per_parent.resize(size);
    for (children_per_parent.items) |*child| {
        child.* = 0; // 0 initialize
    }
    for (tree) |con| {
        children_per_parent.items[con.from] += 1;
    }
    // cnt_nodes*sizeof(T)*cnt_children for children addresses
    var mem_size: T = 0;
    for (children_per_parent.items) |cnt_children|
        mem_size += cnt_children;
    // cnt_nodes*sizeof(T)*2 for node identifier and number of children
    var mtree_memsize: T = @intCast(T, children_per_parent.items.len) * 2 + mem_size;

    var mtree = try alloc.alloc(T, mtree_memsize);
    // each entry is form form <id len child_id1 child_id2 ..>, child_id1 being position in slice
    var next_i: T = 2; // next free index in mtree

    // assume: con is BFS traversed (src,target1),(src,target2)..
    var src_node: u32 = 0;
    var old_src_node: u32 = 0; // root is always 0, so start collecting immediately
    var start_index: u32 = 0; // corresponding start_index to src_node in mtree
    var i: u32 = 0; // index of tree (input)
    var cnt_children: u32 = 0;
    // tmp memory that stores where index to child ID must be stored
    var pos_pos_id = try alloc.alloc(T, id_cnt);
    for (pos_pos_id) |*pos_pos| {
        pos_pos.* = 666666;
    }
    defer alloc.free(pos_pos_id);
    pos_pos_id[0] = 0;
    var id_written = try alloc.alloc(bool, id_cnt);
    defer alloc.free(id_written);
    for (id_written) |*id| {
        id.* = false;
    }

    while (i < tree.len) : (i += 1) {
        src_node = tree[i].from;
        if (src_node == old_src_node) {
            mtree[next_i] = 1000 + tree[i].to; // reserve space for new target
            pos_pos_id[tree[i].to] = next_i;
            // std.debug.print("<<<<<<<<< tree[i].from: {d}, tree[i].to: {d}\n", .{ tree[i].from, tree[i].to });
            // std.debug.print("<<<<<<<<< old_src_node: {d}, src_node: {d}\n", .{ old_src_node, src_node });
            // std.debug.print("<<<<<<<<< start_index: {d}, next_i: {d}\n", .{ start_index, next_i });
            // std.debug.print("<<<<<<<<< pos_pos_id: ", .{});
            // for (pos_pos_id) |pp_id| {
            //     std.debug.print("{d}, ", .{pp_id});
            // }
            // std.debug.print("\n", .{});
            cnt_children += 1; // custom logic?
            next_i += 1;
        } else {
            // fixup id and len for children "pointers" to last id
            // <id len pos_id_child1 pos_id_child2..>
            // with id_child1 id_child2 getting visited later on
            // and offsets table into pos_id_child1 pos_id_child2 for later fixup
            id_written[old_src_node] = true;
            mtree[start_index] = old_src_node; // write IDs
            mtree[start_index + 1] = cnt_children; // write len of pointers to children
            cnt_children = 1;
            start_index = next_i;
            // immediately fixup the link to current new id (not possible for leaf nodes)
            // std.debug.print(">>>>>>>> tree[i].from: {d}, tree[i].to: {d}\n", .{ tree[i].from, tree[i].to });
            // std.debug.print(">>>>>>>> old_src_node: {d}, src_node: {d}\n", .{ old_src_node, src_node });
            // std.debug.print(">>>>>>>> start_index: {d}, next_i: {d}\n", .{ start_index, next_i });
            // std.debug.print(">>>>>>>> pos_pos_id[src_node]: {d}\n", .{pos_pos_id[src_node]});
            mtree[pos_pos_id[src_node]] = start_index;
            next_i += 2;

            mtree[next_i] = 1000 + tree[i].to; // reserve space for new target
            pos_pos_id[tree[i].to] = next_i;
            next_i += 1;
        }
        std.debug.assert(0 <= tree[i].from and tree[i].from + 1 <= id_cnt); // 0..id_cnt-1
        std.debug.assert(0 <= tree[i].from and tree[i].to + 1 <= id_cnt);
        old_src_node = src_node;
    }
    // Write pending last ID with len. This is correct, because there is always
    // a root ID.
    id_written[old_src_node] = true;
    mtree[start_index] = old_src_node; // write IDs
    mtree[start_index + 1] = cnt_children; // write len of pointers to children

    // std.debug.print("mtree: [", .{});
    // for (mtree) |el|
    //     std.debug.print("{d} ", .{el});
    // std.debug.print("]\n", .{});
    // std.debug.print("pos_pos_id: [", .{});
    // for (pos_pos_id) |el|
    //     std.debug.print("{d} ", .{el});
    // std.debug.print("]\n", .{});
    //
    // std.debug.print("id_written: [", .{});
    // for (id_written) |el|
    //     std.debug.print("{d} ", .{el});
    // std.debug.print("]\n", .{});
    // write leaf nodes and fixup pointers (all without children=leafs)
    {
        start_index += cnt_children + 2; // cnt_children + id + len field
        var id: u32 = 0;
        while (id < id_written.len) : (id += 1) {
            if (!id_written[id]) {
                mtree[pos_pos_id[id]] = start_index; // fixup pointer to this id
                mtree[start_index] = id;
                id_written[id] = true;
                start_index += 1;
                mtree[start_index] = 0;
                start_index += 1;
                // std.debug.print("mtree: [", .{});
                // for (mtree) |el|
                //     std.debug.print("{d} ", .{el});
                // std.debug.print("]\n", .{});
                // std.debug.print("pos_pos_id: [", .{});
                // for (pos_pos_id) |el|
                //     std.debug.print("{d} ", .{el});
                // std.debug.print("]\n", .{});
                //
                // std.debug.print("id_written: [", .{});
                // for (id_written) |el|
                //     std.debug.print("{d} ", .{el});
                // std.debug.print("]\n", .{});
            }
        }
    }

    // TODO u32 has 4 bytes: Use 2 for len, 1 for tag,
    // 1 bit for active or not and 7 bit for extra data bucket
    return mtree;
}

test "calcRequiredMemory" {
    // std.debug.print("print\n", .{});
    // for (example_tree) |con| {
    //     std.debug.print("{d}->{d}\n", .{ con.from, con.to });
    // }
    // std.debug.print("end\n", .{});
    const alloc = std.testing.allocator;
    const mtree = try initMTree(u32, alloc, &example_tree, 8);
    defer alloc.free(mtree);

    //const expected_mtree = &[_]u32{ 0, 2, 4, 9, 5, 3, 13, 15, 17, 7, 2, 19, 21, 4, 0, 3, 0, 1, 0, 2, 0, 6, 0 };
    const expected_mtree = &[_]u32{ 0, 2, 4, 9, 5, 3, 19, 17, 13, 7, 2, 15, 21, 1, 0, 2, 0, 3, 0, 4, 0, 6, 0 };
    try std.testing.expectEqualSlices(u32, mtree, expected_mtree);
}
