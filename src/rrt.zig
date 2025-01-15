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

    fn get_cost_grid(self: *const RRT, x: i32, y: i32) ?u8 {
        if (self.grid.check_node_wall(x, y)) {
            return null;
        }
        const u_x: usize = @intCast(x);
        const u_y: usize = @intCast(y);

        return @intFromEnum(self.grid.get(u_x / self.grid.cell_width, u_y / self.grid.cell_width));
    }

    fn transition_test(cost_near: u8, cost_new: u8, distance: i32) bool {
        if (cost_new > 20) {
            return false;
        }
        if (cost_near > cost_new) {
            return true;
        }
        const max_fail = 100;
        var fail: u8 = 0;
        const K: f32 = 1;
        var T: f32 = 1;
        const delta_cost = cost_new - cost_near;
        const f_delta_cost: f32 = @floatFromInt(delta_cost);
        const f_distance: f32 = @floatFromInt(distance);
        const p = std.math.exp((-f_delta_cost / f_distance) / (K * T));
        var rng = std.rand.Xoshiro256.init(0);
        const rand = rng.random().floatNorm(f32);
        if (rand < p) {
            T = T / 1.1;
            fail = 0;
            return true;
        } else {
            if (fail > max_fail) {
                T = T * 1.1;
                fail = 0;
            } else {
                fail += 1;
            }
        }

        return false;
    }

    pub fn t_rrt(self: *RRT) !void {
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
            var cost_new: u8 = undefined;
            var cost_near: u8 = undefined;
            if (self.get_cost_grid(new_node.x, new_node.y)) |cost_n| {
                cost_new = cost_n;
            } else {
                continue;
            }
            new_node.set_parent(parent_id);
            if (self.get_cost_grid(self.graph.get_node(parent_id).x, self.graph.get_node(parent_id).y)) |cost_na| {
                cost_near = cost_na;
            } else {
                continue;
            }
            if (!transition_test(cost_near, cost_new, min_distance)) {
                continue;
            }
            try self.graph.add_node(new_node);
            self.max_iterations -= 1;
            if (new_node.distance(&self.end) < (self.step_size * self.step_size) * 2) {
                self.end.set_parent(new_node.id);
                return;
            }
        }
    }

    pub fn rrt(self: *RRT) !void {
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
