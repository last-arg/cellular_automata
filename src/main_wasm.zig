const std = @import("std");
const mem = std.mem;
const zjb = @import("zjb");
const alloc = std.heap.wasm_allocator;
const GameOfLife = @import("./lib.zig").GameOfLife;

fn log(v: anytype) void {
    zjb.global("console").call("log", .{v}, void);
}

fn logStr(str: []const u8) void {
    const handle = zjb.string(str);
    defer handle.release();
    zjb.global("console").call("log", .{handle}, void);
}

const Canvas = struct {
    width: i32 = 100,
    height: i32 = 100,
    gol: GameOfLife,
    context: zjb.Handle,

    const cell_size = 30; 
    const cell_size_i32: i32 = @intCast(cell_size); 

    pub fn init(allocator: mem.Allocator, width: u32, height: u32) @This() {
        var gol = GameOfLife.init(allocator, width, height) catch |e| zjb.throwError(e);
        errdefer gol.deinit();

        const c = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
        defer c.release();

        const canvas_width: i32 = @intCast(cell_size * gol.width);
        const canvas_height: i32 = @intCast(cell_size * gol.height);
        c.set("width", canvas_width);
        c.set("height", canvas_height);

        var context = c.call("getContext", .{zjb.constString("2d")}, zjb.Handle);
        errdefer context.release();
                
        var r: @This() = .{
            .width = canvas_width,
            .height = canvas_height,
            .gol = gol,
            .context = context,
        };
        r.reset();
        return r;
    }

    pub fn reset(self: *@This()) void {
        var glider = [_][]const u8{
            &.{0, 1, 0},
            &.{0, 0, 1},
            &.{1, 1, 1},
        };

        self.gol.set_grid_start(&glider);
    }

    pub fn deinit(self: *@This()) void {
        self.gol.deinit();
        self.context.release();
    }

    pub fn render(self: *@This()) void {
        // for (0..gol.height) |row_index| {
        //     const row_start = row_index * gol.width;
        //     const row_end = row_start + gol.width;
        //     const obj = zjb.u8ArrayView(gol.grid.items[row_start..row_end]);
        //     defer obj.release();
        //     log(obj);
        // }

        const canvas_width = self.width;
        const canvas_height = self.height;
        const live_color = zjb.constString("#16191d"); 
        const dead_color = zjb.constString("#f8f9fa"); 

        const canvas_start: i32 = 0;
        const canvas_end: i32 = 0;
        self.context.call("clearRect", .{ canvas_start, canvas_end, canvas_width, canvas_height }, void);
        self.context.set("fillStyle", dead_color);
        self.context.call("fillRect", .{ canvas_start, canvas_end, canvas_width, canvas_height }, void);

        self.context.set("fillStyle", live_color);

        for (0..self.gol.height) |row_index| {
            const row_px: i32 = @intCast(row_index * cell_size);
            for (0..self.gol.width) |col_index| {
                const index = row_index * self.gol.width + col_index;
                const col_val = self.gol.grid.items[index];
                if (col_val == 1) {
                    const col_px: i32 = @intCast(col_index * cell_size);
                    self.context.call("fillRect", .{ col_px, row_px, cell_size_i32, cell_size_i32 }, void);
                }
            }
        }
    }
};

var canvas: Canvas = undefined;

pub const panic = zjb.panic;
export fn main() void {
    canvas = Canvas.init(alloc, 7, 7);
    canvas.render();

    const button_reset = zjb.global("document").call("getElementById", .{zjb.constString("canvas-reset")}, zjb.Handle);
    defer button_reset.release();
    button_reset.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("resetCallback", resetCallback) }, void);

    {
        const button_next_step = zjb.global("document").call("getElementById", .{zjb.constString("canvas-next-step")}, zjb.Handle);
        defer button_next_step.release();
        button_next_step.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("clickCallback", clickCallback) }, void);

        const button_play_stop = zjb.global("document").call("getElementById", .{zjb.constString("canvas-play-stop")}, zjb.Handle);
        defer button_play_stop.release();
        button_play_stop.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("play_stop_cb", finite_play_stop_cb) }, void);
    }

    {
        const button_next_step = zjb.global("document").call("getElementById", .{zjb.constString("infinite-next-step")}, zjb.Handle);
        defer button_next_step.release();
        button_next_step.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("infinite-next-step-cb", infinite_next_step_cb) }, void);

        const button_play_stop = zjb.global("document").call("getElementById", .{zjb.constString("infinite-play-stop")}, zjb.Handle);
        defer button_play_stop.release();
        button_play_stop.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("infinite_play_stop_cb", infinite_play_stop_cb) }, void);
    }
}

