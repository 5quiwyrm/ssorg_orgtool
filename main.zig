const std = @import("std");
const print = std.debug.print;
const fs = std.fs;
const json = std.json;
const TOOBIG = 2e7;
const SHOWNUM = 20;
const allocator = std.heap.page_allocator;
const task = @import("taskobj.zig");
const arraylist = std.ArrayList;
const clib = @cImport({
    @cInclude("stdlib.h");
});

pub fn main() !void {
    const exepath = try fs.selfExeDirPathAlloc(allocator);
    const orgfile = try (try fs.openDirAbsolute(exepath, .{})).openFile("org.ssorg", .{ .mode = .read_write });
    defer orgfile.close();

    const orgraw = try orgfile.readToEndAlloc(allocator, TOOBIG);
    defer allocator.free(orgraw);
    try orgfile.seekTo(0);
    var orgrawsplit = std.mem.splitSequence(u8, orgraw, "\n");
    var orglist = arraylist(task.taskobjM).init(allocator);
    defer orglist.deinit();

    while (orgrawsplit.next()) |org| {
        // print("{s}\n", .{org});
        if (org.len < 2) break;
        var x = try json.parseFromSlice(task.taskobj, allocator, org, .{});
        _ = try orglist.append(try x.value.totaskobjM());
    }

    const currtime: i64 = @divFloor(std.time.timestamp(), 86400);

    var argiter = try std.process.argsWithAllocator(allocator);
    defer argiter.deinit();
    _ = argiter.next();

    if (argiter.next()) |arg1| {
        switch (arg1[0]) {
            'b' => {
                var i: i64 = 0;
                var n: i64 = 0;
                prnt: for (orglist.items) |*org| {
                    i += try org.*.print(currtime, n, 0, .{ .brief = true });
                    n += 1;
                    if (i > SHOWNUM) break :prnt;
                }
            },
            'a' => {
                var i: i64 = 0;
                var n: i64 = 0;
                prnt: for (orglist.items) |*org| {
                    i += try org.*.print(currtime, n, 0, .{ .showcompl = true, .showabort = true });
                    n += 1;
                    if (i > SHOWNUM) break :prnt;
                }
            },
            's' => {
                if (argiter.next()) |arg2| {
                    var showuncom: bool = false;
                    var showcompl: bool = false;
                    var showprogr: bool = false;
                    var showabort: bool = false;
                    for (arg2) |itm| {
                        showuncom = showuncom or (itm == 'u');
                        showcompl = showcompl or (itm == 'c');
                        showprogr = showprogr or (itm == 'p');
                        showabort = showabort or (itm == 'a');
                    }
                    var i: i64 = 0;
                    var n: i64 = 0;
                    prnt: for (orglist.items) |*org| {
                        i += try org.*.print(currtime, n, 0, .{ .showuncom = showuncom, .showcompl = showcompl, .showprogr = showprogr, .showabort = showabort });
                        n += 1;
                        if (i > SHOWNUM) break :prnt;
                    }
                } else {
                    print("Please supply fields to show (e.g. c for completed, ca for completed and aborted)", .{});
                    return;
                }
            },
            'm' => {
                const arg2: ?[:0]const u8 = argiter.next();
                var trace: ?*task.taskobjM = null;
                if (arg2 == null) {
                    trace = &orglist.items[0];
                } else {
                    for (arg2.?) |ch| {
                        const iden = task.identoorgnum(ch);
                        if (trace == null) {
                            if (iden < orglist.items.len) {
                                trace = &orglist.items[iden];
                            } else {
                                print("Not found!", .{});
                                return;
                            }
                        } else {
                            if (iden < trace.?.subtasks.items.len) {
                                trace = &trace.?.*.subtasks.items[iden];
                            } else {
                                print("Not found!", .{});
                                return;
                            }
                        }
                    }
                }
                if (arg1.len == 1) {
                    trace.?.*.complete();
                } else {
                    switch (arg1[1]) {
                        'u' => trace.?.*.reprise(),
                        'c' => trace.?.*.complete(),
                        'p' => trace.?.*.progress(),
                        'a' => trace.?.*.abort(),
                        else => trace.?.*.complete(),
                    }
                }
            },
            't' => {
                const addorgfile = try fs.cwd().createFile("newfile.ssorg", .{ .read = true });

                var addstri = arraylist(u8).init(allocator);
                var subs = arraylist(task.taskobj).init(allocator);
                defer subs.deinit();
                try json.stringify(task.taskobj{ .setdate = currtime, .duedate = currtime, .title = "", .status = 0, .tags = 0, .subtasks = try subs.toOwnedSlice() }, .{}, addstri.writer());
                try addorgfile.writeAll(try addstri.toOwnedSlice());
                addstri.deinit();
                _ = clib.system("hx newfile.ssorg");
                var inpt: [3]u8 = undefined;
                _ = try std.io.getStdIn().reader().readUntilDelimiter(&inpt, '\n');

                addorgfile.close();

                const addorgreadfile = try fs.cwd().openFile("newfile.ssorg", .{});
                const addorgreadraw = try addorgreadfile.readToEndAlloc(allocator, TOOBIG);
                const arg2: ?[:0]const u8 = argiter.next();
                var trace: ?*arraylist(task.taskobjM) = null;
                if (arg2 == null) {
                    trace = &orglist;
                } else {
                    for (arg2.?) |ch| {
                        const iden = task.identoorgnum(ch);
                        if (trace == null) {
                            if (iden < orglist.items.len) {
                                trace = &orglist.items[iden].subtasks;
                            } else {
                                print("Not found!", .{});
                                return;
                            }
                        } else {
                            if (iden < trace.?.items.len) {
                                trace = &trace.?.*.items[iden].subtasks;
                            } else {
                                print("Not found!", .{});
                                return;
                            }
                        }
                    }
                }
                var x = try json.parseFromSlice(task.taskobj, allocator, addorgreadraw, .{});
                _ = try trace.?.*.append(try x.value.totaskobjM());
                addorgreadfile.close();
                try fs.cwd().deleteFile("newfile.ssorg");
            },
            'd' => {
                const arg2: ?[:0]const u8 = argiter.next();
                var trace: ?*arraylist(task.taskobjM) = null;
                if (arg2 == null) {
                    print("Please provide an index for removal!", .{});
                    return;
                } else if (arg2.?.len == 1) {
                    trace = &orglist;
                } else {
                    for (arg2.?[0..(arg2.?.len - 1)]) |ch| {
                        const iden = task.identoorgnum(ch);
                        if (trace == null) {
                            if (iden < orglist.items.len) {
                                trace = &orglist.items[iden].subtasks;
                            } else {
                                print("Not found!", .{});
                                return;
                            }
                        } else {
                            if (iden < trace.?.items.len) {
                                trace = &trace.?.*.items[iden].subtasks;
                            } else {
                                print("Not found!", .{});
                                return;
                            }
                        }
                    }
                }
                _ = trace.?.*.orderedRemove(task.identoorgnum(arg2.?[arg2.?.len - 1]));
            },
            'f' => {
                var i: i64 = 0;
                var n: i64 = 0;
                prnt: for (orglist.items) |*org| {
                    i += try org.*.print(currtime, n, 0, .{ .onlyasap = true }); // if it is 1 then its printed
                    n += 1;
                    if (i > SHOWNUM) break :prnt;
                }
            },
            else => {},
        }
    } else {
        var i: i64 = 0;
        var n: i64 = 0;
        prnt: for (orglist.items) |*org| {
            i += try org.*.print(currtime, n, 0, .{}); // if it is 1 then its printed
            n += 1;
            if (i > SHOWNUM) break :prnt;
        }
    }

    var stri = arraylist(u8).init(allocator);
    defer stri.deinit();
    const striW = stri.writer();

    for (orglist.items) |*t| {
        try json.stringify(try t.*.totaskobj(), .{}, striW);
        try stri.append('\n');
    }

    const neworgfile = try (try fs.openDirAbsolute(exepath, .{})).createFile("org.ssorg", .{});
    defer neworgfile.close();
    try neworgfile.writer().writeAll(try stri.toOwnedSlice());
}
