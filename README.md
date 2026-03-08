# Disqord.Voice.Natives

Pre-built native binaries for [Disqord.Voice](https://github.com/Quahu/Disqord/tree/master/src/Disqord.Voice).

This package bundles:
- [libdave](https://github.com/discord/libdave)
- [libsodium](https://github.com/jedisct1/libsodium)

## Supported Platforms

| RID           | libdave         | libsodium         |
|---------------|-----------------|-------------------|
| `win-x64`     | `libdave.dll`   | `libsodium.dll`   |
| `linux-x64`   | `libdave.so`    | `libsodium.so`    |
| `linux-arm64` | `libdave.so`    | `libsodium.so`    |
| `osx-x64`     | `libdave.dylib` | `libsodium.dylib` |
| `osx-arm64`   | `libdave.dylib` | `libsodium.dylib` |

## Updating Bundled Natives

The repository includes helper scripts under `tools\`:

- `Update-Libdave.ps1` downloads the latest libdave release binaries from GitHub
- `Update-Libsodium.ps1` downloads the latest libsodium source release from GitHub and cross-compiles it with Zig
- `Update-All.ps1`

These scripts expect `gh` to be available in `PATH`.

## Licenses

The package redistributes binaries and license texts for:

- [libdave](https://github.com/discord/libdave) (MIT)
- [libsodium](https://github.com/jedisct1/libsodium) (ISC)
- [BoringSSL](https://boringssl.googlesource.com/boringssl/) (OpenSSL/ISC)
- [mlspp](https://github.com/cisco/mlspp) (BSD-2-Clause)
- [nlohmann-json](https://github.com/nlohmann/json) (MIT)

License files are stored in `lib\licenses\` and packed to `contentFiles\any\any\licenses\`.
