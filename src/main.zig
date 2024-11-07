//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const mem = std.mem;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.log.info("Starting Conway's game of life", .{});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.

    try game_of_life();

}

const grid_size = 4; 
const Grid = [grid_size][grid_size]u8;
fn game_of_life() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("Starting conway's game of life\n", .{});

    var grid_1 = mem.zeroes(Grid);
    var grid_2 = mem.zeroes(Grid);
    var active = &grid_1;
    var inactive = &grid_2;

    // Glider
    grid_1[0][1] = 1;
    grid_1[1][2] = 1;
    grid_1[2][0] = 1;
    grid_1[2][1] = 1;
    grid_1[2][2] = 1;

    try print_game_of_life(stdout, active);

    const step_count = 10;
    for (0..step_count) |_| {
        active, inactive = try step_game_of_life(active, inactive);
    }

    try stdout.writeAll("\n");
    try print_game_of_life(stdout, active);

    try bw.flush(); // Don't forget to flush!
}

fn row_sum(row: []const u8) u8 {
    var sum: u8 = 0;
    for (row) |val| {
        sum += val;
    }
    return sum;
}

fn step_game_of_life(active: *Grid, out: *Grid) !struct{*Grid, *Grid} {
    for (active, 0..) |row, i| {
        for (row, 0..) |col, j| {
            var sum: u8 = 0;

            var row_start = j;
            if (j > 0) {
                row_start -= 1;
            }
            var row_end: usize = j + 1;
            if (j < row.len - 1) {
                row_end += 1;
            }

            if (0 < i) {
                const top = active[i-1][row_start..row_end];
                sum += row_sum(top);
            }

            const middle = row[row_start..row_end];
            sum += row_sum(middle);

            if (i < grid_size - 1) {
                const bottom = active[i+1][row_start..row_end];
                sum += row_sum(bottom);
            }
            if (sum > 1) {
                sum -= col;
            }

            if (col == 1) {
                if (sum < 2 or sum > 3) {
                    out[i][j] = 0;
                } else {
                    out[i][j] = 1;
                }
            } else if (col == 0 and sum == 3) {
                out[i][j] = 1;
            } else {
                out[i][j] = col;
            }
        }
    }
    return .{out, active}; 
}

fn print_game_of_life(stdout: anytype, grid: *const Grid) !void {
    for (grid) |row| {
        for (row) |col| {
            try stdout.print("{} ", .{col});
        }
        try stdout.print("\n", .{});
    }
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
