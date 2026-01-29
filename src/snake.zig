/// 世界宽度
pub const WORLD_W = 20;
/// 世界高度
pub const WORLD_H = 20;

const std = @import("std");
const systemTag = @import("builtin").os.tag;

const GameStatus = enum {
    Playing,
    Lost,
    Win,

    pub inline fn to_string(self: GameStatus) []const u8 {
        return switch (self) {
            .Playing => "",
            .Lost => "You Lost!!",
            .Win => "You Win!!",
        };
    }
};

const Block = enum(u8) {
    Empty,
    Edge,
    Food,
    SnakeBody,

    pub inline fn to_string(self: Block) []const u8 {
        return switch (self) {
            .Empty => "  ",
            .Edge => "##",
            .Food => if (systemTag == .linux) "<>" else "💖",
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
        if (systemTag == .linux) {
            return switch (self) {
                .Up => "Up",
                .Down => "Down",
                .Left => "Left",
                .Right => "Right",
            };
        } else {
            return switch (self) {
                .Up => "⬆️",
                .Down => "⬇️",
                .Left => "⬅️",
                .Right => "➡️",
            };
        }
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

var world: [WORLD_H][WORLD_W]Block = undefined;
var game_status = GameStatus.Playing;
var snake = std.DoublyLinkedList{ .first = null, .last = null };
var snake_buffer: [WORLD_H * WORLD_W * @sizeOf(SnakeNode)]u8 = undefined;
var snake_allocator_main = std.heap.FixedBufferAllocator.init(&snake_buffer);
var snake_allocator = snake_allocator_main.allocator();
pub var direction = Direction.Left;
var prng = std.Random.DefaultPrng.init(114514);
var rng = prng.random();

pub fn game_stoped() bool {
    return game_status != GameStatus.Playing;
}

pub fn init() anyerror!void {
    game_status = GameStatus.Playing;
    direction = Direction.Left;

    for (0..WORLD_H) |y| {
        for (0..WORLD_W) |x| {
            world[y][x] = if (x == 0 or y == 0 or x == WORLD_W - 1 or y == WORLD_H - 1)
                Block.Edge
            else
                Block.Empty;
        }
    }

    while (snake.first != null) {
        snake_allocator.destroy(find_snake_node(snake.pop().?));
    }

    var init_snakes = try snake_allocator.alloc(SnakeNode, 5);

    for (0..5) |i| {
        const pos = Pos{
            .x = @truncate(WORLD_H - 6 + i),
            .y = WORLD_H / 2,
        };
        init_snakes[i].data = pos;
        snake.append(&init_snakes[i].node);
        world[pos.y][pos.x] = Block.SnakeBody;
    }

    generate_random_food();
    generate_random_food();
    generate_random_food();
}

fn generate_random_food() void {
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

pub fn tick() anyerror!void {
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
        Block.Edge => game_status = GameStatus.Lost,
        Block.SnakeBody => game_status = GameStatus.Lost,
        Block.Food => {
            var new_body = try snake_allocator.alloc(SnakeNode, 1);
            new_body[0].data = next_pos;
            snake.prepend(&new_body[0].node);
            world[next_pos.y][next_pos.x] = Block.SnakeBody;
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

var text_buf: [2 * WORLD_H * WORLD_W + 1024]u8 = undefined;
var text_idx: usize = 0;

fn print(comptime fmt: []const u8, args: anytype) !void {
    const buf = try std.fmt.bufPrint(text_buf[text_idx..], fmt, args);
    text_idx += buf.len;
}

pub fn gen_world() error{NoSpaceLeft}![]const u8 {
    text_buf = .{0} ** text_buf.len;
    text_idx = 0;

    try print("score = {d}, dir = {s}\n", .{ snake.len() - 5, direction.to_string() });

    for (&world) |line| {
        for (&line) |block| {
            try print("{s}", .{block.to_string()});
        }
        try print("\n", .{});
    }

    try print("Press Q to exit\n", .{});

    if (game_stoped()) {
        try print("{s} Press any key to restart\n", .{game_status.to_string()});
    } else {
        try print("Use ↑ ↓ ← → to move\n", .{});
    }

    return &text_buf;
}
