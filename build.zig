const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const query = std.Target.Query{ .cpu_arch = .wasm32, .os_tag = .freestanding };
    const target = b.resolveTargetQuery(query);

    const exe = b.addExecutable(.{
        .name = "cart",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
        .error_tracing = true,
        .single_threaded = true,
    });

    exe.entry = .disabled;
    exe.root_module.export_symbol_names = &[_][]const u8{ "start", "update" };
    exe.import_memory = true;
    exe.initial_memory = 65536;
    exe.max_memory = 65536;
    exe.stack_size = 14752;

    // const native_query = std.Target.Query{};
    // const native_target = b.resolveTargetQuery(native_query);

    // const convert = b.addExecutable(.{
    //     .name = "convert",
    //     .root_module = b.createModule(.{ .root_source_file = b.path("convert.zig"), .target = native_target }),
    // });

    // var s = b.addRunArtifact(convert);
    // exe.step.dependOn(&s.step);
    // b.addRunArtifact(exe: *Step.Compile)

    b.installArtifact(exe);

    //const exe_check = bb.addExecutable()
}
