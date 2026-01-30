const std = @import("std");
const snake_module = @import("snake.zig");

pub fn simp_auto_control(game: *snake_module) void {
    if (game.snake.first == null) return;

    const head_data = snake_module.data_of(game.snake.first.?);
    const head_x: usize = head_data.x;
    const head_y: usize = head_data.y;

    const top_y: usize = 1;
    const bottom_y: usize = if (game.world_h > 2) game.world_h - 2 else 1;
    const return_x: usize = 1;
    const scan_min_x: usize = 2;
    const scan_max_x: usize = if (game.world_w > 2) game.world_w - 2 else 1;

    // 已在返回通道且不在第一行时，向上回到第一行
    if (head_x == return_x and head_y > top_y) {
        game.set_direction(.Up);
        return;
    }

    // 在第一行准备进入扫描区
    if (head_y == top_y and head_x < scan_min_x) {
        game.set_direction(.Right);
        return;
    }

    // 进入扫描逻辑（蛇形遍历），保留 return_x 作为回到第一行的通道
    const row_index: usize = head_y - top_y;
    const going_right: bool = (row_index % 2 == 0);

    // 到达最底行后，回到返回通道
    if (head_y == bottom_y) {
        if (head_x > return_x) {
            game.set_direction(.Left);
            return;
        }
        // 已在返回通道，向上回到第一行
        game.set_direction(.Up);
        return;
    }

    if (going_right) {
        if (head_x < scan_max_x) {
            game.set_direction(.Right);
            return;
        }
        // 行末，向下进入下一行
        game.set_direction(.Down);
        return;
    }

    // going left
    if (head_x > scan_min_x) {
        game.set_direction(.Left);
        return;
    }
    // 行末，向下进入下一行
    game.set_direction(.Down);
}
