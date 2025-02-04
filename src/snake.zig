/// 世界宽度
const WORLD_W = 20;
/// 世界高度
const WORLD_H = 20;

const std = @import("std");
const io = @import("io.zig");
const systemTag = @import("builtin").os.tag;

const GameStatus = enum {
    Playing,
    Lost,
    Win,

    pub inline fn toString(self: GameStatus) []const u8 {
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

    pub inline fn toString(self: Block) []const u8 {
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

    pub inline fn toString(self: Direction) []const u8 {
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

const Pos = struct {
    x: u8,
    y: u8,
};

const SnakeNode = std.TailQueue(Pos).Node;

var world: [WORLD_H][WORLD_W]Block = undefined;
var game_status = GameStatus.Playing;
var snake = std.TailQueue(Pos){};
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

    while (snake.len > 0) {
        snake_allocator.destroy(snake.pop().?);
    }

    var init_snakes = try snake_allocator.alloc(SnakeNode, 5);

    for (0..5) |i| {
        const pos = Pos{
            .x = @truncate(WORLD_H - 6 + i),
            .y = WORLD_H / 2,
        };
        init_snakes[i].data = pos;
        snake.append(&init_snakes[i]);
        world[pos.y][pos.x] = Block.SnakeBody;
    }

    generate_random_food();
    generate_random_food();
    generate_random_food();
}

fn generate_random_food() void {
    while (true) {
        const x = std.rand.intRangeAtMost(rng, u8, 1, WORLD_W - 2);
        const y = std.rand.intRangeAtMost(rng, u8, 1, WORLD_H - 2);

        if (world[y][x] == Block.Empty) {
            world[y][x] = Block.Food;
            return;
        }
    }
}

pub fn tick() anyerror!void {
    if (game_stoped()) {
        return;
    }

    var next_pos = snake.first.?.data;
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
            snake.prepend(&new_body[0]);
            world[next_pos.y][next_pos.x] = Block.SnakeBody;
            generate_random_food();
        },
        Block.Empty => {
            var head = snake.pop().?;
            world[head.data.y][head.data.x] = Block.Empty;
            head.data = next_pos;
            snake.prepend(head);
            world[next_pos.y][next_pos.x] = Block.SnakeBody;
        },
    }
}

pub fn printWorld() void {
    var buffer: [20]u8 = undefined;
    // 回到左上角
    io.moveTo00();
    io.output("Snake Game! Score: ");
    const score = std.fmt.bufPrint(&buffer, "{d}", .{snake.len - 5}) catch "0";
    io.output(score);
    io.output("\nDirection: ");
    io.output(direction.toString());
    io.output("\n");
    io.output(game_status.toString());
    io.output("\n");
    for (&world) |line| {
        for (&line) |block| {
            io.output(block.toString());
        }
        io.output("\n");
    }
    if (game_stoped()) {
        io.output("Press any key to reset. ");
    }
    io.output("Press Q to quit.\n");
    io.refresh();
}
