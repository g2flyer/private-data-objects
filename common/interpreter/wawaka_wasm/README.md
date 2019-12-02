<!--- -*- mode: markdown; fill-column: 100 -*- --->
<!---
Licensed under Creative Commons Attribution 4.0 International License
https://creativecommons.org/licenses/by/4.0/
--->

**NOTE: THIS IS A RESEARCH PROTOTYPE, IT IS NOT INTENDED FOR PRODUCTION USAGE**

# The Wawaka Contract Interpreter #

The Wawaka contract interpreter processes contracts for private data
objects based on the
[WebAssembly Micro Runtime](https://github.com/intel/wasm-micro-runtime)
developed by Intel (WAMR). WAMR implements a small WebAssembly VM and a
set of supporting functions that can be executed inside the contract
enclave. As such contracts can be implemented in any programming
language that can be compiled into WASM.

## Building Wawaka ##

The Wawaka interpreter is not built by default. To build a contract
enclave with Wawaka enabled, you will need to do the following:

  * Install and configure [emscripten](https://emscripten.org/)
  * Clone the WAMR source code
  * Set the `WASM_SRC` environment variable to the directory where you cloned WAMR
  * Set the `PDO_INTERPRETER` environment variable to `wawaka`

### Install emscripten ###

There are many toolchains that could be used to build a WASM code. We have tested (and our sample
and test contracts use) [emscripten](https://emscripten.org/). Note that we currently require the `fastcomp` compiler which is no longer the default compiler.

```bash
cd ${PDO_SOURCE_ROOT}

git clone https://github.com/emscripten-core/emsdk.git
cd ${PDO_SOURCE_ROOT}/emsdk

./emsdk install latest-fastcomp
./emsdk activate latest-fastcomp

source ./emsdk_env.sh
```

### Clone the WAMR source ###

If wawaka is configured as the contract interpreter, the libraries implementing the WASM interpreter
will be built for use with Intel SGX. The source for the WAMR interpreter is distributed separately and must be downloaded.

```bash
cd ${PDO_SOURCE_ROOT}
git clone https://github.com/intel/wasm-micro-runtime.git wasm
```

### Set the environment variables ###

By default, PDO will be built with the Gipsy Scheme contract interpreter. To use the experimental wawaka interpreter, set the environment variables `WASM_SRC` (the directory where you downloaded the WAMR source) and `PDO_INTERPRETER` (the name of the contract interpreter to use.

```bash
export WASM_SRC=${PDO_SOURCE_ROOT}/wasm
export PDO_INTERPRETER=wawaka
```

### Build PDO ###

Note that any change to the contract interpreter requires PDO to be completely rebuilt.

```bash
cd ${PDO_SOURCE_ROOT}/build
make rebuild
```

### Test the Configuration ###

Sample wawaka contracts are built and installed along with the
interpreter. You can run the simple test contract as follows:

```bash
cd ${PDO_SOURCE_ROOT}/contracts/wawaka
pdo-test-contract --no-ledger --interpreter wawaka --contract mock-contract \
    --expressions ./mock-contract/test-long.exp --loglevel info
```

## Basics of a Contract ##

Note that compilation into WASM that will run in the contract enclave can be somewhat tricky. Specifically, all symbols whether used or not must be bound. The wawaka interpreter will fail if it attempts to load WASM code with unbound symbols.

It may be easiest to copy the