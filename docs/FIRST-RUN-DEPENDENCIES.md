# First-run dependency policy

Internet access may be required for one-off installation/build dependencies.

That is acceptable for this project. What is not acceptable is requiring the internet for normal operation.

## Potential one-off downloads

### Godot

Install the supported Godot version and its export templates if you intend to create distributable builds.

### Rust desktop bridge

`cargo build --release` may download crates from the configured Cargo registry the first time.

After Cargo's dependency cache is populated, subsequent builds can be done offline where the dependency set is already available.

### Linux native headers

`apt update` and `apt install` contact the machine's configured operating-system package repositories.

### Windows/macOS development tools

Platform SDKs and compiler toolchains may similarly need one-time installation.

## Not used at runtime

None of these installers/package managers are invoked by the ELI VR application itself.

There is no runtime sign-in or dependency-download step.
