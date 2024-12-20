const std = @import("std");
const mem = std.mem;

pub const GameOfLife = struct {
    grid: std.ArrayList(u8),
    grid_buffer: std.ArrayList(u8),
    width: u32,
    height: u32,
    allocator: mem.Allocator,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, width: u32, height: u32) !Self {
        const total = width * height;
        var grid = try std.ArrayList(u8).initCapacity(allocator, total);
        errdefer grid.deinit();
        for (0..total) |_| grid.appendAssumeCapacity(0);
        var grid_buffer = try std.ArrayList(u8).initCapacity(allocator, total);
        grid_buffer.appendSliceAssumeCapacity(grid.items);
        return .{
            .grid = grid,
            .grid_buffer = grid_buffer,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn set_grid_start(self: *Self, arr: [][]const u8) void {
        @memset(self.grid.items, 0);
        for (0..arr.len) |row_index| {
            for (arr[row_index], 0..) |col_value, col_index| {
                self.grid.items[row_index * self.width + col_index] = col_value;
            }
        }
    }

    pub fn step_wrap(self: *Self) !void {
        var active = self.grid;
        var inactive = self.grid_buffer;

        for (0..self.height) |row_index| {
            const row_start = row_index * self.width;
            const row_top = blk: {
                if (row_index == 0) {
                    break :blk active.items[active.items.len - self.width..];
                }
                const prev_start = row_start - self.width;
                break :blk active.items[prev_start..row_start];
            };

            const row_current = active.items[row_start..row_start + self.width];

            const row_bottom = blk: {
                if (row_index == self.height - 1) {
                    break :blk active.items[0..self.width];
                }
                const next_start = row_start + self.width;
                break :blk active.items[next_start..next_start + self.width];
            };

            for (0..self.width) |col_index| {
                var sum = sum_row_wrap(col_index, row_top);
                sum += sum_row_wrap(col_index, row_current);
                sum += sum_row_wrap(col_index, row_bottom);
                const col_value = row_current[col_index];
                sum -= col_value;

                const grid_index = row_index * self.width + col_index; 
                if (col_value == 1) {
                    if (sum < 2 or sum > 3) {
                        inactive.items[grid_index] = 0;
                    } else {
                        inactive.items[grid_index] = 1;
                    }
                } else if (col_value == 0) {
                    if (sum == 3) {
                        inactive.items[grid_index] = 1;
                    } else {
                        inactive.items[grid_index] = col_value;
                    }
                } else {
                    unreachable;
                }
            }
        }
        self.grid = inactive;
        self.grid_buffer = active;
    }

    fn sum_row_wrap(index: usize, row: []u8) u32 {
        var buf: [3]u8 = undefined;
        const prev_index = blk: {
            if (index == 0) {
                break :blk row.len - 1;
            }
            break :blk index - 1;
        };
        buf[0] = row[prev_index];

        buf[1] = row[index];

        const next_index = blk: {
            const index_next = index + 1;
            if (index_next >= row.len) {
                break :blk 0;
            }
            break :blk index_next;
        };
        buf[2] = row[next_index];
        // std.debug.print("{any}\n", .{buf});

        var sum: u32 = 0;
        for (buf) |val| {
            sum += val;
        }
        return sum;
    }

    pub fn step(self: *Self) !void {
        var active = self.grid;
        var inactive = self.grid_buffer;

        for (0..self.height) |row_index| {
            const row_start = row_index * self.width;
            const top_row_opt = blk: {
                if (row_index > 0) {
                    const start = row_start - self.width;
                    break :blk active.items[start..start + self.width];
                }
                break :blk null;
            };

            const row = active.items[row_start..row_start + self.width];

            const bottom_row_opt = blk: {
                const bottom_index = row_index + 1; 
                if (bottom_index < row.len) {
                    const start = row_start + self.width;
                    break :blk active.items[start..start + self.width];
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
                        inactive.items[grid_index] = 0;
                    } else {
                        inactive.items[grid_index] = 1;
                    }
                } else if (col_value == 0) {
                    if (sum == 3) {
                        inactive.items[grid_index] = 1;
                    } else {
                        inactive.items[grid_index] = col_value;
                    }
                } else {
                    unreachable;
                }
            }
        }
        self.grid = inactive;
        self.grid_buffer = active;
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

pub const ElementaryCA = struct {
    row: std.ArrayList(u8),
    row_buffer: std.ArrayList(u8),
    ruleset: [8]u8 = .{0} ** 8,
    // rule 222
    // [_]u8{1,1,0,1,1,1,1,0};

    const Self = @This();
    const Options = struct{
        row_length: u32 = 11,
        init_live_cell_indexes: []const u32 = &.{5},
        rule: u8 = 0,
    };

    pub fn init(allocator: mem.Allocator, opts: Options) !Self {
        var row = try std.ArrayList(u8).initCapacity(allocator, opts.row_length);
        errdefer row.deinit();
        for (0..opts.row_length) |i| {
            var val: u8 = 0;
            if (mem.indexOfScalar(u32, opts.init_live_cell_indexes, @intCast(i))) |_| {
                val = 1;
            } 
            row.appendAssumeCapacity(val);
        }
        var row_buffer = try std.ArrayList(u8).initCapacity(allocator, row.items.len);
        row_buffer.appendSliceAssumeCapacity(row.items);
        var self: Self = .{
            .row = row,
            .row_buffer = row_buffer,
        };
        self.set_rule(opts.rule);
        return self;
    }

    fn set_rule(self: *Self, rule_val: u8) void {
        const last_index = self.ruleset.len - 1;
        for (0..self.ruleset.len) |i| {
            self.ruleset[last_index - i] = (rule_val >> @intCast(i)) & 1;
        }
    }

    pub fn next_generation(self: *Self) !void {
        const active = self.row.items;
        const inactive = self.row_buffer;
        for (active, 0..) |value, i| {
            const index_prev = (i + active.len - 1) % active.len;
            const index_next = (i + active.len + 1) % active.len;
            var state: u8 = active[index_prev] << 2;
            state |= value << 1;
            state |= active[index_next];
            // std.debug.print("{b}\n", .{state});
            inactive.items[i] = self.rule(state);
        }

        self.row_buffer = self.row;
        self.row = inactive;
    }

    fn rule(self: *const Self, val: u8) u8 {
        // std.debug.print("val: {d} {} {b}\n", .{val, val == 0b011, val});
        if (val == 0b111) return self.ruleset[0];
        if (val == 0b110) return self.ruleset[1];
        if (val == 0b101) return self.ruleset[2];
        if (val == 0b100) return self.ruleset[3];
        if (val == 0b011) return self.ruleset[4];
        if (val == 0b010) return self.ruleset[5];
        if (val == 0b001) return self.ruleset[6];
        if (val == 0b000) return self.ruleset[7];
        @panic("messed up rule getting rule");
    }

    pub fn print(self: *const Self) !void {
        var writer = std.io.getStdOut().writer();
        for (self.row.items) |value| {
            try writer.print("{d} ", .{value});
        }
        try writer.writeAll("\n");
    }

    pub fn deinit(self: *Self) void {
        self.row.deinit();
        self.row_buffer.deinit();
    }
};
