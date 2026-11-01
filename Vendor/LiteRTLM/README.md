# LiteRT-LM Swift wrapper

This directory vendors the Apache-2.0 Swift wrapper from Google AI Edge
LiteRT-LM `v0.12.0`. Its package manifest downloads Google's official
`CLiteRTLM.xcframework` binary and verifies checksum
`3c2a11ecc8511d1e74efa7ca308dc7130c95223325c33212337ffb0563b79cde`.

The small wrapper is kept locally because the upstream Git repository contains
large prebuilt assets that are unnecessary for Swift Package Manager builds.
See `LICENSE` for its license.
