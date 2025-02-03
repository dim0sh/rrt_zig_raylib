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
        const start = graph_lib.Node.new(0, start_x, start_y, null, 0);
        const end = graph_lib.Node.new(1, end_x, end_y, null, 0);
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
        return graph_lib.Node.new(id, x, y, null, 0);
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
    // transition test for transition based t-rrt algorithm
    fn transition_test(cost_near: usize, cost_new: usize, distance: i32) bool {
        const alpha: f32 = 1.2;
        const max_cost: usize = 120000;
        const K: f32 = 5000;
        var T: f32 = 1;
        if (cost_new > max_cost) {
            return false;
        }
        if (cost_near > cost_new) {
            return true;
        }
        const max_fail = 1000;
        var fail: u8 = 0;
        const delta_cost = cost_new - cost_near;
        const f_delta_cost: f32 = @floatFromInt(delta_cost);
        const f_distance: f32 = @floatFromInt(distance);
        const p = std.math.exp((-f_delta_cost / f_distance) / (K * T));
        var rng = std.rand.Xoshiro256.init(0);
        const rand = rng.random().floatNorm(f32);
        if (rand < p) {
            T = T / alpha;
            fail = 0;
            return true;
        } else {
            if (fail > max_fail) {
                T = T * alpha;
                fail = 0;
            } else {
                fail += 1;
            }
        }

        return false;
    }
    // transition based rrt (cost efficient path)
    pub fn t_rrt_star(self: *RRT) !void {
        var rng = std.rand.Xoshiro256.init(0);
        while (self.max_iterations > 0) {
            // generate / sample new node
            var new_node = self.random_node(&rng);
            // validate sampled node
            if (self.grid.check_node_wall(new_node.x, new_node.y)) {
                continue;
            }
            // find closest node
            var parent_id: usize = 0;
            var min_distance: i32 = 1000000;
            for (self.graph.nodes.items) |node| {
                const distance = node.distance(&new_node);
                if (distance < min_distance) {
                    min_distance = distance;
                    parent_id = node.id;
                }
            }
            new_node.set_parent(parent_id);
            const parent = self.graph.get_node(parent_id);

            // generate closer node if too far
            if (min_distance > (self.step_size * self.step_size) * 2) {
                new_node = new_node.generate_closer_node(self.graph.get_node(parent_id), self.step_size);
            }
            // node validation
            if (self.grid.check_node_wall(new_node.x, new_node.y)) {
                continue;
            }

            const distance_cost: usize = @intCast(new_node.distance(parent));
            // set new node cost
            var cost_new: usize = 0;
            const cost_near: usize = parent.cost;
            if (self.get_cost_grid(new_node.x, new_node.y)) |cost_n| {
                cost_new = cost_n;
            } else {
                continue;
            }
            new_node.set_cost(parent.cost + @max(1, cost_new) * distance_cost);
            // transition test for new node
            if (!transition_test(cost_near, parent.cost + cost_new * distance_cost, min_distance)) {
                continue;
            }
            var updated_nodes: [100]usize = undefined;
            var idx: usize = 0;
            const threashold = self.step_size * 10;
            for (self.graph.nodes.items) |node| {
                const distance = node.distance(&new_node);
                if (distance < threashold) {
                    updated_nodes[idx] = node.id;
                    idx += 1;
                }
            }
            for (updated_nodes[0..idx]) |id| {
                const node = self.graph.get_node(id);
                const cost = node.cost;

                if (self.get_cost_grid(node.x, node.y)) |cost_n| {
                    const distance_c: usize = @intCast(node.distance(&new_node));
                    const c_p: usize = new_node.cost + @max(1, cost_n) * distance_c;
                    if (cost > c_p) {
                        node.set_parent(new_node.id);
                        node.set_cost(c_p);
                    }
                }
            }

            // add new node to graph and decrement iterations
            try self.graph.add_node(new_node);
            self.max_iterations -= 1;
            // check if end node is reached
            if (new_node.distance(&self.end) < (self.step_size * self.step_size) * 2 and self.end.parent == null) {
                self.end.set_parent(new_node.id);
                // return;
            }
        }
    }
    // transition based rrt (cost efficient path)
    pub fn t_rrt(self: *RRT) !void {
        var rng = std.rand.Xoshiro256.init(0);
        while (self.max_iterations > 0) {
            // generate / sample new node
            var new_node = self.random_node(&rng);
            // validate sampled node
            if (self.grid.check_node_wall(new_node.x, new_node.y)) {
                continue;
            }
            // find closest node
            var parent_id: usize = 0;
            var min_distance: i32 = 10000000;
            for (self.graph.nodes.items) |node| {
                const distance = node.distance(&new_node);
                if (distance < min_distance) {
                    min_distance = distance;
                    parent_id = node.id;
                }
            }
            new_node.set_parent(parent_id);
            // generate closer node if too far
            if (min_distance > (self.step_size * self.step_size) * 2) {
                new_node = new_node.generate_closer_node(self.graph.get_node(parent_id), self.step_size);
            }
            // node validation
            if (self.grid.check_node_wall(new_node.x, new_node.y)) {
                continue;
            }
            const parent = self.graph.get_node(parent_id);
            // set new node cost
            var cost_new: usize = parent.cost;
            const cost_near: usize = parent.cost;
            if (self.get_cost_grid(new_node.x, new_node.y)) |cost_n| {
                cost_new += cost_n;
            } else {
                continue;
            }
            new_node.set_cost(cost_new);
            // transition test for new node
            if (!transition_test(cost_near, cost_new, min_distance)) {
                continue;
            }
            // add new node to graph and decrement iterations
            try self.graph.add_node(new_node);
            self.max_iterations -= 1;
            // check if end node is reached
            if (new_node.distance(&self.end) < (self.step_size * self.step_size) * 2) {
                self.end.set_parent(new_node.id);
                return;
            }
        }
    }
    // basic rrt (shortest path)
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
