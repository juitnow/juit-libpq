@juit/libpq
===========

> Precompiled native bindings for [`libpq`](https://github.com/brianc/node-libpq),
> ready to use with Node.js — no build toolchain required.

## Why This Exists

The excellent [`libpq`](https://github.com/brianc/node-libpq) library by
Brian M. Carlson provides low-level access to PostgreSQL via its native
`libpq` interface. However, it must be compiled locally during `npm install`,
which poses challenges:

- **Security concerns**:  Many users now disable install scripts to mitigate
  supply chain attacks.
- **Environment constraints**: Not all environments (e.g., CI, containers,
  edge runtimes) have the required toolchain for native builds.

This project provides **prebuilt binaries** of `libpq`:

- **Statically linked** against PostgreSQL's `libpq` (currently v16.10).
- **No external dependencies** (e.g., OpenSSL, libpq) — all included
- **Built against Node.js 20, 22, and 24 ABI versions**
- **Supports Linux (x64 & arm64) and macOS (arm64)**
- [**MIT licensed**](LICENSE.md)
