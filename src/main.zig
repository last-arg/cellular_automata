//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const mem = std.mem;
const lib = @import("./lib.zig");
const GameOfLife = lib.GameOfLife;
const ElementaryCA = lib.ElementaryCA;

pub fn main() !void {
    try elementay_cellular_automata();
}

fn elementay_cellular_automata() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var ca = try ElementaryCA.init(gpa.allocator(), .{
        // .row_length = 19
        .rule = 222
    });
    defer ca.deinit();

    for (0..9) |_| {
        try ca.print();
        try ca.next_generation();
    }
    try ca.print();
}

pub fn game_of_life() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gol = try GameOfLife.init(gpa.allocator(), 7, 7);

    var glider = [_][]const u8{
        &.{0, 1, 0},
        &.{0, 0, 1},
        &.{1, 1, 1},
    };

    gol.set_grid_start(&glider);

    for (0..29) |_| {
        try gol.print();
        try gol.step_wrap();
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
