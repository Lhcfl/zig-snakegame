# zig-snakegame

Zig 写的贪吃蛇游戏，兼容 windows 和 linux

允许自动吃食物

### 运行方式

```
zig build run
```

```
Snake Game! powered by Zig and Vaxis
Usage:
  --max-speed <number>   Set the maximum speed (ticks per second). Default is 25.
  --food <number>        Set the number of food items in the game. Default is 3.
  --size <number>        Set the size of the game world (width and height). Default is 20.
  --basic                Enable basic mode (no color and simplified rendering).
  --auto <id>            Enable automatic control: 0=simp, 1=bfs.
Enjoy the game!
```
