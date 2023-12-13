const std = @import("std");
const graphics = @import("graphics.zig");
const c = @import("c.zig");

const Allocator = std.mem.Allocator;

pub const Tilemap = struct {
    pub const Tile_ID = enum(u8) {
        Nothing = 0,
        Flooring = 1,
        StationaryPlatform = 2,
        MovingPlatform = 3,
    };
    pub const Tile = struct {
        id: Tile_ID,
        x: i32,
        dx: i32 = 0,
        y: i32,
        dy: i32 = 0,
        w: i32,
        h: i32,
        hb_color: graphics.Color = graphics.Color.white,
        tex: graphics.Color = graphics.Color.dark_gray,

        pub fn init(id: u8, x: i32, y: i32, w: i32, h: i32) Tile {
            std.debug.print("id: {d}, x: {d}, y: {d}\n", .{ id, x, y });
            const tex = switch (id) {
                0 => graphics.Color.dark_gray,
                1 => graphics.Color.white,
                2 => graphics.Color.blue,
                3 => graphics.Color.green,
                else => graphics.Color.void,
            };
            return Tile{
                .id = @enumFromInt(id),
                .x = x,
                .y = y,
                .w = w,
                .h = h,
                .tex = tex,
            };
        }

        pub fn draw(self: *const Tile, window: *graphics.Window, outline: bool) void {
            // draw tile
            window.set_render_color(self.tex);
            window.fill_rect(c.SDL_Rect{
                .x = @intCast(self.x),
                .y = @intCast(self.y),
                .w = @intCast(self.w),
                .h = @intCast(self.h),
            });
            if (!outline) return;
            // draw tile outline
            window.set_render_color(self.hb_color);
            window.draw_rect(c.SDL_Rect{
                .x = @intCast(self.x),
                .y = @intCast(self.y),
                .w = @intCast(self.w),
                .h = @intCast(self.h),
            });
        }
        pub fn update_id_and_color(self: *Tile, id: u8) void {
            self.id = @enumFromInt(id);
            self.tex = switch (id) {
                0 => graphics.Color.dark_gray,
                1 => graphics.Color.white,
                2 => graphics.Color.blue,
                3 => graphics.Color.green,
                else => graphics.Color.void,
            };
        }
    };

    tiles: [][]Tile,
    w: u32,
    h: u32,
    cur: []const u8,

    // for now create new tilemap, later load one in
    pub fn init(allocator: Allocator, w: u32, h: u32, tile_w: i32, tile_h: i32, path: []const u8) !Tilemap {
        const tiles_across = w / @as(u32, @intCast(tile_w));
        const tiles_down = h / @as(u32, @intCast(tile_h));
        var map: [][]Tile = undefined;
        if (path.len < 1) {
            map = try build_map(allocator, @intCast(tiles_across), @intCast(tiles_down), tile_w, tile_h);
        } else {
            map = read_from_file(allocator, path, tile_w, tile_h) catch try build_map(allocator, @intCast(tiles_across), @intCast(tiles_down), tile_w, tile_h);
        }

        return Tilemap{
            .tiles = map,
            .w = w,
            .h = h,
            .cur = path,
        };
    }

    fn build_map(allocator: Allocator, tiles_down: i32, tiles_across: usize, tile_w: i32, tile_h: i32) ![][]Tile {
        var tmp = std.ArrayList([]Tile).init(allocator);

        for (0..@intCast(tiles_across)) |y| {
            var row = std.ArrayList(Tile).init(allocator);
            for (0..@intCast(tiles_down)) |x| {
                const xpos = @as(i32, @intCast(x)) * tile_w;
                const ypos = @as(i32, @intCast(y)) * tile_h;
                try row.append(Tile.init(0, xpos, ypos, tile_w, tile_h));
            }
            try tmp.append(try row.toOwnedSlice());
        }
        return try tmp.toOwnedSlice();
    }

    //*****************************************//
    //                                         //
    //              *** TODO ***               //
    //                                         //
    //  look into using bufstream and reading  //
    //  in int values from the file, instead   //
    //  of current, naïve u8 mem split method  //
    //                                         //
    //*****************************************//

    fn read_from_file(allocator: Allocator, path: []const u8, tile_w: i32, tile_h: i32) ![][]Tile {
        var map = std.ArrayList([]Tile).init(allocator);
        const file = try std.fs.cwd().openFile(path, .{});
        const buf = try allocator.alloc(u8, 4000);
        _ = try file.reader().readAll(buf);
        defer allocator.free(buf);

        var y: i32 = 0;
        var iter_lines = std.mem.split(u8, buf, "\n");
        while (iter_lines.next()) |line| {
            var x: i32 = 0;
            var row = std.ArrayList(Tile).init(allocator);

            var iter_elems = std.mem.split(u8, line, " ");
            while (iter_elems.next()) |elem| {
                if (elem.len > 0) {
                    if (elem[0] > 47 and elem[0] < 58) {
                        try row.append(Tile.init(elem[0] - 48, x * tile_w, y * tile_h, tile_w, tile_h));
                        x += 1;
                    }
                }
            }
            try map.append(try row.toOwnedSlice());
            y += 1;
        }

        return map.toOwnedSlice();
    }

    fn export_to_file(self: *Tilemap, allocator: Allocator, file_out: []const u8) !void {
        var file = std.fs.cwd().openFile(
            file_out,
            .{ .mode = std.fs.File.OpenMode.write_only },
        ) catch try std.fs.cwd().createFile(file_out, .{});
        defer file.close();
        for (self.tiles) |row| {
            for (row) |tile| {
                _ = try file.write(try std.fmt.allocPrint(allocator, "{d} ", .{@intFromEnum(tile.id)}));
            }
            _ = try file.write("\n");
        }
        const stdout = std.io.getStdOut().writer();
        try stdout.print("File export completed\n", .{});
    }

    pub fn save(self: *Tilemap, allocator: Allocator) !void {
        try export_to_file(self, allocator, self.cur);
    }

    pub fn edit_tile(self: *Tilemap, id: u8, x: u32, y: u32) void {
        if (y >= self.tiles.len or x >= self.tiles[0].len) return;
        self.tiles[y][x].update_id_and_color(id);
    }

    pub fn draw(self: *Tilemap, window: *graphics.Window, outline: bool) void {
        for (self.tiles) |row| {
            for (row) |tile| {
                tile.draw(window, outline);
            }
        }
    }
};
