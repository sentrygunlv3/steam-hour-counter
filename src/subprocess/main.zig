const std = @import("std");

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	const exe_path = try std.fs.selfExePathAlloc(allocator);
	defer allocator.free(exe_path);
	
	const dir = std.fs.path.dirname(exe_path).?;

	const lib_path = try std.fs.path.join(allocator, &[_][]const u8{dir, "libsteam_api.so"});
	defer allocator.free(lib_path);

	var steam_api = try std.DynLib.open(lib_path);
	defer steam_api.close();

	const SteamAPI_Init = steam_api.lookup(*const fn () callconv(.c) bool, "SteamAPI_Init") orelse return;

	_ = SteamAPI_Init();

	while (true) {
		std.Thread.sleep(std.time.ms_per_hour);
	}
}
