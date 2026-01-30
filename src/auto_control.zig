const std = @import("std");
const snake_module = @import("snake.zig");

const Pos = struct {
    x: usize,
    y: usize,
};

const QueueNode = struct {
    pos: Pos,
    prev_dir: ?u8, // 0=Up, 1=Down, 2=Left, 3=Right
    node: std.DoublyLinkedList.Node,
};

fn find_queue_node(node: *std.DoublyLinkedList.Node) *QueueNode {
    return @fieldParentPtr("node", node);
}

pub fn auto_control(game: *snake_module) void {
    // 获取蛇头位置
    if (game.snake.first == null) return;
    const snake_head_data = snake_module.data_of(game.snake.first.?);
    const snake_head = Pos{ .x = snake_head_data.x, .y = snake_head_data.y };

    // 使用BFS寻找到最近食物的安全路径
    const allocator = game.allocator;
    const direction = findDirection(allocator, game, snake_head) catch return;

    if (direction) |dir| {
        game.set_direction(dir);
    }
}

fn findDirection(allocator: std.mem.Allocator, game: *snake_module, start: Pos) !?@TypeOf(game.direction) {
    var queue = std.DoublyLinkedList{};
    defer {
        while (queue.pop()) |node| {
            allocator.destroy(find_queue_node(node));
        }
    }

    var visited = std.AutoHashMap(usize, void).init(allocator);
    defer visited.deinit();

    // 初始化队列，起点没有方向
    {
        const initial_node = try allocator.create(QueueNode);
        initial_node.* = .{
            .pos = start,
            .prev_dir = null,
            .node = .{},
        };
        queue.append(&initial_node.node);
        try visited.put(start.y * game.world_w + start.x, {});
    }

    const directions = [_]struct { dx: i32, dy: i32, dir: @TypeOf(game.direction) }{
        .{ .dx = 0, .dy = -1, .dir = .Up },
        .{ .dx = 0, .dy = 1, .dir = .Down },
        .{ .dx = -1, .dy = 0, .dir = .Left },
        .{ .dx = 1, .dy = 0, .dir = .Right },
    };

    while (queue.popFirst()) |node| {
        const current = find_queue_node(node);
        const current_idx = current.pos.y * game.world_w + current.pos.x;

        // 检查当前位置是否是食物（找到最近的食物）
        if (game.world[current_idx] == .Food) {
            const result = if (current.prev_dir) |dir| directions[dir].dir else null;
            allocator.destroy(current);
            return result;
        }

        // 探索四个方向
        for (directions, 0..) |dir_info, dir_idx| {
            const new_x = @as(i32, @intCast(current.pos.x)) + dir_info.dx;
            const new_y = @as(i32, @intCast(current.pos.y)) + dir_info.dy;

            // 检查边界
            if (new_x < 0 or new_y < 0 or
                new_x >= @as(i32, @intCast(game.world_w)) or
                new_y >= @as(i32, @intCast(game.world_h)))
            {
                continue;
            }

            const next_pos = Pos{ .x = @intCast(new_x), .y = @intCast(new_y) };
            const idx = next_pos.y * game.world_w + next_pos.x;

            // 检查是否已访问
            if (visited.contains(idx)) continue;

            // 检查是否可通行（避开墙壁和蛇身体）
            const block = game.world[idx];
            if (block == .Edge or block == .SnakeBody) {
                continue;
            }

            // 添加到队列
            const new_node = try allocator.create(QueueNode);
            new_node.* = .{
                .pos = next_pos,
                .prev_dir = if (current.prev_dir == null) @intCast(dir_idx) else current.prev_dir,
                .node = .{},
            };
            queue.append(&new_node.node);
            try visited.put(idx, {});
        }

        allocator.destroy(current);
    }

    return null; // 未找到路径
}
