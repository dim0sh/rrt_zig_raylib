const ray = @cImport(@cInclude("raylib.h"));
const std = @import("std");

const Cell = enum(u8) {
    Empty,
    Wall,
    Start,
    End,
    _,
};

pub const Grid = struct {
    width: usize,
    height: usize,
    cell_width: usize,
    cells: std.ArrayList(Cell),

    pub fn init(width: usize, height: usize, cell_width: usize, alloc: std.mem.Allocator) !Grid {
        const grid_width = width / cell_width;
        const grid_height = height / cell_width;
        var cells = std.ArrayList(Cell).init(alloc);
        try cells.ensureTotalCapacity(grid_height * grid_width);
        cells.appendNTimesAssumeCapacity(Cell.Empty, grid_height * grid_width);
        cells.items[0] = Cell.Start;
        cells.items[(grid_height * grid_width) - 1] = Cell.End;
        return Grid{ .width = grid_width, .height = grid_height, .cell_width = cell_width, .cells = cells };
    }

    pub fn deinit(self: *Grid) void {
        self.cells.deinit();
    }

    pub fn get(self: *const Grid, x: usize, y: usize) Cell {
        return self.cells.items[x + y * self.width];
    }

    pub fn set(self: *Grid, x: usize, y: usize, cell: Cell) void {
        self.cells.items[x + y * self.width] = cell;
    }

    pub fn generate_cost(self: *Grid) void {
        var rng = std.rand.Xoshiro256.init(0);
        for (self.cells.items, 0..) |cell, idx| {
            if (cell == Cell.Empty) {
                const rand = rng.random().intRangeAtMost(u8, 0, 100);
                switch (rand) {
                    0...3 => {
                        self.cells.items[idx] = Cell.Wall;
                    },
                    4...20 => {
                        self.cells.items[idx] = @enumFromInt(rand);
                    },
                    else => {},
                }
            }
        }
    }

    pub fn draw(self: *const Grid) void {
        const cell_width: c_int = @intCast(self.cell_width);
        for (self.cells.items, 0..) |cell, idx| {
            const x: usize = idx % self.width;
            const y: usize = idx / self.width;
            const c_x: c_int = @intCast(x);
            const c_y: c_int = @intCast(y);
            switch (cell) {
                Cell.Empty => {},
                Cell.Wall => {
                    const color = ray.Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
                    ray.DrawRectangle(c_x * cell_width, c_y * cell_width, cell_width, cell_width, color);
                },
                Cell.Start => {
                    const color = ray.Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
                    ray.DrawRectangle(c_x * cell_width, c_y * cell_width, cell_width, cell_width, color);
                },
                Cell.End => {
                    const color = ray.Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
                    ray.DrawRectangle(c_x * cell_width, c_y * cell_width, cell_width, cell_width, color);
                },
                _ => {
                    const enum_val = @intFromEnum(cell) * 10;
                    const color = ray.Color{ .r = enum_val, .g = enum_val, .b = enum_val, .a = 255 };
                    ray.DrawRectangle(c_x * cell_width, c_y * cell_width, cell_width, cell_width, color);
                },
            }
        }
    }
};
