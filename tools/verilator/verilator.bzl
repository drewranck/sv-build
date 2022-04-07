
load("//tools/bzl:expand_template.bzl", "expand_template")

VERILATOR_FLAGS = {
    "lint": [
        " -Wno-WIDTH",
    ],
    "build": [
        " -cc",
        " --exe",
        # Optimize
        " -Os",
        " -x-assign 0",
        # Warn abount lint issues; I personally find these to be overly restrictive
        # and less useful for non-Veripool-emacs-auto designers.
        " -Wall",
        " -Wno-BLKSEQ",
        " -Wno-UNUSED",
        " -Wno-WIDTH",
        " -Wno-PINCONNECTEMPTY",

        # TODO(drewranck): Apparently I forgot to include zlib.h on my docker image, so we can't
        # get waves (for now)
        #" --trace --trace-structs --trace-fst",
        " --assert",
        #" --coverage",

        # We are forcing verilator to build, and to build in-place, because
        # it is not running a bazel flow, it runs its own (make or cmake) flow.
        " --build",
        " --Mdir .",

        # We don't need to add the -I. here b/c it is added in the generated
        # .f file as: "-y ."
        #" -I.",

    ],
    "defines": [
        "SIMULATION",
    ],
    "plusargs": [],
    }


def sim_main_cpp_generator(name, srcs,
                           template="//tools/verilator:sim_main.cpp.template",
                           visibility=None):
    """ Build Target - generates a generated_{Module}_sim_main.cpp for Verilator.

        args:
          name -- a string suffix to be appended to each target.
          srcs  -- SystemVerilog Testbench Top files (must end in .sv)
                  such as ["pipeline_test_verilator.sv"].
                  per item in srcs.
          template -- the input C++ template file (such as sim_main.cpp.template),
                      the only replacement is any instance of !!TBTOP!! in this file
                      will get replaced by a src SV module name (such as
                      "pipeline_test_verilator")
          visibility -- build genrule visibility, default None.
        returns: none, creates files generated_{Module}_sim_main.cpp for Verilator.
    """
    _sim_main_cpp_generator_impl(name = name, srcs = srcs, template = template,
                                 visibility = visibility)


def _sim_main_cpp_generator_impl(name, srcs, template, visibility):

    if len(name) < 1:
        fail("name (%s) must have length greater than 1." % name)

    for f in srcs:

        if f[-3:] != ".sv":
            fail("Expected item in srcs (%s) does not end in .sv (name=%s)" % (f, name))

        # strip everything left of an including the ':', strip last 3 chars (assumed '.sv')
        svmodule = f[:-3]
        svmodule = svmodule[svmodule.find(':')+1:]

        _sh_library_name = name + "-" + svmodule
        _expand_template_name = _sh_library_name + "-expand-template"
        _gencpp_file = _sh_library_name + ".cpp"

        expand_template(
            name = _expand_template_name,
            template = template,
            out = _gencpp_file,
            substitutions = {
                "!!TBTOP!!": svmodule,
            }
        )

        native.sh_library(
            name = _sh_library_name,
            data = [_expand_template_name],
        )


def get_str_dotf_cmd_bash_verilator(dotf_fname):
    """ Returns a string bash command for generating a Verilator .f

    Keyword arguments:
    dotf_fname -- .f filename that bash command will generate
    """


    #In Verilator land, the .f consists of some +args, followed
    #by a -y some/path of everywhere to look for .v, .sv, .vh, .svh files.
    return """
echo "+librescan +libext+.v+.sv+.vh+.svh " > $(location {f}) ;
echo "-y ." >> $(location {f}) ;
for dir in `dirname $(SRCS) | uniq` ;
do
    echo "-y $$dir " >> $(location {f}) ;
done ;
""".format(f = dotf_fname)
