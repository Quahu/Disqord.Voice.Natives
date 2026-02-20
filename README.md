# Disqord.Voice.Natives

Pre-built [libdave](https://github.com/discord/libdave) natives for [Disqord.Voice](https://github.com/Quahu/Disqord/tree/master/src/Disqord.Voice).

Provides native binaries for Discord's DAVE E2EE protocol.

## Supported Platforms

| RID           | Library         |
| ------------- | --------------- |
| `win-x64`     | `libdave.dll`   |
| `linux-x64`   | `libdave.so`    |
| `linux-arm64` | `libdave.so`    |
| `osx-x64`     | `libdave.dylib` |
| `osx-arm64`   | `libdave.dylib` |

## Licenses

The bundled binaries include the following statically linked libraries:
- [libdave](https://github.com/discord/libdave) (MIT)
- [BoringSSL](https://boringssl.googlesource.com/boringssl/) (OpenSSL/ISC)
- [mlspp](https://github.com/cisco/mlspp) (BSD-2-Clause)
- [nlohmann-json](https://github.com/nlohmann/json) (MIT)

See the `lib/licenses/` directory for full license texts.
