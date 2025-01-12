const std = @import("std");
const graph_lib = @import("graph.zig");
const ray = @cImport(@cInclude("raylib.h"));
const Grid = @import("grid.zig").Grid;

pub const RRT = struct {
    graph: graph_lib.Graph,
    start: graph_lib.Node,
    end: graph_lib.Node,
    step_size: usize,
    max_iterations: usize,
    width: i32,
    height: i32,
    grid: *const Grid,

    pub fn init(start_x: i32, start_y: i32, end_x: i32, end_y: i32, step_size: usize, max_iterations: usize, allocator: std.mem.Allocator, width: i32, height: i32, grid: *const Grid) !RRT {
        var graph = graph_lib.Graph.init(allocator);
        const start = graph_lib.Node.new(0, start_x, start_y, null);
        const end = graph_lib.Node.new(1, end_x, end_y, null);
        try graph.add_node(start);
        return RRT{
            .graph = graph,
            .start = start,
            .end = end,
            .step_size = step_size,
            .max_iterations = max_iterations,
            .width = width,
            .height = height,
            .grid = grid,
        };
    }

    pub fn deinit(self: *RRT) void {
        self.graph.deinit();
    }

    pub fn draw(self: *RRT) void {
        const color = ray.Color{ .r = 0, .g = 150, .b = 150, .a = 125 };
        self.graph.draw(5, color);
    }

    fn random_node(self: *RRT, rng: *std.rand.Xoshiro256) graph_lib.Node {
        const x = rng.random().intRangeAtMost(i32, 0, self.width);
        const y = rng.random().intRangeAtMost(i32, 0, self.height);
        const id = self.graph.nodes.items.len;
        return graph_lib.Node.new(id, x, y, null);
    }

    pub fn draw_solution(self: *RRT) void {
        var node = &self.end;
        const color = ray.Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
        while (node.parent != null) {
            const parent = self.graph.get_parent(node);
            node.draw_to_parent(parent, color);
            node = parent;
        }
    }

    pub fn generate_nodes(self: *RRT) !void {
        var rng = std.rand.Xoshiro256.init(0);
        while (self.max_iterations > 0) {
            var new_node = self.random_node(&rng);
            if (self.grid.check_node_wall(new_node.x, new_node.y)) {
                continue;
            }
            var parent_id: usize = 0;
            var min_distance: i32 = 10000000;
            for (self.graph.nodes.items) |node| {
                const distance = node.distance(&new_node);
                if (distance < min_distance) {
                    min_distance = distance;
                    parent_id = node.id;
                }
            }
            if (min_distance > (self.step_size * self.step_size) * 2) {
                new_node = new_node.generate_closer_node(self.graph.get_node(parent_id), self.step_size);
            }
            if (self.grid.check_node_wall(new_node.x, new_node.y)) {
                continue;
            }
            self.max_iterations -= 1;
            new_node.set_parent(parent_id);
            try self.graph.add_node(new_node);
            if (new_node.distance(&self.end) < (self.step_size * self.step_size) * 2) {
                self.end.set_parent(new_node.id);
                return;
            }
        }
    }
};
