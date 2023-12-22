const map = @import("map.zig");
const sdl = @import("sdl.zig");
const std = @import("std");

// BEGIN ENUMS
pub const Color = enum(u32) {
    white = 0xFFFFFFFF,
    purple = 0x7BF967AA,
    red = 0xFC1A17CC,
    dark_gray = 0x181818FF,
    blue = 0x0000CCFF,
    green = 0x00AA00FF,
    void = 0xFF00FFFF,

    pub fn make_sdl_color(col: Color) sdl.SDL_Color {
        var color = @intFromEnum(col);
        const r: u8 = @truncate((color >> (3 * 8)) & 0xFF);
        const g: u8 = @truncate((color >> (2 * 8)) & 0xFF);
        const b: u8 = @truncate((color >> (1 * 8)) & 0xFF);
        const a: u8 = @truncate((color >> (0 * 8)) & 0xFF);

        return sdl.SDL_Color{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};
// END ENUMS

// BEGIN STRUCTS
const Camera = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = SCREEN_WIDTH,
    h: i32 = SCREEN_HEIGHT,
    dx: i32 = 0,
    dy: i32 = 0,
};

const Music = struct {
    music: *sdl.Mix_Music,
    playing: bool = false,
    paused: bool = false,

    pub fn init(path: [*c]const u8) ?Music {
        if (load(path)) |mm| {
            return Music{
                .music = mm,
            };
        } else {
            std.debug.print("could not find/load music\n", .{});
        }
        return null;
    }
    pub fn deinit(self: *Music) void {
        sdl.Mix_FreeMusic(self.music);
    }

    fn load(path: [*c]const u8) ?*sdl.Mix_Music {
        return sdl.Mix_LoadMUS(path);
    }
    pub fn play(self: *Music) void {
        switch (sdl.Mix_PlayingMusic() == 0) {
            true => {
                _ = sdl.Mix_PlayMusic(self.music, -1);
                self.playing = true;
                return;
            },
            false => {
                if (sdl.Mix_PausedMusic() == 1) _ = sdl.Mix_ResumeMusic();
                self.paused = false;
                return;
            },
        }
    }
    pub fn toggle_pause(self: *Music) void {
        switch (self.playing) {
            true => {
                if (self.paused) {
                    _ = sdl.Mix_ResumeMusic();
                    self.paused = false;
                } else {
                    _ = sdl.Mix_PauseMusic();
                    self.paused = true;
                }
                return;
            },
            false => {
                return;
            },
        }
    }
    pub fn halt(self: *Music) void {
        if (self.playing) _ = sdl.Mix_HaltMusic;
    }
};

const Player = struct {
    x: i32 = (SCREEN_WIDTH / 2) - 80,
    y: i32 = (SCREEN_HEIGHT / 2) - 80,
    w: c_int = 48,
    h: c_int = 64,
    dx: i32 = 0,
    dy: i32 = 0,
    jump_count: u8 = 0,
};

const SoundEffect = struct {
    effect: ?*sdl.Mix_Chunk,
    timestamp: i64,

    pub fn init(path: []const u8) SoundEffect {
        std.debug.print("\ntrying path: {s}\n", .{path});
        return SoundEffect{
            .effect = load(@ptrCast(path)),
            .timestamp = std.time.milliTimestamp(),
        };
    }
    pub fn deinit(self: *SoundEffect) void {
        sdl.Mix_FreeChunk(self.effect);
    }
    fn load(path: [*c]const u8) ?*sdl.Mix_Chunk {
        if (sdl.Mix_LoadWAV(path) == null) {
            std.debug.print("failed:\n {s}\n", .{sdl.Mix_GetError()});
        }
        return sdl.Mix_LoadWAV(path);
    }

    pub fn play(self: *SoundEffect) void {
        _ = sdl.Mix_PlayChannel(-1, self.effect, 0);
    }
};

const Vec2 = struct {
    x: i32,
    y: i32,
    mag: i32 = 0,

    fn normal_vec(self: *Vec2) Vec2 {
        return Vec2{
            .x = @divFloor(self.x, self.mag),
            .y = @divFloor(self.x, self.mag),
        };
    }
};
// END STRUCTS

// BEGIN CONSTANTS
const FPS = 60;
const FRAME_DELAY = 1000 / FPS;
const FRAME_AVG_COUNT = 10;
const BACKGROUND_COLOR = Color.dark_gray;
const SCREEN_WIDTH = 1920;
const SCREEN_HEIGHT = 1080;
const TILE_WIDTH = 32;
const TILE_HEIGHT = 32;

// DRAW OFFSET CONSTANTS
const FLOOR_X_OFFSET = 0;
const FLOOR_Y_OFFSET = 0;
const SURFACE_X_OFFSET = 32;
const SURFACE_Y_OFFSET = 0;
const WALL_X_OFFSET = 32 * 2;
const WALL_Y_OFFSET = 0;
const PORTAL_X_OFFSET = 0;
const PORTAL_Y_OFFSET = 32;
const SPAWNER_X_OFFSET = 32;
const SPAWNER_Y_OFFSET = 32;
const PLAYER_X_OFFSET = 0;
const PLAYER_Y_OFFSET = 32 * 2;
const FINISH_X_OFFSET = 32 * 2;
const FINISH_Y_OFFSET = 32;

// END CONSTANTS

//BEGIN FUNCTIONS
fn collide(rect_a: *const sdl.SDL_Rect, rect_b: *const sdl.SDL_Rect) bool {
    return sdl.SDL_HasIntersection(rect_a, rect_b) != 0;
}

fn direct_cam_toward_player(player: *Player, cam: *Camera, tmap: *map.Tilemap) void {
    const min_x = 0;
    const min_y = 0;

    const xmid = @divFloor(cam.w, 2);
    const ymid = @divFloor(cam.h, 2);

    const max_x = @as(i32, @intCast(tmap.map[0][tmap.map[0].len - 1].x + TILE_WIDTH)) - cam.w;
    const max_y = @as(i32, @intCast(tmap.map[tmap.map.len - 1][0].y + TILE_HEIGHT)) - cam.h;

    const dx = @divFloor((player.x + player.w) - (cam.x + xmid), 10);
    const dy = @divFloor((player.y + player.h) - (cam.y + ymid), 10);

    if (dx > 0) {
        cam.dx = if (cam.x + dx > max_x) 0 else dx;
    } else {
        cam.dx = if (cam.x + dx < min_x) 0 else dx;
    }
    if (dy > 0) {
        cam.dy = if (cam.y + dy < max_y) dy else 0;
    } else {
        cam.dy = if (cam.y + dy > min_y) dy else 0;
    }
}

fn fps(avg_arr: []u32) u32 {
    var frames: u32 = 0;
    for (avg_arr) |time| {
        frames += time;
    }
    return frames / @as(u32, @intCast(avg_arr.len));
}

fn place_at_pos(x: u32, y: u32, tilemap: *map.Tilemap, id: map.TileID) void {
    tilemap.edit_tile(id, x / (TILE_WIDTH), y / (TILE_HEIGHT));
}

fn save(tm: *map.Tilemap, allocator: std.mem.Allocator) !void {
    try tm.save(allocator);
}

fn set_fullscreen(window: *sdl.SDL_Window, fullscreen_type: u32) void {
    switch (fullscreen_type) {
        0 => {
            _ = sdl.SDL_SetWindowFullscreen(window, 0);
        },
        1 => {
            _ = sdl.SDL_SetWindowFullscreen(window, sdl.SDL_SCREEN_FULLSCREEN);
        },
        2 => {
            _ = sdl.SDL_SetWindowFullscreen(window, sdl.SDL_SCREEN_FULLSCREEN_DESKTOP);
        },
        else => {},
    }
}

fn set_render_color(renderer: *sdl.SDL_Renderer, color: Color) void {
    const col = Color.make_sdl_color(color);
    _ = sdl.SDL_SetRenderDrawColor(renderer, col.r, col.g, col.b, col.a);
}
// END FUNCTIONS

pub fn main() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        sdl.SDL_Log("Unable to initialize SDL: {s}\n", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    if (sdl.TTF_Init() < 0) {
        sdl.SDL_Log("Unable to initialize SDL_TTF: {s}\n", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    var window: *sdl.SDL_Window = sdl.SDL_CreateWindow("2d-Roguelike", sdl.SDL_WINDOWPOS_CENTERED, sdl.SDL_WINDOWPOS_CENTERED, SCREEN_WIDTH, SCREEN_HEIGHT, 0) orelse {
        sdl.SDL_Log("Unable to initialize SDL: {s}\n", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    var renderer: *sdl.SDL_Renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse {
        sdl.SDL_Log("Unable to initialize SDL: {s}\n", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    if (sdl.Mix_OpenAudio(44100, sdl.MIX_DEFAULT_FORMAT, 8, 2048) < 0) {
        sdl.SDL_Log("SDL_mixer could not initialize! SDL_mixer Error: %s\n", sdl.Mix_GetError());
    }

    var music: ?Music = Music.init("assets/music/8_Bit_Nostalgia.mp3");
    defer if (music != null) music.?.deinit();
    if (music != null) {
        music.?.play();
        music.?.toggle_pause();
    }

    defer sdl.SDL_Quit();
    defer sdl.TTF_Quit();
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);
    defer sdl.Mix_Quit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const map_path = if (args.len > 1) args[1] else "assets/maps/new_map.map";

    var player = Player{};

    var tmap = try map.Tilemap.init(
        alloc,
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        TILE_WIDTH,
        TILE_HEIGHT,
        map_path,
    );
    var player_max_x = tmap.map[0][tmap.map[0].len - 1].x + TILE_WIDTH;
    var player_max_y = tmap.map[tmap.map.len - 1][0].y + TILE_HEIGHT;

    const texmap = sdl.IMG_LoadTexture(renderer, "assets/textures/texmap.png");
    defer sdl.SDL_DestroyTexture(texmap);

    var camera = Camera{};

    var player_spawned = false;
    var frame_start: u32 = undefined;
    var frame_time: u32 = undefined;
    var frame_avg = std.mem.zeroes([FRAME_AVG_COUNT]u32);
    var frame_avg_idx: usize = 0;
    var portal_timeout: i64 = std.time.milliTimestamp();

    var draw_offset: Vec2 = Vec2{ .x = 0, .y = 0 };
    var map_edit_enabled: bool = false;

    var left_mouse_is_down: bool = false;
    var tile_id_selected: map.TileID = @enumFromInt(0);

    var prev_time: i64 = std.time.milliTimestamp();
    var source_offset: c_int = 0;

    var debug_view = false;
    var quit = false;

    while (!quit) {
        frame_start = sdl.SDL_GetTicks();
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                sdl.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    'q' => {
                        quit = true;
                    },
                    'm' => music.?.toggle_pause(),
                    'a' => player.dx = -8,
                    'd' => player.dx = 8,
                    's' => {
                        if (map_edit_enabled) {
                            if (event.key.keysym.mod & sdl.KMOD_CTRL != 0) {
                                var t = try std.Thread.spawn(.{}, save, .{ &tmap, alloc });
                                t.detach();
                            }
                        }
                    },
                    ' ' => {
                        switch (player.jump_count) {
                            0 => {
                                player.dy = -20;
                                player.jump_count += 1;
                            },
                            1 => {
                                player.dy = -15;
                                player.jump_count += 1;
                            },
                            else => {},
                        }
                    },
                    'e' => map_edit_enabled = !map_edit_enabled,
                    'r' => player_spawned = false,
                    '0' => tile_id_selected = @enumFromInt(0),
                    '1' => tile_id_selected = @enumFromInt(1),
                    '2' => tile_id_selected = @enumFromInt(2),
                    '3' => tile_id_selected = @enumFromInt(3),
                    '4' => tile_id_selected = @enumFromInt(4),
                    '5' => tile_id_selected = @enumFromInt(5),
                    sdl.SDLK_F3 => debug_view = !debug_view,
                    else => {},
                },
                sdl.SDL_KEYUP => switch (event.key.keysym.sym) {
                    'a', 'd' => player.dx = 0,
                    else => {},
                },
                sdl.SDL_MOUSEBUTTONDOWN => switch (event.button.button) {
                    sdl.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = true;
                        const x = if (event.button.x + camera.x > 0) @as(u32, @intCast(event.button.x + camera.x)) else 0;
                        const y = if (event.button.y + camera.y > 0) @as(u32, @intCast(event.button.y + camera.y)) else 0;
                        if (map_edit_enabled) place_at_pos(x, y, &tmap, tile_id_selected);
                    },
                    else => {},
                },
                sdl.SDL_MOUSEBUTTONUP => switch (event.button.button) {
                    sdl.SDL_BUTTON_LEFT => {
                        left_mouse_is_down = false;
                    },
                    else => {},
                },
                sdl.SDL_MOUSEMOTION => switch (left_mouse_is_down) {
                    true => {
                        const x = if (event.button.x + camera.x > 0) @as(u32, @intCast(event.button.x + camera.x)) else 0;
                        const y = if (event.button.y + camera.y > 0) @as(u32, @intCast(event.button.y + camera.y)) else 0;
                        if (map_edit_enabled) place_at_pos(x, y, &tmap, tile_id_selected);
                    },
                    false => {},
                },
                sdl.SDL_MOUSEWHEEL => {
                    if (map_edit_enabled) camera.dx = if (event.wheel.x > 0) 20 else if (event.wheel.x < 0) -20 else 0;
                    if (map_edit_enabled) camera.dy = if (event.wheel.y > 0) -20 else if (event.wheel.y < 0) 20 else 0;
                },
                else => {},
            }
        }

        // do stuff
        if (!player_spawned) {
            for (tmap.map) |row| {
                for (row) |tile| {
                    switch (tile.id) {
                        .SpawnPoint => {
                            player.x = tile.x;
                            player.y = tile.y - player.h;
                            player_spawned = true;
                        },
                        else => {},
                    }
                }
            }
        }

        const starty: usize = if (player.y - player.h + player.dy < 0 or player.y > player_max_y) 0 else @intCast(@divTrunc(player.y - player.h + player.dy, TILE_HEIGHT));
        const endy: usize = if (player.y + player.h + player.dy < 0 or player.y > player_max_y) @intCast(@divTrunc(player_max_y, TILE_HEIGHT)) else @intCast(@divTrunc(player.y + player.h + player.dy + TILE_HEIGHT, TILE_HEIGHT));
        for (starty..endy) |i| {
            const row = tmap.map[i];
            const startx: usize = if (player.x - player.w + player.dx < 0 or player.x > player_max_x) 0 else @intCast(@divTrunc(player.x - player.w + player.dx, TILE_WIDTH));
            const endx: usize = if (player.x + player.w + player.dx < 0 or player.x > player_max_x) @intCast(@divTrunc(player_max_x + player.dx, TILE_WIDTH)) else @intCast(@divTrunc(player.x + player.w + player.dx + TILE_WIDTH, TILE_WIDTH));
            for (startx..endx) |j| {
                const tile = row[j];
                switch (tile.collides) {
                    true => {
                        switch (tile.id) {
                            .Floor, .FloorSurface => {
                                if (collide(&sdl.SDL_Rect{
                                    .x = player.x,
                                    .y = player.y + player.dy,
                                    .w = player.w,
                                    .h = player.h,
                                }, &sdl.SDL_Rect{
                                    .x = tile.x,
                                    .y = tile.y,
                                    .w = tile.w,
                                    .h = tile.h,
                                })) {
                                    player.y += @divFloor(player.dy, 2) * -1;
                                    player.dy = @divFloor(player.dy, 2);
                                    player.jump_count = 0;
                                }
                                if (collide(&sdl.SDL_Rect{
                                    .x = player.x + player.dx,
                                    .y = player.y,
                                    .w = player.w,
                                    .h = player.h,
                                }, &sdl.SDL_Rect{
                                    .x = tile.x,
                                    .y = tile.y,
                                    .w = tile.w,
                                    .h = tile.h,
                                })) {
                                    player.x -= @divFloor(player.dx, 2);
                                    player.jump_count = 1;
                                }
                            },
                            .BluePortal => {
                                if (std.time.milliTimestamp() - portal_timeout > 1000) {
                                    for (tmap.portals) |p| {
                                        if (collide(&sdl.SDL_Rect{
                                            .x = player.x + player.dx,
                                            .y = player.y + player.dy,
                                            .w = player.w,
                                            .h = player.h,
                                        }, &sdl.SDL_Rect{
                                            .x = p.x,
                                            .y = p.y,
                                            .w = p.w,
                                            .h = p.h,
                                        })) {
                                            if (p.link) |endpoint| {
                                                std.debug.print("tp to ({d}, {d})\n", .{ endpoint.x, endpoint.y });
                                                player.dy = 0;
                                                player.x = endpoint.x + player.w;
                                                player.y = endpoint.y - 20;
                                                portal_timeout = std.time.milliTimestamp();
                                            } else {
                                                std.debug.print("no endpoint to tp to :(\n", .{});
                                            }
                                        }
                                    }
                                }
                            },
                            .FinishLine => {
                                std.debug.print("player completed level\n", .{});
                            },
                            else => {},
                        }
                    },
                    false => {},
                }
            }
        }

        if (player.x + player.dx < 0 or player.x + player.w + player.dx > tmap.map[0].len) player.x -= @divFloor(player.dx, 2);

        if (!map_edit_enabled) {
            player.x += player.dx;
            player.y += player.dy;
            player.dy += 1;
        }

        switch (map_edit_enabled) {
            true => {
                camera.x += camera.dx;
                if (camera.y + camera.dy + camera.h + TILE_HEIGHT + TILE_HEIGHT / 2 < tmap.map.len * TILE_HEIGHT) camera.y += camera.dy;
                camera.dy += if (camera.dy > 0) -1 else if (camera.dy < 0) 1 else 0;
                camera.dx += if (camera.dx > 0) -1 else if (camera.dx < 0) 1 else 0;
            },
            false => {
                camera.x += camera.dx;
                camera.y += camera.dy;
            },
        }

        // no more doing, just draw
        set_render_color(renderer, Color.dark_gray);
        _ = sdl.SDL_RenderClear(renderer);

        if (!map_edit_enabled) direct_cam_toward_player(&player, &camera, &tmap);

        for (tmap.map) |row| {
            for (row) |tile| {
                const x_to_cam = tile.x - camera.x;
                const y_to_cam = tile.y - camera.y;
                if (x_to_cam + TILE_WIDTH > 0 and x_to_cam < camera.x + camera.w and y_to_cam + TILE_HEIGHT > 0 and y_to_cam < camera.y + camera.h) {
                    switch (tile.id) {
                        .Wall => {
                            draw_offset.x = WALL_X_OFFSET;
                            draw_offset.y = WALL_Y_OFFSET;
                        },
                        .Floor => {
                            draw_offset.x = FLOOR_X_OFFSET;
                            draw_offset.y = FLOOR_Y_OFFSET;
                        },
                        .SpawnPoint => {
                            draw_offset.x = SPAWNER_X_OFFSET;
                            draw_offset.y = SPAWNER_Y_OFFSET;
                        },
                        .BluePortal => {
                            draw_offset.x = WALL_X_OFFSET;
                            draw_offset.y = WALL_Y_OFFSET;
                            _ = sdl.SDL_RenderCopy(
                                renderer,
                                texmap,
                                &sdl.SDL_Rect{
                                    .x = draw_offset.x,
                                    .y = draw_offset.y,
                                    .w = 32,
                                    .h = 32,
                                },
                                &sdl.SDL_Rect{
                                    .x = @intCast(x_to_cam),
                                    .y = @intCast(y_to_cam),
                                    .w = tile.w,
                                    .h = tile.h,
                                },
                            );
                            draw_offset.x = PORTAL_X_OFFSET;
                            draw_offset.y = PORTAL_Y_OFFSET;
                        },
                        .FinishLine => {
                            draw_offset.x = WALL_X_OFFSET;
                            draw_offset.y = WALL_Y_OFFSET;
                            _ = sdl.SDL_RenderCopy(
                                renderer,
                                texmap,
                                &sdl.SDL_Rect{
                                    .x = draw_offset.x,
                                    .y = draw_offset.y,
                                    .w = 32,
                                    .h = 32,
                                },
                                &sdl.SDL_Rect{
                                    .x = @intCast(x_to_cam),
                                    .y = @intCast(y_to_cam),
                                    .w = tile.w,
                                    .h = tile.h,
                                },
                            );
                            draw_offset.x = FINISH_X_OFFSET;
                            draw_offset.y = FINISH_Y_OFFSET;
                        },
                        .FloorSurface => {
                            draw_offset.x = SURFACE_X_OFFSET;
                            draw_offset.y = SURFACE_Y_OFFSET;
                        },
                    }
                    _ = sdl.SDL_RenderCopy(
                        renderer,
                        texmap,
                        &sdl.SDL_Rect{
                            .x = draw_offset.x,
                            .y = draw_offset.y,
                            .w = 32,
                            .h = 32,
                        },
                        &sdl.SDL_Rect{
                            .x = @intCast(x_to_cam),
                            .y = @intCast(y_to_cam),
                            .w = tile.w,
                            .h = tile.h,
                        },
                    );
                    if (debug_view) {
                        set_render_color(renderer, Color.green);
                        _ = sdl.SDL_RenderDrawRect(
                            renderer,
                            &sdl.SDL_Rect{
                                .x = @intCast(x_to_cam),
                                .y = @intCast(y_to_cam),
                                .w = tile.w,
                                .h = tile.h,
                            },
                        );
                    }
                }
            }
        }

        if (player.dx != 0) {
            const new_time = std.time.milliTimestamp();
            if (new_time - prev_time > 200) {
                source_offset = if (source_offset == 0) 32 else 0;
                prev_time = new_time;
            }
        } else source_offset = 0;
        const flip: c_uint = if (player.dx < 0) sdl.SDL_FLIP_HORIZONTAL else sdl.SDL_FLIP_NONE;
        _ = sdl.SDL_RenderCopyEx(
            renderer,
            texmap,
            &sdl.SDL_Rect{
                .x = PLAYER_X_OFFSET + source_offset,
                .y = PLAYER_Y_OFFSET,
                .w = 24,
                .h = 31,
            },
            &sdl.SDL_Rect{
                .x = @intCast(player.x - camera.x),
                .y = @intCast(player.y - camera.y),
                .w = player.w,
                .h = player.h,
            },
            0,
            null,
            flip,
        );
        set_render_color(renderer, Color.white);
        if (debug_view) {
            _ = sdl.SDL_RenderDrawRect(
                renderer,
                &sdl.SDL_Rect{
                    .x = @intCast(player.x - camera.x),
                    .y = @intCast(player.y - camera.y),
                    .w = player.w,
                    .h = player.h,
                },
            );
        }

        sdl.SDL_RenderPresent(renderer);

        if (frame_avg_idx == FRAME_AVG_COUNT) {
            frame_avg_idx = 0;
            //std.debug.print("fps: {d}\n", .{fps(&frame_avg)});
        } else {
            frame_avg[frame_avg_idx] = if (frame_time > 0) 1000 / frame_time else 0;
            frame_avg_idx += 1;
        }
        frame_time = sdl.SDL_GetTicks() - frame_start;

        if (FRAME_DELAY > frame_time) sdl.SDL_Delay(FRAME_DELAY - frame_time);
    }
}
