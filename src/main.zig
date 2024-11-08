//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const mem = std.mem;
const GameOfLife = @import("./lib.zig").GameOfLife;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gol = try GameOfLife.init(gpa.allocator(), 7, 7);

    var glider = [_][]const u8{
        &.{0, 1, 0},
        &.{0, 0, 1},
        &.{1, 1, 1},
    };

    gol.set_grid_start(&glider);

    for (0..20) |_| {
        try gol.print();
        try gol.step();
    }
    try gol.print();

    defer gol.deinit();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const global = struct {
        fn testOne(input: []const u8) anyerror!void {
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    const opts: std.testing.FuzzInputOptions = .{};
    try std.testing.fuzz(global.testOne, opts);
}
