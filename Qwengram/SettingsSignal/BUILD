load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "QwengramSettingsSignal",
    module_name = "QwengramSettingsSignal",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//Qwengram/Settings:QwengramSettings",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
