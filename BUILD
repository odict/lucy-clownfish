config_setting(name = "windows")
config_setting(name = "osx")
config_setting(name = "linux")

steps = [
    "cd compiler/c",
    "./configure",
    "make",
    "make test",
    "cd ../../runtime/c",
    "./configure",
    "make",
    "make test",
    "cd ../../",
    "cp runtime/c/libclownfish.0.6.0.dylib $@"
]

outfile = select({
    ":osx": "libclownfish.0.6.0.dylib",
    ":linux": "libclownfish.0.6.0.so", 
    ":windows": "libclownfish.0.6.0.dll"
})

genrule(
    name = "main",
    srcs = ["compiler", "runtime"],
    cmd = " && ".join(steps),
    local = 1,
    output_to_bindir = 1,
    outs = ["libclownfish.0.6.0.dylib"]
)