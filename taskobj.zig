const std = @import("std");
const arraylist = std.ArrayList;
pub var allocator = std.heap.page_allocator;
pub const taskerr = error{InvalidTask};
const clibs = @cImport({
    @cInclude("time.h");
});
pub const orgiden = "0123456789abcdefghijklmnopqrstuvwxyz".*;

pub fn identoorgnum(iden: u8) usize {
    return switch (iden) {
        48...57 => iden - 48,
        97...122 => iden - 87,
        else => 0,
    };
}

pub const taskobj = struct {
    setdate: i64,
    duedate: i64,
    title: []u8,
    status: i64,
    tags: i64,
    subtasks: ?[]taskobj,

    pub fn totaskobjM(self: *taskobj) !taskobjM {
        var title = arraylist(u8).init(allocator);
        try title.appendSlice(self.title);
        var subtasks = arraylist(taskobjM).init(allocator);
        if (self.subtasks != null) {
            for (self.subtasks.?) |*t| {
                try subtasks.append(try t.*.totaskobjM());
            }
        }
        return taskobjM{
            .setdate = self.setdate,
            .duedate = self.duedate,
            .title = title,
            .status = self.status,
            .tags = self.tags,
            .subtasks = subtasks,
        };
    }
};

const statusE = [_]*const [11:0]u8{
    "Uncompleted",
    "Completed  ",
    "InProgress ",
    "Aborted    ",
};

const tagsE = [_]*const [5:0]u8{
    "NoTag",
    "Asap ",
};

pub const PrintOptions = struct {
    brief: bool = false,
    showuncom: bool = true,
    showcompl: bool = false,
    showprogr: bool = true,
    showabort: bool = false,
    onlyasap: bool = false,
};

pub const taskobjM = struct {
    setdate: i64,
    duedate: i64,
    title: arraylist(u8),
    status: i64,
    tags: i64,
    subtasks: arraylist(taskobjM),

    pub fn totaskobj(self: *taskobjM) !taskobj {
        const subtasks = try self.subtasks.toOwnedSlice();
        var ret_subtask = arraylist(taskobj).init(allocator);
        for (subtasks) |*t| {
            try ret_subtask.append(try t.*.totaskobj());
        }
        return taskobj{
            .setdate = self.setdate,
            .duedate = self.duedate,
            .title = try self.title.toOwnedSlice(),
            .status = self.status,
            .tags = self.tags,
            .subtasks = try ret_subtask.toOwnedSlice(),
        };
    }

    pub fn print(self: *taskobjM, currtime: i64, orgnum: i64, comptime idnlvl: i64, args: PrintOptions) !u8 {
        // idnlvl should always be set to 0
        if (!args.showuncom and self.status == 0) return 0;
        if (!args.showcompl and self.status == 1) return 0;
        if (!args.showprogr and self.status == 2) return 0;
        if (!args.showabort and self.status == 3) return 0;
        if (args.onlyasap and self.tags != 1) return 0;

        var setdiffbuf = arraylist(u8).init(allocator);
        defer setdiffbuf.deinit();
        try std.fmt.formatInt(self.setdate - currtime, 10, .lower, .{ .width = 4, .alignment = .left }, setdiffbuf.writer());
        var duediffbuf = arraylist(u8).init(allocator);
        defer duediffbuf.deinit();
        try std.fmt.formatInt(self.duedate - currtime, 10, .lower, .{ .width = 4, .alignment = .left }, duediffbuf.writer());
        var ret_str = arraylist(u8).init(allocator);
        defer ret_str.deinit();
        var uncompleted: i64 = 0;
        var done: i64 = 0;
        var inprogress: i64 = 0;
        var aborted: i64 = 0;
        for (self.subtasks.items) |subt| {
            switch (subt.status) {
                0 => uncompleted += 1,
                1 => done += 1,
                2 => inprogress += 1,
                3 => aborted += 1,
                else => unreachable,
            }
        }

        std.debug.print("{s}{c}: {s} | {s} | {s} | {s} | {s} | [U: {}, C: {}, P: {}, A: {}]\n", .{
            "  " ** idnlvl,
            orgiden[@as(usize, @intCast(orgnum))],
            setdiffbuf.items,
            duediffbuf.items,
            statusE[@as(usize, @intCast(self.status))],
            tagsE[@as(usize, @intCast(self.tags))],
            self.title.items,
            uncompleted,
            done,
            inprogress,
            aborted,
        });
        if (idnlvl > 10) return 1;
        if (args.brief) return 1;
        var n: i64 = 0;
        for (self.subtasks.items) |*t| {
            _ = try t.*.print(currtime, n, idnlvl + 1, .{
                .brief = args.brief,
                .showuncom = args.showuncom,
                .showcompl = args.showcompl,
                .showprogr = args.showprogr,
                .showabort = args.showabort,
            });
            n += 1;
        }
        return 1;
    }

    pub fn setstat(self: *taskobjM, status: i64) void {
        self.status = status;
        for (self.subtasks.items) |*t| {
            t.*.setstat(status);
        }
    }

    pub fn reprise(self: *taskobjM) void {
        self.setstat(0);
    }
    pub fn complete(self: *taskobjM) void {
        self.setstat(1);
    }
    pub fn progress(self: *taskobjM) void {
        self.setstat(2);
    }
    pub fn abort(self: *taskobjM) void {
        self.setstat(3);
    }
};
