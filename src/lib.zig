const std = @import("std");
const mem = std.mem;

pub const GameOfLife = struct {
    grid: std.ArrayList(u8),
    width: u32,
    height: u32,
    allocator: mem.Allocator,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, width: u32, height: u32) !Self {
        const total = width * height;
        var grid = try std.ArrayList(u8).initCapacity(allocator, total);
        for (0..total) |_| grid.appendAssumeCapacity(0);
        return .{
            .grid = grid,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn set_grid_start(self: *Self, arr: [][]const u8) void {
        for (0..arr.len) |row_index| {
            for (arr[row_index], 0..) |col_value, col_index| {
                self.grid.items[row_index * self.width + col_index] = col_value;
            }
        }
    }

    pub fn step(self: *Self) !void {
        var buf_copy = try std.ArrayList(u8).initCapacity(self.allocator, self.width * self.height);
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

            // std.debug.print("row {}\n", .{row_index});
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
                sum -= col_value;

                // std.debug.print("sum: {} | col: {}\n", .{sum, col_value});
                const grid_index = row_index * self.width + col_index; 
                if (col_value == 1) {
                    if (sum < 2 or sum > 3) {
                        self.grid.items[grid_index] = 0;
                    } else {
                        self.grid.items[grid_index] = 1;
                    }
                } else if (col_value == 0) {
                    if (sum == 3) {
                        self.grid.items[grid_index] = 1;
                    } else {
                        self.grid.items[grid_index] = col_value;
                    }
                } else {
                    unreachable;
                }
            }
        }
    }

    fn sum_row_around_index(index: usize, row: []u8) u32 {
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
            sum += val;
        }
        return sum;
    }

    pub fn print(self: *const Self) !void {
        if (comptime @import("builtin").os.tag == .wasi) {
            try self.print_wasm();
        } else {
            try self.print_os();
        }
    }

    pub fn print_wasm(self: *const Self) !void {
        _ = self;
    }
    
    pub fn print_os(self: *const Self) !void {
        const writer = std.io.getStdOut().writer();
        for (self.grid.items, 0..) |val, i| {
            try writer.print("{} ", .{val});
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
