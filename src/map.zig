const grid_lib = @import("grid.zig");
const std = @import("std");

pub fn create_map(grid: *grid_lib.Grid) void {
    // start and end
    set_start(grid, 0, 0);
    set_end(grid, grid.width - 1, grid.height - 1);
    //walls
    create_mult_wall(grid, 10, 0, 1, grid.height - 10);
    create_mult_wall(grid, 10, grid.height - 5, 1, 5);
    create_mult_wall(grid, 15, 10, 1, 8);
    create_mult_wall(grid, 25, 10, 8, 8);
    //cost
    create_mult_cost(grid, 9, 0, 1, grid.height - 10, 255);
    create_mult_cost(grid, 5, 5, 4, 4, 100);

    create_mult_cost(grid, 8, grid.height - 10, 4, 1, 180);
    create_mult_cost(grid, 8, grid.height - 9, 4, 1, 150);
    create_mult_cost(grid, 8, grid.height - 8, 4, 1, 100);
    create_mult_cost(grid, 8, grid.height - 7, 4, 1, 50);

    create_mult_cost(grid, 25, 18, 2, 4, 50);
    create_mult_cost(grid, 27, 18, 2, 4, 100);
    create_mult_cost(grid, 29, 18, 2, 4, 150);
    create_mult_cost(grid, 31, 18, 2, 4, 200);
    create_mult_cost(grid, 33, 15, 2, 6, 255);
    create_mult_cost(grid, 33, 18, 2, 2, 200);
    create_mult_cost(grid, 35, 15, 2, 6, 200);

    create_mult_cost(grid, 25, 2, 8, 8, 255);
}

fn create_mult_wall(grid: *grid_lib.Grid, x: usize, y: usize, width: usize, height: usize) void {
    for (0..width) |i| {
        for (0..height) |j| {
            set_wall(grid, x + i, y + j);
        }
    }
}

fn create_mult_cost(grid: *grid_lib.Grid, x: usize, y: usize, width: usize, height: usize, cost: u8) void {
    for (0..width) |i| {
        for (0..height) |j| {
            set_cost(grid, x + i, y + j, cost);
        }
    }
}

fn set_wall(grid: *grid_lib.Grid, x: usize, y: usize) void {
    grid.set(x, y, grid_lib.Cell.Wall);
}

fn set_start(grid: *grid_lib.Grid, x: usize, y: usize) void {
    grid.set(x, y, grid_lib.Cell.Start);
}

fn set_end(grid: *grid_lib.Grid, x: usize, y: usize) void {
    grid.set(x, y, grid_lib.Cell.End);
}

fn set_cost(grid: *grid_lib.Grid, x: usize, y: usize, cost: u8) void {
    grid.set(x, y, @enumFromInt(cost));
}
