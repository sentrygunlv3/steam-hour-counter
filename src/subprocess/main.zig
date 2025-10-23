const std = @import("std");

pub fn main() !void {
	var steam_api = try std.DynLib.open("./libsteam_api.so");
	defer steam_api.close();

	const SteamAPI_Init = steam_api.lookup(*const fn () callconv(.c) bool, "SteamAPI_Init") orelse return;

	_ = SteamAPI_Init();

	while (true) {
		std.Thread.sleep(std.time.ms_per_hour);
	}
}
