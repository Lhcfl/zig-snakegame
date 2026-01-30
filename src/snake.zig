const std = @import("std");
const GameConfig = @import("config.zig");
const Game = @This();

const GameStatus = enum {
    Playing,
    Lost,
    Win,
};

const Block = enum(u8) {
    Empty,
    Edge,
    Food,
    SnakeBody,

    pub inline fn render(self: Block) []const u8 {
        return switch (self) {
            .Empty => "  ",
            .Edge => "██",
            .Food => "💖",
            .SnakeBody => "()",
        };
    }
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,

    pub inline fn to_string(self: Direction) []const u8 {
        return switch (self) {
            .Up => "⬆️",
            .Down => "⬇️",
            .Left => "⬅️",
            .Right => "➡️",
        };
    }
};

pub fn set_direction(self: *Game, new_dir: Direction) void {
    switch (self.direction) {
        .Up => if (new_dir == .Down) return,
        .Down => if (new_dir == .Up) return,
        .Left => if (new_dir == .Right) return,
        .Right => if (new_dir == .Left) return,
    }
    self.direction = new_dir;
}

const Pos = struct {
    x: usize,
    y: usize,
};

const SnakeNode = struct {
    data: Pos,
    node: std.DoublyLinkedList.Node,
};

/// 世界宽度
world_w: usize = 20,
/// 世界高度
world_h: usize = 20,
world: []Block = undefined,
game_status: GameStatus = .Playing,
snake: std.DoublyLinkedList = .{},
direction: Direction = Direction.Left,
prng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(114514),
rng: std.Random = undefined,
food_count: usize = 0,
score: u32 = 0,
allocator: std.mem.Allocator = undefined,
first_inited: bool = false,

pub const LENGTH_INIT = 5;

pub fn game_stoped(self: *Game) bool {
    return self.game_status != .Playing;
}

pub fn deinit(self: *Game) void {
    self.allocator.free(self.world);

    // deallocate existing snake nodes
    while (self.snake.first != null) {
        self.allocator.destroy(find_snake_node(self.snake.pop().?));
    }
}

pub fn indexOf(self: *Game, pos: Pos) usize {
    return @as(usize, pos.y) * self.world_w + @as(usize, pos.x);
}

pub fn init(self: *Game, config: GameConfig) !void {
    if (self.first_inited) {
        self.deinit();
    }

    self.first_inited = true;
    self.world_h = config.size;
    self.world_w = config.size;
    self.allocator = config.allocator;
    self.world = try self.allocator.alloc(Block, self.world_h * self.world_w);
    self.game_status = .Playing;
    self.rng = self.prng.random();
    self.direction = .Left;
    self.score = 0;
    self.food_count = config.food;

    for (0..self.world_h) |y| {
        for (0..self.world_w) |x| {
            self.world[self.indexOf(Pos{ .x = x, .y = y })] = if (x == 0 or y == 0 or x == self.world_w - 1 or y == self.world_h - 1)
                Block.Edge
            else
                Block.Empty;
        }
    }

    for (0..LENGTH_INIT) |i| {
        const pos = Pos{
            .x = @truncate(self.world_w - 6 + i),
            .y = self.world_h / 2,
        };
        const one = try self.allocator.create(SnakeNode);
        one.data = pos;
        self.snake.append(&one.node);
        self.world[self.indexOf(pos)] = Block.SnakeBody;
    }

    for (0..config.food) |_| {
        self.generate_random_food();
    }
}

fn cannot_generate_food(self: *Game) bool {
    return self.score >= (self.world_w - 2) * (self.world_h - 2) - LENGTH_INIT - self.food_count;
}

fn generate_random_food(self: *Game) void {
    // cannot generate more food
    if (self.cannot_generate_food()) {
        return;
    }

    const total_space = (self.world_w - 2) * (self.world_h - 2);
    const threshold = total_space / 20; // 5%

    // 计算空位数量：总空间 - 蛇身长度 - 食物数量
    const snake_length = LENGTH_INIT + self.score;
    const empty_count = total_space - snake_length - self.food_count;

    // 空位较少时，遍历收集所有空位并随机选择
    if (empty_count < threshold and empty_count > 0) {
        var empty_positions = self.allocator.alloc(Pos, empty_count) catch {
            // 分配失败，直接返回
            return;
        };
        defer self.allocator.free(empty_positions);

        var idx: usize = 0;
        for (0..self.world_h) |y| {
            for (0..self.world_w) |x| {
                const pos = Pos{ .x = x, .y = y };
                if (self.world[self.indexOf(pos)] == Block.Empty) {
                    empty_positions[idx] = pos;
                    idx += 1;
                }
            }
        }

        const selected = std.Random.intRangeAtMost(self.rng, usize, 0, empty_count - 1);
        const food_pos = empty_positions[selected];
        self.world[self.indexOf(food_pos)] = Block.Food;
        return;
    }

    // 空位充足时，直接随机
    while (true) {
        const x = std.Random.intRangeAtMost(self.rng, usize, 1, self.world_w - 2);
        const y = std.Random.intRangeAtMost(self.rng, usize, 1, self.world_h - 2);

        if (self.world[self.indexOf(Pos{ .x = x, .y = y })] == Block.Empty) {
            self.world[self.indexOf(Pos{ .x = x, .y = y })] = Block.Food;
            return;
        }
    }
}

fn find_snake_node(node: *std.DoublyLinkedList.Node) *SnakeNode {
    return @as(*SnakeNode, @fieldParentPtr("node", node));
}

pub fn data_of(node: *std.DoublyLinkedList.Node) Pos {
    return find_snake_node(node).data;
}

pub fn tick(self: *Game) !void {
    if (self.game_stoped()) {
        return;
    }

    var next_pos = find_snake_node(self.snake.first.?).data;
    switch (self.direction) {
        Direction.Left => next_pos.x -= 1,
        Direction.Right => next_pos.x += 1,
        Direction.Up => next_pos.y -= 1,
        Direction.Down => next_pos.y += 1,
    }
    const hit = self.world[self.indexOf(next_pos)];
    switch (hit) {
        Block.Edge => self.game_status = .Lost,
        Block.SnakeBody => self.game_status = .Lost,
        Block.Food => {
            var new_body = try self.allocator.alloc(SnakeNode, 1);
            new_body[0].data = next_pos;
            self.snake.prepend(&new_body[0].node);
            self.world[self.indexOf(next_pos)] = Block.SnakeBody;
            self.generate_random_food();
            self.score += 1;
            if (self.score >= (self.world_w - 2) * (self.world_h - 2) - LENGTH_INIT) {
                self.game_status = .Win;
                return;
            }
        },
        Block.Empty => {
            var head = find_snake_node(self.snake.pop().?);
            self.world[self.indexOf(head.data)] = Block.Empty;
            head.data = next_pos;
            self.snake.prepend(&head.node);
            self.world[self.indexOf(next_pos)] = Block.SnakeBody;
        },
    }
}
