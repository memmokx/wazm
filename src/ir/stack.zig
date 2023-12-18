const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Stack(comptime T: type) type {
    return struct {
        pub const Node = struct {
            data: T,
            next: ?*Node,

            pub fn init(data: T, allocator: Allocator) !*Node {
                var n = try allocator.create(Node);

                n.* = .{
                    .data = data,
                    .next = null,
                };

                return n;
            }
        };

        const Self = @This();

        allocator: Allocator,
        top: ?*Node = null,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
            };
        }

        pub fn push(self: *Self, data: T) !void {
            var tmp: ?*Node = null;

            tmp = self.top;
            self.top = try Node.init(data, self.allocator);
            self.top.?.next = tmp;
        }

        pub fn pop(self: *Self) !?T {
            var data: ?T = null;
            var tmp: ?*Node = null;

            if (self.top) |top| {
                data = top.data;
                tmp = top.next;
                self.allocator.destroy(top);
            }

            self.top = tmp;
            return data;
        }

        pub fn print(self: Self) void {
            var tmp: ?*Node = self.top;
            while (tmp != null) : (tmp = tmp.?.next) {
                std.debug.print("stack: {}\n", .{tmp.?.data});
            }
        }
    };
}
