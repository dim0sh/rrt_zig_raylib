const std = @import("std");
const ray = @cImport(@cInclude("raylib.h"));
const ArrayList = std.ArrayList;
const Map = std.AutoArrayHashMap;

pub const Graph = struct {
    nodes: ArrayList(Node),

    pub fn init(allocator: std.mem.Allocator) Graph {
        return Graph{
            .nodes = ArrayList(Node).init(allocator),
        };
    }

    pub fn deinit(self: *Graph) void {
        self.nodes.deinit();
    }

    pub fn add_node(self: *Graph, node: Node) !void {
        try self.nodes.append(node);
    }

    pub fn get_node(self: *Graph, id: usize) *Node {
        return &self.nodes.items[id];
    }

    pub fn get_parent(self: *Graph, node: *const Node) *Node {
        return &self.nodes.items[node.parent.?];
    }

    pub fn draw(self: *Graph, cell_width: usize, color: ray.Color) void {
        for (self.nodes.items) |node| {
            const x = node.x;
            const y = node.y;
            const c_x: c_int = @intCast(x);
            const c_y: c_int = @intCast(y);
            const c_cell_width: f32 = @floatFromInt(cell_width);
            // const color = ray.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
            ray.DrawCircle(c_x, c_y, c_cell_width, color);
            // ray.DrawRectangle(c_x, c_y, c_cell_width, c_cell_width, color);
            if (node.parent != null) {
                const parent = self.get_parent(&node);
                node.draw_to_parent(parent, color);
            }
        }
    }
};

pub const Node = struct {
    id: usize,
    x: i32,
    y: i32,
    parent: ?usize,

    pub fn new(id: usize, x: i32, y: i32, parent: ?usize) Node {
        return Node{
            .id = id,
            .x = x,
            .y = y,
            .parent = parent,
        };
    }

    pub fn set_parent(self: *Node, parent: ?usize) void {
        self.parent = parent;
    }

    pub fn draw_to_parent(self: *const Node, parent: *const Node, color: ray.Color) void {
        // ray.DrawLine(self.x, self.y, parent.x, parent.y, color);
        const start = ray.Vector2{ .x = @floatFromInt(self.x), .y = @floatFromInt(self.y) };
        const end = ray.Vector2{ .x = @floatFromInt(parent.x), .y = @floatFromInt(parent.y) };
        ray.DrawLineEx(start, end, 5, color);
    }

    pub fn distance(self: *const Node, other: *const Node) i32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return dx * dx + dy * dy;
    }

    pub fn generate_closer_node(self: *const Node, parent: *const Node, step_size: usize) Node {
        const f_step_size: f32 = @floatFromInt(step_size);
        const dx = self.x - parent.x;
        const dy = self.y - parent.y;
        const f_p_x: f32 = @floatFromInt(parent.x);
        const f_p_y: f32 = @floatFromInt(parent.y);
        const f_dx: f32 = @floatFromInt(dx);
        const f_dy: f32 = @floatFromInt(dy);
        const node_distance = @sqrt(f_dx * f_dx + f_dy * f_dy);
        const x = f_p_x + (f_dx / node_distance) * f_step_size;
        const y = f_p_y + (f_dy / node_distance) * f_step_size;
        const i_x: i32 = @intFromFloat(x);
        const i_y: i32 = @intFromFloat(y);
        return Node.new(self.id, i_x, i_y, parent.id);
    }
};
