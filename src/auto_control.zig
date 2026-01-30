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

    // 获取蛇尾位置
    const snake_tail_data = if (game.snake.last) |tail| snake_module.data_of(tail) else return;
    const snake_tail = Pos{ .x = snake_tail_data.x, .y = snake_tail_data.y };

    const allocator = game.allocator;

    // 尝试找到最近的食物
    const food_direction = findNearestFood(allocator, game, snake_head) catch null;

    if (food_direction) |dir| {
        // 验证吃完食物后是否还有逃生空间（能否到达蛇尾附近）
        if (isSafeMove(allocator, game, snake_head, dir, snake_tail) catch false) {
            game.set_direction(dir);
            return;
        }
    }

    // 如果没有安全的食物路径，就跟随蛇尾移动（保持存活）
    const tail_direction = findPathToTarget(allocator, game, snake_head, snake_tail) catch null;
    if (tail_direction) |dir| {
        game.set_direction(dir);
        return;
    }

    // 如果连蛇尾都到不了（空间很紧），选择能访问最大空间的方向（折叠策略）
    const max_space_direction = findMaxSpaceDirection(allocator, game, snake_head) catch null;
    if (max_space_direction) |dir| {
        game.set_direction(dir);
    }
}

fn findNearestFood(allocator: std.mem.Allocator, game: *snake_module, start: Pos) !?@TypeOf(game.direction) {
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

// 检查移动某个方向后是否还能找到逃生路径（检查能否到达蛇尾附近）
fn isSafeMove(allocator: std.mem.Allocator, game: *snake_module, from: Pos, dir: @TypeOf(game.direction), tail: Pos) !bool {
    // 计算移动后的位置
    const next_pos = blk: {
        var pos = from;
        switch (dir) {
            .Up => {
                if (pos.y > 0) pos.y -= 1;
            },
            .Down => {
                pos.y += 1;
            },
            .Left => {
                if (pos.x > 0) pos.x -= 1;
            },
            .Right => {
                pos.x += 1;
            },
        }
        break :blk pos;
    };

    // 简单检查：从下一步位置能否找到路径到蛇尾附近区域
    const can_reach = try canReachArea(allocator, game, next_pos, tail);
    return can_reach;
}

// 寻找到指定目标的路径方向
fn findPathToTarget(allocator: std.mem.Allocator, game: *snake_module, start: Pos, target: Pos) !?@TypeOf(game.direction) {
    var queue = std.DoublyLinkedList{};
    defer {
        while (queue.pop()) |node| {
            allocator.destroy(find_queue_node(node));
        }
    }

    var visited = std.AutoHashMap(usize, void).init(allocator);
    defer visited.deinit();

    const initial_node = try allocator.create(QueueNode);
    initial_node.* = .{
        .pos = start,
        .prev_dir = null,
        .node = .{},
    };
    queue.append(&initial_node.node);
    try visited.put(start.y * game.world_w + start.x, {});

    const directions = [_]struct { dx: i32, dy: i32, dir: @TypeOf(game.direction) }{
        .{ .dx = 0, .dy = -1, .dir = .Up },
        .{ .dx = 0, .dy = 1, .dir = .Down },
        .{ .dx = -1, .dy = 0, .dir = .Left },
        .{ .dx = 1, .dy = 0, .dir = .Right },
    };

    while (queue.popFirst()) |node| {
        const current = find_queue_node(node);

        // 检查是否到达目标附近（距离<=1）
        const dx = if (current.pos.x > target.x) current.pos.x - target.x else target.x - current.pos.x;
        const dy = if (current.pos.y > target.y) current.pos.y - target.y else target.y - current.pos.y;
        if (dx + dy <= 1) {
            const result = if (current.prev_dir) |dir| directions[dir].dir else null;
            allocator.destroy(current);
            return result;
        }

        for (directions, 0..) |dir_info, dir_idx| {
            const new_x = @as(i32, @intCast(current.pos.x)) + dir_info.dx;
            const new_y = @as(i32, @intCast(current.pos.y)) + dir_info.dy;

            if (new_x < 0 or new_y < 0 or
                new_x >= @as(i32, @intCast(game.world_w)) or
                new_y >= @as(i32, @intCast(game.world_h)))
            {
                continue;
            }

            const next_pos = Pos{ .x = @intCast(new_x), .y = @intCast(new_y) };
            const idx = next_pos.y * game.world_w + next_pos.x;

            if (visited.contains(idx)) continue;

            const block = game.world[idx];
            if (block == .Edge or block == .SnakeBody) {
                continue;
            }

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

    return null;
}

// 检查从起点能否到达目标区域
fn canReachArea(allocator: std.mem.Allocator, game: *snake_module, start: Pos, target: Pos) !bool {
    var queue = std.DoublyLinkedList{};
    defer {
        while (queue.pop()) |node| {
            allocator.destroy(find_queue_node(node));
        }
    }

    var visited = std.AutoHashMap(usize, void).init(allocator);
    defer visited.deinit();

    const initial_node = try allocator.create(QueueNode);
    initial_node.* = .{
        .pos = start,
        .prev_dir = null,
        .node = .{},
    };
    queue.append(&initial_node.node);
    try visited.put(start.y * game.world_w + start.x, {});

    const directions = [_]struct { dx: i32, dy: i32 }{
        .{ .dx = 0, .dy = -1 },
        .{ .dx = 0, .dy = 1 },
        .{ .dx = -1, .dy = 0 },
        .{ .dx = 1, .dy = 0 },
    };

    while (queue.popFirst()) |node| {
        const current = find_queue_node(node);

        // 检查是否到达目标附近
        const dx = if (current.pos.x > target.x) current.pos.x - target.x else target.x - current.pos.x;
        const dy = if (current.pos.y > target.y) current.pos.y - target.y else target.y - current.pos.y;
        if (dx + dy <= 1) {
            allocator.destroy(current);
            return true;
        }

        for (directions) |dir_info| {
            const new_x = @as(i32, @intCast(current.pos.x)) + dir_info.dx;
            const new_y = @as(i32, @intCast(current.pos.y)) + dir_info.dy;

            if (new_x < 0 or new_y < 0 or
                new_x >= @as(i32, @intCast(game.world_w)) or
                new_y >= @as(i32, @intCast(game.world_h)))
            {
                continue;
            }

            const next_pos = Pos{ .x = @intCast(new_x), .y = @intCast(new_y) };
            const idx = next_pos.y * game.world_w + next_pos.x;

            if (visited.contains(idx)) continue;

            const block = game.world[idx];
            if (block == .Edge or block == .SnakeBody) {
                continue;
            }

            const new_node = try allocator.create(QueueNode);
            new_node.* = .{
                .pos = next_pos,
                .prev_dir = null,
                .node = .{},
            };
            queue.append(&new_node.node);
            try visited.put(idx, {});
        }

        allocator.destroy(current);
    }

    return false;
}

// 找到能访问最大空间的方向（用于紧急情况下的折叠策略）
fn findMaxSpaceDirection(allocator: std.mem.Allocator, game: *snake_module, start: Pos) !?@TypeOf(game.direction) {
    const directions = [_]struct { dx: i32, dy: i32, dir: @TypeOf(game.direction) }{
        .{ .dx = 0, .dy = -1, .dir = .Up },
        .{ .dx = 0, .dy = 1, .dir = .Down },
        .{ .dx = -1, .dy = 0, .dir = .Left },
        .{ .dx = 1, .dy = 0, .dir = .Right },
    };

    var max_space: usize = 0;
    var best_dir: ?@TypeOf(game.direction) = null;

    for (directions) |dir_info| {
        const new_x = @as(i32, @intCast(start.x)) + dir_info.dx;
        const new_y = @as(i32, @intCast(start.y)) + dir_info.dy;

        // 检查边界
        if (new_x < 0 or new_y < 0 or
            new_x >= @as(i32, @intCast(game.world_w)) or
            new_y >= @as(i32, @intCast(game.world_h)))
        {
            continue;
        }

        const next_pos = Pos{ .x = @intCast(new_x), .y = @intCast(new_y) };
        const idx = next_pos.y * game.world_w + next_pos.x;

        // 跳过墙壁和蛇身
        const block = game.world[idx];
        if (block == .Edge or block == .SnakeBody) {
            continue;
        }

        // 计算从这个位置能访问多少空格
        const space = countReachableSpace(allocator, game, next_pos) catch 0;
        if (space > max_space) {
            max_space = space;
            best_dir = dir_info.dir;
        }
    }

    return best_dir;
}

// 计算从某个位置能访问到的空格数量
fn countReachableSpace(allocator: std.mem.Allocator, game: *snake_module, start: Pos) !usize {
    var queue = std.DoublyLinkedList{};
    defer {
        while (queue.pop()) |node| {
            allocator.destroy(find_queue_node(node));
        }
    }

    var visited = std.AutoHashMap(usize, void).init(allocator);
    defer visited.deinit();

    const initial_node = try allocator.create(QueueNode);
    initial_node.* = .{
        .pos = start,
        .prev_dir = null,
        .node = .{},
    };
    queue.append(&initial_node.node);
    try visited.put(start.y * game.world_w + start.x, {});

    const directions = [_]struct { dx: i32, dy: i32 }{
        .{ .dx = 0, .dy = -1 },
        .{ .dx = 0, .dy = 1 },
        .{ .dx = -1, .dy = 0 },
        .{ .dx = 1, .dy = 0 },
    };

    var count: usize = 0;

    while (queue.popFirst()) |node| {
        const current = find_queue_node(node);
        count += 1;

        for (directions) |dir_info| {
            const new_x = @as(i32, @intCast(current.pos.x)) + dir_info.dx;
            const new_y = @as(i32, @intCast(current.pos.y)) + dir_info.dy;

            if (new_x < 0 or new_y < 0 or
                new_x >= @as(i32, @intCast(game.world_w)) or
                new_y >= @as(i32, @intCast(game.world_h)))
            {
                continue;
            }

            const next_pos = Pos{ .x = @intCast(new_x), .y = @intCast(new_y) };
            const idx = next_pos.y * game.world_w + next_pos.x;

            if (visited.contains(idx)) continue;

            const block = game.world[idx];
            if (block == .Edge or block == .SnakeBody) {
                continue;
            }

            const new_node = try allocator.create(QueueNode);
            new_node.* = .{
                .pos = next_pos,
                .prev_dir = null,
                .node = .{},
            };
            queue.append(&new_node.node);
            try visited.put(idx, {});
        }

        allocator.destroy(current);
    }

    return count;
}
