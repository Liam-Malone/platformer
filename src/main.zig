const std = @import("std");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");
const player = @import("player.zig");
const map = @import("map.zig");
const c = @import("c.zig");

const Player = player.Player;
const Window = graphics.Window;

const FPS = 60;
const BACKGROUND_COLOR = graphics.Color.dark_gray;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const TILE_WIDTH = 20;
const TILE_HEIGHT = 20;

var window_width: i32 = 800;
var window_height: i32 = 600;
var quit: bool = false;
var edit_enabled: bool = false;
var pause: bool = true;
var selected_id: u8 = 1;
var left_mouse_is_down = false;

fn place_at_pos(x: u32, y: u32, tilemap: *map.Tilemap) void {
    if (edit_enabled) tilemap.edit_tile(selected_id, x / (TILE_WIDTH), y / (TILE_HEIGHT));
}

fn save(tm: *map.Tilemap, allocator: std.mem.Allocator) !void {
    try tm.save(allocator);
}

fn is_collidable(t_id: map.Tilemap.Tile_ID) bool {
    switch (t_id) {
        .Flooring, .MovingPlatform, .StationaryPlatform => return true,
        else => return false,
    }
}

// *** TODO ***
//  FIX THIS THING COS I'M BRAINDEAD
fn vcollide_player_with_tiles(p: *player.Player, tm: *map.Tilemap) bool {
    if (p.y < 0 or p.y > WINDOW_HEIGHT) return false;
    if (p.dy == 0) {
        const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
        const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
        if (p.y + p.h >= tm.tiles[y_idx][x_idx].y and is_collidable(tm.tiles[y_idx][x_idx].id)) {
            return true;
        }
        return false;
    }
    switch (p.dy > 0) {
        true => {
            const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
            const y_idx: usize = @intCast(@divFloor(p.y + p.h + p.dy, TILE_HEIGHT));
            if (p.y + p.h + p.dy >= tm.tiles[y_idx][x_idx].y and is_collidable(tm.tiles[y_idx][x_idx].id)) {
                if (p.dy > 0) p.dy = 0;
                return true;
            }
            return false;
        },
        false => {
            const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
            const y_idx: usize = @intCast(@divFloor(if (p.y + p.dy > 0) p.y + p.dy else p.y, TILE_HEIGHT));
            if (p.y + p.dy <= tm.tiles[y_idx][x_idx].y + tm.tiles[y_idx][x_idx].h and is_collidable(tm.tiles[y_idx][x_idx].id)) {
                if (p.dy < 0) p.dy = 0;
                return true;
            }
            return false;
        },
    }
}
fn hcollide_player_with_tiles(p: *player.Player, tm: *map.Tilemap) bool {
    if (p.x < 0 or p.x > WINDOW_WIDTH) return false;
    if (p.dx == 0) {
        const x_idx: usize = @intCast(@divFloor(p.x, TILE_WIDTH));
        const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
        if (p.x + p.w >= tm.tiles[y_idx - 1][x_idx].x and is_collidable(tm.tiles[y_idx - 1][x_idx].id)) {
            return true;
        }
        return false;
    }
    switch (p.dx > 0) {
        true => {
            const x_idx: usize = @intCast(@divFloor(p.x + p.w + p.dx, TILE_WIDTH));
            const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
            if (p.x + p.w + p.dx >= tm.tiles[y_idx - 1][x_idx].x and is_collidable(tm.tiles[y_idx - 1][x_idx].id)) {
                if (p.dx > 0) p.dx = 0;
                return true;
            }
            return false;
        },
        false => {
            const x_idx: usize = @intCast(@divFloor(if (p.x + p.dx > 0) p.x + p.dx else p.x, TILE_HEIGHT));
            const y_idx: usize = @intCast(@divFloor(p.y + p.h, TILE_HEIGHT));
            if (p.x + p.dx <= tm.tiles[y_idx - 1][x_idx].x + tm.tiles[y_idx - 1][x_idx].w and is_collidable(tm.tiles[y_idx - 1][x_idx].id)) {
                if (p.dx < 0) p.dx = 0;
                return true;
            }
            return false;
        },
    }
}

pub fn main() !void {
    var window = try Window.init("ShooterGame", 0, 0, window_width, window_height);
    defer window.deinit();

    audio.open_audio(44100, 8, 2048);
    defer audio.close_audio();

    var music = audio.Music.init("assets/music/8_Bit_Nostalgia.mp3");
    defer music.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var the_player = Player.init(20, 0, 20, 30, null);
    var the_map = try map.Tilemap.init(alloc, WINDOW_WIDTH, WINDOW_HEIGHT, TILE_WIDTH, TILE_HEIGHT, "assets/maps/testing.map");

    music.play();
    music.toggle_pause();

    var render_grid = true;

    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    'q' => {
                        quit = true;
                    },
                    'm' => music.toggle_pause(),
                    'a' => the_player.dx = -2,
                    'd' => the_player.dx = 2,
                    's' => {
                        if (event.key.keysym.mod & c.KMOD_CTRL != 0) {
                            var t = try std.Thread.spawn(.{}, save, .{ &the_map, alloc });
                            t.detach();
                        }
                    },
                    ' ' => the_player.dy = -20,
                    'e' => edit_enabled = !edit_enabled,
                    'g' => render_grid = !render_grid,
                    '0' => selected_id = 0,
                    '1' => selected_id = 1,
                    '2' => selected_id = 2,
                    '3' => selected_id = 3,
                    else => {},
                },
                c.SDL_KEYUP => switch (event.key.keysym.sym) {
                    'a', 'd' => the_player.dx = 0,
                    else => {},
                },
                c.SDL_MOUSEBUTTONDOWN => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = true;
                    },
                    else => {},
                },
                c.SDL_MOUSEBUTTONUP => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = false;
                        //clicked_button = false;
                    },
                    else => {},
                },
                c.SDL_MOUSEMOTION => switch (left_mouse_is_down) {
                    true => {
                        const x = if (event.button.x > 0) @as(u32, @intCast(event.button.x)) else 0;
                        const y = if (event.button.y > 0) @as(u32, @intCast(event.button.y)) else 0;
                        place_at_pos(x, y, &the_map);
                        window.update();
                    },
                    false => {},
                },

                else => {},
            }
        }

        window.set_render_color(BACKGROUND_COLOR);
        window.update();
        window.render();

        the_map.draw(&window, render_grid);

        for (the_map.tiles, 0..) |row, i| {
            for (row, 0..) |_, j| {
                if (the_map.tiles[i][j].id == .MovingPlatform) {
                    if (the_map.tiles[i][j].x == 0 or the_map.tiles[i][j].x == WINDOW_WIDTH) the_map.tiles[i][j].dx *= -1;
                    if (the_map.tiles[i][j].y == 0 or the_map.tiles[i][j].y == WINDOW_HEIGHT) the_map.tiles[i][j].dy *= -1;
                    the_map.tiles[i][j].x += the_map.tiles[i][j].dx;
                    the_map.tiles[i][j].y += the_map.tiles[i][j].dy;
                }
            }
        }

        the_player.draw(&window);

        if (!vcollide_player_with_tiles(&the_player, &the_map)) {
            if (the_player.dy < 6) the_player.dy += 1;
            the_player.y += the_player.dy;
        }
        if (!hcollide_player_with_tiles(&the_player, &the_map)) {
            the_player.x += the_player.dx;
        }

        c.SDL_RenderPresent(window.renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
