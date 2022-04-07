package(default_visibility = ["//visibility:public"])

# config_setting(s):
# Example:
# > bazel build :target
# > bazel build :target --//tools/bzl:sv_sim=verilator_debug

# I'm not really sure a config_setting is the way to go
# here, b/c the simulator choice, or technology and tooling should
# ultimately be project specific set by a .bzl and BUILD of their
# own. I'd rather they set those defaults, and then we plumb these
# settings through.

load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

# The default value of sv_sim is "verilator"
string_flag(
    name = "sv_sim",
    build_setting_default = "verilator"
)

config_setting(
    name = "cfg_verilator",
    flag_values = {":sv_sim": "verilator"},
)

# This is a test to see if we can pass an opaque config_setting
# to all the native rules and get what we want.
config_setting(
    name = "cfg_verilator_debug",
    flag_values = {":sv_sim": "verilator_debug"},
)