var prev_time: f64 = 0.0;
var time_step: f64 = 0.0;
var is_playing = false;
const frame_ms: f64 = 1000.0 / 2.0; 
fn finite_play_stop_cb(event: zjb.Handle) callconv(.C) void {
    defer event.release();

    if (is_playing) {
        is_playing = false;
        prev_time = 0.0;
    } else {
        is_playing = true;
        prev_time = zjb.global("performance").call("now", .{}, f64);
        zjb.global("window").call("requestAnimationFrame", .{ zjb.fnHandle("frame_cb", finite_frame_cb) }, void);
    }
}

fn infinite_play_stop_cb(event: zjb.Handle) callconv(.C) void {
    defer event.release();

    if (is_playing) {
        is_playing = false;
        prev_time = 0.0;
    } else {
        is_playing = true;
        prev_time = zjb.global("performance").call("now", .{}, f64);
        zjb.global("window").call("requestAnimationFrame", .{ zjb.fnHandle("infinite_frame_cb", infinite_frame_cb) }, void);
    }
}

fn finite_frame_cb(time_ms: f64) callconv(.C) void {
    if (!is_playing) {
        return;
    }
    const lag = time_ms - prev_time;
    prev_time = time_ms;
    time_step += lag;
    while (time_step >= frame_ms) {
        canvas.gol.step() catch |e| {
            logStr("GameOfLife.step failed");
            zjb.throwError(e);
        };
        time_step -= frame_ms;
    }

    canvas.render();

    zjb.global("window").call("requestAnimationFrame", .{ zjb.fnHandle("frame_cb", finite_frame_cb) }, void);
}

fn infinite_frame_cb(time_ms: f64) callconv(.C) void {
    if (!is_playing) {
        return;
    }
    const lag = time_ms - prev_time;
    prev_time = time_ms;
    time_step += lag;
    while (time_step >= frame_ms) {
        canvas.gol.step_wrap() catch |e| {
            logStr("GameOfLife.step failed");
            zjb.throwError(e);
        };
        time_step -= frame_ms;
    }

    canvas.render();

    zjb.global("window").call("requestAnimationFrame", .{ zjb.fnHandle("frame_cb", finite_frame_cb) }, void);
}

fn infinite_next_step_cb(event: zjb.Handle) callconv(.C) void {
    defer event.release();

    canvas.gol.step_wrap() catch |e| {
        logStr("GameOfLife.step failed");
        zjb.throwError(e);
    };
    canvas.render();
}

fn infinite_next(event: zjb.Handle) callconv(.C) void {
    defer event.release();

    canvas.gol.step() catch |e| {
        logStr("GameOfLife.step failed");
        zjb.throwError(e);
    };
    canvas.render();
}

fn resetCallback(event: zjb.Handle) callconv(.C) void {
    defer event.release();
    // log("reset");

    is_playing = false;
    canvas.reset();
    canvas.render();
}

// var value: i32 = 0;
// fn incrementAndGet(increment: i32) callconv(.C) i32 {
//     value += increment;
//     return value;
// }

// var test_var: f32 = 1337.7331;
// fn checkTestVar() callconv(.C) f32 {
//     return test_var;
// }

// fn setTestVar() callconv(.C) f32 {
//     test_var = 42.24;
//     return test_var;
// }

// comptime {
//     zjb.exportFn("incrementAndGet", incrementAndGet);

//     zjb.exportGlobal("test_var", &test_var);
//     zjb.exportFn("checkTestVar", checkTestVar);
//     zjb.exportFn("setTestVar", setTestVar);
// }
