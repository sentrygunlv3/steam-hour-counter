const std = @import("std");
const l = std.log;

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	const exe_path = try std.fs.selfExePathAlloc(allocator);
	defer allocator.free(exe_path);

	var steam_api = try std.DynLib.open("/usr/lib/steam-hour-counter/libsteam_api.so");
	defer steam_api.close();

	const SteamAPI_Init = steam_api.lookup(*const fn () callconv(.c) bool, "SteamAPI_Init") orelse return;

	if (!SteamAPI_Init()) {
		while (true) {
			l.warn("failed to init steam api, make sure steam is running", .{});
			std.Thread.sleep(3 * std.time.ms_per_min);
			if (SteamAPI_Init()) {
				break;
			}
		}
	}

	while (true) {
		std.Thread.sleep(std.time.ms_per_hour);
	}
}
