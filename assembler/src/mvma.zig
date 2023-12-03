const std = @import("std");

pub const MvmaSource = struct {
    allocator: std.mem.Allocator,
    reader: std.fs.File.Reader,
    position: usize = 0,
    column: usize = 0,
    line: usize = 0,
    nextByte: ?u8 = null,

    pub const FilePosition = struct { line: usize, column: usize };

    pub fn peekNext(self: *MvmaSource) ?u8 {
        if (self.nextByte) |nextByte| return nextByte;

        const nextByte = self.reader.readByte() catch return null;
        self.nextByte = nextByte;
        return nextByte;
    }

    fn incrementPosition(self: *MvmaSource, newChar: u8) void {
        if (newChar == '\n') {
            self.line += 1;
            self.column = 0;
        } else {
            self.column += 1;
        }
        self.position += 1;
    }

    pub fn consumeNext(self: *MvmaSource) ?u8 {
        if (self.nextByte) |nextByte| {
            self.incrementPosition(nextByte);
            self.nextByte = null;
            return nextByte;
        }
        const nextByte = self.reader.readByte() catch return null;
        self.incrementPosition(nextByte);
        return nextByte;
    }

    pub fn consumeUntil(self: *MvmaSource, delimiter: u8) std.ArrayList(u8) {
        // self.reader.streamUntilDelimiter(string.writer(), delimiter, null) catch {};
        // self.position += string.items.len;
        var string = std.ArrayList(u8).init(self.allocator);
        while (self.consumeNext()) |char| {
            if (char == delimiter) break;
            string.append(char) catch {};
        }
        self.nextByte = null;
        return string;
    }

    pub fn currentPosition(self: *MvmaSource) FilePosition {
        return FilePosition{ .column = self.column + 1, .line = self.line + 1 };
    }
};
