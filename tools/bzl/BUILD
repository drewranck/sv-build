package(default_visibility = ["//visibility:public"])

# config_setting(s):
# Example:
# > bazel build :target
# > bazel build :target --//drewvm/bzl:sv_sim=verilator_debug

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


# TODO(drew.ranck): temp -- consider removing the tech/node/tool here
# These might make more sense to be project specific. Why? I don't really
# feel like having to run bazel as:
#
# > bazel build :target --//bzl:tech_vendor=foo --//bzl:tech_node=bar
#
# On every invocation if I'm not using the defaults. It's a bad user
# experience, but that's bazel for you! A per-project Makefile.vars is a lot
# cleaner and easier to use than config_settings.

# The default value of:
#  tech_vendor is "xilinx"
#  tech_node is "ultrascale_plus"
#  fpga_tool is "vivado"
#
#string_flag(
#    name = "tech_vendor",
#    build_setting_default = "xilinx"
#)
#string_flag(
#    name = "tech_node",
#    build_setting_default = "ultrascale_plus"
#)
#
#string_flag(
#    name = "fpga_tool",
#    build_setting_default = "vivado"
#)
#
#config_setting(
#    name = "cfg_fpga_xilinx_usp",
#    flag_values = {
#        ":tech_vendor": "xilinx",
#        ":tech_node": "ultrascale_plus",
#    },
#)
#
#config_setting(
#    name = "cfg_fpga_intel_stratixv",
#    flag_values = {
#        ":tech_vendor": "intel",
#        ":tech_node": "stratixv",
#    },
#)
#
#config_setting(
#    name = "fpga_tool_vivado",
#    flag_values = {
#        ":tech_vendor": "xilinx",
#        ":fpga_tool": "vivado",
#    },
#)
#
#config_setting(
#    name = "fpga_tool_quartus",
#    flag_values = {
#        ":tech_vendor": "intel",
#        ":fpga_tool": "quartus",
#    },
#)
