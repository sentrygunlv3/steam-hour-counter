const std = @import("std");

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
			std.Thread.sleep(10 * std.time.ms_per_min);
			if (SteamAPI_Init()) {
				break;
			}
		}
	}

	while (true) {
		std.Thread.sleep(std.time.ms_per_hour);
	}
}
