const std = @import("std");
const l = std.log;
const Child = std.process.Child;
const Signal = std.os.linux.SIG;

const qlist = @import("qlist");

var running = true;
var update = true;

var subprocesses: std.StringHashMap(Child) = undefined;

fn signalHandler(signo: i32) callconv(.c) void {
	switch (signo) {
		Signal.INT => {
			cleanup();
			std.process.exit(0);
		},
		Signal.TERM => {
			running = false;
		},
		Signal.HUP => {
			update = true;
		},
		else => {},
	}
}

pub fn main() void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	subprocesses = std.StringHashMap(Child).init(allocator);
	var programs = qlist.QList.init(allocator);

	var env_map = std.process.getEnvMap(allocator) catch |e| {
		l.err("failed to get env map: {}", .{e});
		return;
	};
	defer env_map.deinit();

	const home_dir = env_map.get("HOME") orelse {
		l.err("cant get home dir", .{});
		return;
	};

	var sa = std.os.linux.Sigaction{
		.handler = .{.handler = signalHandler},
		.mask = std.os.linux.sigemptyset(),
		.flags = 0,
	};

	_ = std.os.linux.sigaction(Signal.INT, &sa, null);
	_ = std.os.linux.sigaction(Signal.TERM, &sa, null);
	_ = std.os.linux.sigaction(Signal.HUP, &sa, null);

	while (running) {
		if (update) {
			update = false;
			l.info("reading config...", .{});

			const conf_path = std.fs.path.join(allocator, &[_][]const u8{
				home_dir, ".config", "steam-hour-counter"
			}) catch |e| {
				l.err("failed to join path: {}", .{e});
				return;
			};
			defer allocator.free(conf_path);
	
			qlist.read(&programs, conf_path) catch |e| {
				l.err("failed to read config: {}", .{e});
			};
		}

		var iterator = programs.hm.iterator();
		while (iterator.next()) |item| {
			const proc = Child.run(.{
				.argv = &[_][]const u8{"pgrep", "-x", item.key_ptr.*},
				.allocator = allocator,
			}) catch |e| {
				l.err("failed to pgrep: {}", .{e});
				return;
			};
			defer allocator.free(proc.stdout);
			defer allocator.free(proc.stderr);

			var child = subprocesses.get(item.key_ptr.*);
			if (proc.stdout.len > 0 and child == null) {
				l.info("found {s}", .{item.key_ptr.*});
				
				env_map.put("SteamAppId", item.value_ptr.*.string) catch |e| {
					l.warn("failed to add SteamAppId to env map: {}\nskipping to next program", .{e});
					continue;
				};

				var sub = Child.init(
					&[_][]const u8{"/usr/lib/steam-hour-counter/shc-sub"},
					allocator
				);
				sub.env_map = &env_map;

				Child.spawn(&sub) catch killSub(&sub);
				subprocesses.put(item.key_ptr.*, sub) catch killSub(&sub);

				l.info("started subprocess for {s}", .{item.key_ptr.*});
			} else if (proc.stdout.len < 1 and child != null) {
				killSub(&child.?);
				_ = subprocesses.remove(item.key_ptr.*);
				l.info("killed subprocess for {s}", .{item.key_ptr.*});
			}
		}
		std.Thread.sleep(15 * std.time.ns_per_s);
	}
	cleanup();
}

fn killSub(sub: *Child) void {
	_ = sub.kill() catch |e| {
		l.err("failed to kill subprocess: {}", .{e});
		std.process.exit(1);
	};
}

fn cleanup() void {
	l.info("\nshutting down subprocesses for:", .{});
	var iterator = subprocesses.iterator();
	while (iterator.next()) |item| {
		l.info("- {s}", .{item.key_ptr.*});
		_ = item.value_ptr.kill() catch {};
	}
}
