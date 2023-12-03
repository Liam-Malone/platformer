const std = @import("std");
const graphics = @import("graphics.zig");
const c = @import("c.zig");

const Allocator = std.mem.Allocator;

pub const Tilemap = struct {
    const Tile = struct {
        id: i32,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        //tex: ?*c.SDL_Texture,
        hb_color: graphics.Color = graphics.Color.white,
        tex: graphics.Color = graphics.Color.dark_gray,

        pub fn init(x: i32, y: i32, w: i32, h: i32, id: i32) Tile {
            return Tile{
                .x = x,
                .y = y,
                .w = w,
                .h = h,
                .id = id,
            };
        }

        pub fn draw(self: *const Tile, window: *graphics.Window) void {
            // draw tile
            window.set_render_color(self.tex);
            window.fill_rect(c.SDL_Rect{
                .x = @intCast(self.x),
                .y = @intCast(self.y),
                .w = @intCast(self.w),
                .h = @intCast(self.h),
            });
            // draw tile outline
            window.set_render_color(self.hb_color);
            window.draw_rect(c.SDL_Rect{
                .x = @intCast(self.x),
                .y = @intCast(self.y),
                .w = @intCast(self.w),
                .h = @intCast(self.h),
            });
        }
        pub fn update_id_and_color(self: *Tile, id: i32) void {
            self.id = id;
            self.tex = switch (id) {
                0 => graphics.Color.white,
                1 => graphics.Color.blue,
                else => graphics.Color.void,
            };
        }
    };

    tiles: [][]Tile,
    w: u32,
    h: u32,

    // for now create new tilemap, later load one in
    pub fn init(allocator: Allocator, w: u32, h: u32, tile_w: i32, tile_h: i32) !Tilemap {
        const tiles_across = w / @as(u32, @intCast(tile_w));
        const tiles_down = h / @as(u32, @intCast(tile_h));
        var map = try build_map(allocator, @intCast(tiles_across), @intCast(tiles_down), tile_w, tile_h);
        return Tilemap{
            .tiles = map,
            .w = w,
            .h = h,
        };
    }

    fn build_map(allocator: Allocator, tiles_down: i32, tiles_across: usize, tile_w: i32, tile_h: i32) ![][]Tile {
        var tmp = std.ArrayList([]Tile).init(allocator);

        for (0..@intCast(tiles_across)) |y| {
            var row = std.ArrayList(Tile).init(allocator);
            for (0..@intCast(tiles_down)) |x| {
                const xpos = @as(i32, @intCast(x)) * tile_w;
                const ypos = @as(i32, @intCast(y)) * tile_h;
                try row.append(Tile.init(xpos, ypos, tile_w, tile_h, 0));
            }
            try tmp.append(try row.toOwnedSlice());
        }
        return try tmp.toOwnedSlice();
    }

    fn export_to_file(self: *Tilemap, file_out: []const u8) !void {
        var file = std.fs.cwd().openFile(
            file_out,
            .{ .mode = std.fs.File.OpenMode.write_only },
        ) catch try std.fs.cwd().createFile(file_out, .{});
        defer file.close();
        for (self.tiles) |row| {
            for (row) |tile| {
                _ = try file.write(tile.id);
                _ = try file.write(" ");
            }
            _ = try file.write("\n");
        }
        const stdout = std.io.getStdOut().writer();
        try stdout.print("File export completed\n", .{});
    }

    pub fn edit_tile(self: *Tilemap, id: i32, x: u32, y: u32) void {
        if (y >= self.tiles.len or x >= self.tiles[0].len) return;
        self.tiles[y][x].update_id_and_color(id);
    }

    pub fn draw(self: *Tilemap, window: *graphics.Window) void {
        for (self.tiles) |row| {
            for (row) |tile| {
                tile.draw(window);
            }
        }
    }
};
