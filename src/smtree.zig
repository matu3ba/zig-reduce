//! Simplified Access time optimized MultiTree (MTree)
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
//         1               2
//      3  4  5          6   7
const example_tree = [_]Con{
    .{ .from = 0, .to = 1 },
    .{ .from = 0, .to = 2 },
    .{ .from = 1, .to = 3 },
    .{ .from = 1, .to = 4 },
    .{ .from = 1, .to = 5 },
    .{ .from = 2, .to = 6 },
    .{ .from = 2, .to = 7 },
};
//              0 1 2 3 4 5 6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
// BFS result: [0 2 4 9 1 3 13 15 17 2 2  19 21 3  0  4  0  5  0  6  0  7  0]
//  addresses       1 2     3  4  5       6  7

/// Returns MultiTree.
/// Requires cnt_parent_nodes*T*2 + cnt_children_nodes*T memory.
/// and during construction additonally cnt_children_nodes*T memory
/// Root id is 0 and starts at index 0.
/// assume: child_IDs are visited in monotonically increased order
///         with step length 1 and starting with 1
/// assume: child_ID > parent_ID
/// assume: each child has exactly 1 incoming edge.
/// assume: parent has at most max(T)-1 children.
/// assume: T can hold all slice addresses and ids
fn initMTree(comptime T: type, alloc: mem.Allocator, tree: []const Con) error{OutOfMemory}![]u32 {
    //const type_i = @typeInfo(T);
    //comptime std.debug.assert(type_i == .Int and type_i.?.signedness == .unsigned);
    //const sizeT = @sizeOf(T);

    var children_per_parent = try std.ArrayList(u8).initCapacity(alloc, 1);
    defer children_per_parent.deinit();
    try children_per_parent.append(0); // root element
    for (tree) |con| {
        // there is always a new child id
        std.debug.assert(children_per_parent.items.len == con.to);
        try children_per_parent.append(0);
        children_per_parent.items[con.from] += 1;
    }
    // cnt_nodes*sizeof(T)*cnt_children for children addresses
    var mem_size: T = 0;
    for (children_per_parent.items) |cnt_children|
        mem_size += cnt_children;
    // cnt_nodes*sizeof(T)*2 for node identifier and number of children
    var mtree_memsize: T = @intCast(T, children_per_parent.items.len) * 2 + mem_size;
    var children_addr_memsize: T = mem_size;

    // tmp memory that stores where index to child must be stored
    var node_indices = try alloc.alloc(T, children_addr_memsize + 1); // +1 for root
    defer alloc.free(node_indices);
    var mtree = try alloc.alloc(T, mtree_memsize);

    // each entry is form form <id len child_id1 child_id2 ..>
    var next_i: T = 0; // next free index in mtree
    var next_id: T = 0; // next id to write
    var next_ch_id: T = 1; // next child_id to write

    // initialization for root node
    node_indices[0] = 0;

    while (next_id < children_per_parent.items.len) : (next_id += 1) {
        // fixup skipped index fields
        // invariant child_ID > parent_ID makes sure this is always valid
        mtree[node_indices[next_id]] = next_i;
        mtree[next_i] = next_id;
        next_i += 1;

        var cnt_children = mtree[next_i .. next_i + 1];
        cnt_children[0] = children_per_parent.items[next_id];
        next_i += 1;

        if (cnt_children[0] > 0) {
            var child_addrs = mtree[next_i .. next_i + cnt_children[0]];

            var children_i: T = 0;
            while (children_i < child_addrs.len) : (children_i += 1) {
                //child_addrs[children_i] = next_ch_id;
                node_indices[next_ch_id] = next_i + children_i; // index into mtree
                next_ch_id += 1;
            }
            // skip written index fields
            next_i += cnt_children[0];
        }

        // DEBUG
        // std.debug.print("mtree: [", .{});
        // for (mtree) |el|
        //     std.debug.print("{d} ", .{el});
        // std.debug.print("]\n", .{});
        //
        // std.debug.print("node_indices: [", .{});
        // for (node_indices) |el|
        //     std.debug.print("{d} ", .{el});
        // std.debug.print("]\n", .{});
    }

    return mtree;
}

test "calcRequiredMemory" {
    const alloc = std.testing.allocator;
    const mtree = try initMTree(u32, alloc, &example_tree);
    defer alloc.free(mtree);

    const expected_mtree = &[_]u32{ 0, 2, 4, 9, 1, 3, 13, 15, 17, 2, 2, 19, 21, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0 };
    try std.testing.expectEqualSlices(u32, mtree, expected_mtree);
}
