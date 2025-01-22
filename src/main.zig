const ray = @cImport(@cInclude("raylib.h"));
const std = @import("std");
const grid_lib = @import("grid.zig");
const rrt_lib = @import("rrt.zig");
const map_lib = @import("map.zig");

const WINDOW_TITLE = "falling sand";
pub const WINDOW_WIDTH = 1600;
pub const WINDOW_HEIGHT = 900;
const margin = 10;
const TARGET_FPS = 1000;
const ITERATIONS = 10000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var grid = try grid_lib.Grid.init(WINDOW_WIDTH, WINDOW_HEIGHT, 40, arena.allocator());
    defer grid.deinit();

    map_lib.create_map(&grid);

    // grid.generate_cost();

    var rrt = try rrt_lib.RRT.init(0, 0, WINDOW_WIDTH - 10, WINDOW_HEIGHT - 10, 30, ITERATIONS, arena.allocator(), WINDOW_WIDTH, WINDOW_HEIGHT, &grid);
    defer rrt.deinit();

    try rrt.t_rrt_star();

    ray.InitWindow(WINDOW_WIDTH + margin, WINDOW_HEIGHT + margin, WINDOW_TITLE);
    ray.SetTargetFPS(TARGET_FPS);
    defer ray.CloseWindow();

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.BLACK);
        grid.draw();
        rrt.draw();
        rrt.draw_solution();

        // ray.DrawFPS(WINDOW_HEIGHT - 100, 0);
    }
}
