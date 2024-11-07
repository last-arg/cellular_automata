//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const mem = std.mem;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gol = try GameOfLife.init(gpa.allocator(), 7, 7);

    var glider = [_][]const bool{
        &.{false, true, false},
        &.{false, false, true},
        &.{true, true, true},
    };

    gol.set_grid_start(&glider);

    try gol.print();
    try gol.step();
    defer gol.deinit();
}

const GameOfLife = struct {
    grid: std.ArrayList(bool),
    width: u32,
    height: u32,
    allocator: mem.Allocator,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, width: u32, height: u32) !Self {
        const total = width * height;
        var grid = try std.ArrayList(bool).initCapacity(allocator, total);
        for (0..total) |_| grid.appendAssumeCapacity(false);
        return .{
            .grid = grid,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn set_grid_start(self: *Self, arr: [][]const bool) void {
        for (0..arr.len) |row_index| {
            for (arr[row_index], 0..) |col_value, col_index| {
                self.grid.items[row_index * self.width + col_index] = col_value;
            }
        }
    }

    pub fn step(self: *Self) !void {
        var buf_copy = try std.ArrayList(bool).initCapacity(self.allocator, self.width * self.height);
        defer buf_copy.deinit();
        buf_copy.appendSliceAssumeCapacity(self.grid.items);

        for (0..self.height) |row_index| {
            const row_start = row_index * self.width;
            const top_row_opt = blk: {
                if (row_index > 0) {
                    const start = row_start - self.width;
                    break :blk buf_copy.items[start..start + self.width];
                }
                break :blk null;
            };

            const row = buf_copy.items[row_start..row_start + self.width];

            const bottom_row_opt = blk: {
                const bottom_index = row_index + 1; 
                if (bottom_index < row.len) {
                    const start = row_start + self.width;
                    break :blk buf_copy.items[start..start + self.width];
                }
                break :blk null;
            };


            for (0..self.width) |col_index| {
                var sum: u32 = 0;
                if (top_row_opt) |top_row| {
                    sum += sum_row_around_index(col_index, top_row);
                }

                sum += sum_row_around_index(col_index, row);

                if (bottom_row_opt) |bottom_row| {
                    sum += sum_row_around_index(col_index, bottom_row);
                }

                const col_value = row[col_index];
                sum -= @intFromBool(col_value);

                // std.debug.print("sum: {} | col: {}\n", .{sum, col_value});
                const grid_index = row_index * self.width + col_index; 
                if (col_value) {
                    if (sum < 2 or sum > 3) {
                        self.grid.items[grid_index] = false;
                    } else {
                        self.grid.items[grid_index] = true;
                    }
                } else if (!col_value) {
                    if (sum == 3) {
                        self.grid.items[grid_index] = true;
                    } else {
                        self.grid.items[grid_index] = col_value;
                    }
                }
            }
        }
    }

    fn sum_row_around_index(index: usize, row: []bool) u32 {
        const start = blk: {
            if (index == 0) {
                break :blk index;
            }
            break :blk index - 1;
        };
        const end = blk: {
            const index_next = index + 2;
            if (index_next >= row.len) {
                break :blk row.len;
            }
            break :blk index_next;
        };

        var sum: u32 = 0;
        // std.debug.print("sum: {any}\n", .{row[start..end]});
        for (row[start..end]) |val| {
            sum += @intFromBool(val);
        }
        return sum;
    }

    pub fn print(self: *const Self) !void {
        const writer = std.io.getStdOut().writer();
        for (self.grid.items, 0..) |val, i| {
            try writer.print("{} ", .{@intFromBool(val)});
            if (@mod(i + 1, self.width) == 0) {
                try writer.writeAll("\n");
            }
        }
        try writer.writeAll("\n");
    }

    pub fn deinit(self: *const Self) void {
        self.grid.deinit();
    }
};

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
