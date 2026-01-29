const Game = @This();
const GameConfig = @import("config.zig");

/// 世界宽度
pub const WORLD_W = 20;
/// 世界高度
pub const WORLD_H = 20;

const std = @import("std");
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

pub const Direction = enum {
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

pub fn set_direction(new_dir: Direction) void {
    switch (direction) {
        .Up => if (new_dir == .Down) return,
        .Down => if (new_dir == .Up) return,
        .Left => if (new_dir == .Right) return,
        .Right => if (new_dir == .Left) return,
    }
    direction = new_dir;
}

const Pos = struct {
    x: u8,
    y: u8,
};

const SnakeNode = struct {
    data: Pos,
    node: std.DoublyLinkedList.Node,
};

pub var world: [WORLD_H][WORLD_W]Block = undefined;
pub var game_status = GameStatus.Playing;
var snake = std.DoublyLinkedList{ .first = null, .last = null };
var snake_buffer: [WORLD_H * WORLD_W * @sizeOf(SnakeNode) * 4]u8 = undefined;
var sfba = std.heap.FixedBufferAllocator.init(&snake_buffer);
var sa = sfba.allocator();
pub var direction = Direction.Left;
var prng = std.Random.DefaultPrng.init(114514);
var rng = prng.random();
var food_count: usize = 0;
pub var score: u32 = 0;

const LENGTH_INIT = 5;

pub fn game_stoped() bool {
    return game_status != .Playing;
}

pub fn init(config: GameConfig) !void {
    game_status = .Playing;
    direction = .Left;
    score = 0;
    food_count = config.food;

    for (0..WORLD_H) |y| {
        for (0..WORLD_W) |x| {
            world[y][x] = if (x == 0 or y == 0 or x == WORLD_W - 1 or y == WORLD_H - 1)
                Block.Edge
            else
                Block.Empty;
        }
    }

    // deallocate existing snake nodes
    while (snake.first != null) {
        sa.destroy(find_snake_node(snake.pop().?));
    }

    // create initial snake
    var init_snakes = try sa.alloc(SnakeNode, 5);

    for (0..LENGTH_INIT) |i| {
        const pos = Pos{
            .x = @truncate(WORLD_H - 6 + i),
            .y = WORLD_H / 2,
        };
        init_snakes[i].data = pos;
        snake.append(&init_snakes[i].node);
        world[pos.y][pos.x] = Block.SnakeBody;
    }

    for (0..config.food) |_| {
        generate_random_food();
    }
}

fn cannot_generate_food() bool {
    return score >= (WORLD_W - 2) * (WORLD_H - 2) - LENGTH_INIT - food_count;
}

fn generate_random_food() void {
    // cannot generate more food
    if (cannot_generate_food()) {
        return;
    }

    while (true) {
        const x = std.Random.intRangeAtMost(rng, u8, 1, WORLD_W - 2);
        const y = std.Random.intRangeAtMost(rng, u8, 1, WORLD_H - 2);

        if (world[y][x] == Block.Empty) {
            world[y][x] = Block.Food;
            return;
        }
    }
}

fn find_snake_node(node: *std.DoublyLinkedList.Node) *SnakeNode {
    return @as(*SnakeNode, @fieldParentPtr("node", node));
}

pub fn tick() !void {
    if (game_stoped()) {
        return;
    }

    var next_pos = find_snake_node(snake.first.?).data;
    switch (direction) {
        Direction.Left => next_pos.x -= 1,
        Direction.Right => next_pos.x += 1,
        Direction.Up => next_pos.y -= 1,
        Direction.Down => next_pos.y += 1,
    }
    const hit = world[next_pos.y][next_pos.x];
    switch (hit) {
        Block.Edge => game_status = .Lost,
        Block.SnakeBody => game_status = .Lost,
        Block.Food => {
            var new_body = try sa.alloc(SnakeNode, 1);
            new_body[0].data = next_pos;
            snake.prepend(&new_body[0].node);
            world[next_pos.y][next_pos.x] = Block.SnakeBody;
            score += 1;
            if (cannot_generate_food()) {
                game_status = .Win;
                return;
            }
            generate_random_food();
        },
        Block.Empty => {
            var head = find_snake_node(snake.pop().?);
            world[head.data.y][head.data.x] = Block.Empty;
            head.data = next_pos;
            snake.prepend(&head.node);
            world[next_pos.y][next_pos.x] = Block.SnakeBody;
        },
    }
}
