# Cantera MATLAB Toolbox — Packaging & Release

[![Cantera MATLAB CI](https://github.com/ssun30/cantera_matlab/actions/workflows/main.yml/badge.svg)](https://github.com/ssun30/cantera_matlab/actions/workflows/main.yml)
[![View on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/183781-cantera_matlab)
[![Latest release](https://img.shields.io/github/v/release/ssun30/cantera_matlab?include_prereleases)](https://github.com/ssun30/cantera_matlab/releases)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![MATLAB](https://img.shields.io/badge/MATLAB-R2024b%2B-orange)

This repository independently hosts the tooling needed to **build, test, and
release** the Cantera MATLAB Toolbox as a `.mltbx` package for easy
installation. It does not contain the MATLAB interface source code itself —
that is maintained in the main [Cantera repository](https://github.com/Cantera/cantera)
under `interfaces/matlab`.

The pipeline:

1. **Stage** the Cantera MATLAB interface (and samples) from a checkout of the
   main Cantera repo.
2. **Package** the pure-MATLAB tree into a `.mltbx` for distribution.
3. **Build** a self-contained Cantera library from source, with every
   third-party dependency vendored and statically linked, so users need no
   Cantera installation of their own.
4. **Build** the C++ interface against that library, and **test** that the
   staged toolbox loads and works.

---

## For users — installing the toolbox

The toolbox is distributed through MATLAB File Exchange:

> **Cantera MATLAB Toolbox** (temporary link):
> https://www.mathworks.com/matlabcentral/fileexchange/183781-cantera_matlab

Because of MathWorks File Exchange policy, the **pre-built interface library is
not shipped inside the `.mltbx`**. Instead, MATLAB **automatically downloads**
the compiled interface for your platform when you install the toolbox. You then
move it into the toolbox and add it to the path. Installation therefore has two
parts:

### 1. Install the `.mltbx`

Download the `.mltbx` and double-click it (or use the MATLAB Add-On Manager) to
add the toolbox to MATLAB's add-ons. During installation MATLAB prompts you to
install "third-party software" and downloads the compiled interface for your
platform into an `AdditionalSoftware` folder.

### 2. Move the downloaded interface library into the toolbox

The downloaded interface lands in an `AdditionalSoftware` folder that sits next
to the installed toolbox, under the MATLAB Add-Ons directory:

```
<MATLAB Add-Ons>/Toolboxes/
├── Cantera MATLAB Toolbox/        ← the installed toolbox
└── AdditionalSoftware/
    └── ctMatlabInterface/
        └── ctMatlab/              ← the downloaded interface library
```

To get the exact path on your machine, run in MATLAB:

```matlab
CanteraMATLABToolbox.getInstallationLocation("ctMatlabInterface")
```

(The Add-Ons installation folder is also shown in **MATLAB Preferences →
Add-Ons** and in the Add-On Manager.)

Move the `ctMatlab` folder out of `AdditionalSoftware` and into the installed
toolbox so it ends up at:

```
Cantera MATLAB Toolbox/toolbox/+ct/+impl/ctMatlab/
```

Then add that folder to the MATLAB path and save it (this is required — the
`+ct/+impl/ctMatlab` folder is not on the path automatically):

```matlab
addpath("<...>/Cantera MATLAB Toolbox/toolbox/+ct/+impl/ctMatlab")
savepath
```

> **Alternatively, build the interface yourself** with `ct.buildInterface` (see
> the interface README in the main Cantera repo) and place the result in the
> same location. `ct.buildInterface` adds it to the path and saves it for you,
> so no separate `addpath`/`savepath` step is needed.

> This manual move will be automated in a future release.

### 3. Load Cantera

**You do not need to install Cantera separately.** The download in step 1
includes a self-contained Cantera library — every third-party dependency is
vendored and statically linked, so it depends on nothing beyond the operating
system. No conda environment, no `LD_LIBRARY_PATH`, no compiler.

Run `ct.load` for the first time. If you are prompted for the Cantera library
directory, point it at the same `ctMatlab` folder you moved in step 2 — the
library ships alongside the interface. The choice is remembered for future
sessions, and the data directory is registered automatically. See the interface
usage guide for details (`ct.configureCanteraDirectories`, execution modes).

---

## For maintainers — building, testing, releasing

### Prerequisites

* **MATLAB** R2024b or later, with a MATLAB-compatible C++ compiler.
* A checkout of the **main Cantera repository**, cloned with submodules
  (`git clone --recurse-submodules`).
* **Python 3.9+** with `scons`, `packaging`, `jinja2`, and `ruamel.yaml`
  (`pip install scons packaging jinja2 ruamel.yaml`).
* **Boost headers, 1.83 or newer** — the only Cantera dependency not vendored
  under `ext/`. Set `BOOST_INC_DIR` if not on the default include path.
* **doxygen**, with **perl** on its PATH. Required to build, not only to build
  docs: `cantera_clib` is generated at build time by `sourcegen`, which reads a
  Doxygen tag file.

No Cantera installation is required — `buildtool buildCanteraLibrary` builds a
self-contained one from source. It verifies all of the above before starting.

**On Windows**, run from **Git Bash** (doxygen needs the perl in Git's
`usr/bin`, absent from PowerShell's PATH), and either pin `doxygen=1.9.*` or
install MiKTeX — doxygen 1.17 treats a missing `bibtex` as fatal.

Set these environment variables before building:

| Variable                 | Purpose                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `CANTERA_ROOT`           | Path to the main Cantera source checkout (staged, and built)        |
| `TOOLBOX_VERSION`        | Semantic version for the package, e.g. `3.2.0`                     |
| `CANTERA_USE_SYSTEM_LIB` | Optional. Set to `1` to skip the library build (see below)          |
| `CANTERA_INCLUDE_PATH`   | Optional override; set automatically by `buildCanteraLibrary`       |
| `CANTERA_LIB_PATH`       | Optional override; set automatically by `buildCanteraLibrary`       |
| `BOOST_INC_DIR`          | Optional. Boost headers, if not on the default include path         |
| `PYTHON`                 | Optional. Full path to the interpreter that drives SCons            |

> Set `PYTHON` if the build fails with exit code 9009: MATLAB's `PATH` often
> holds only the Microsoft Store stub rather than a real interpreter.

> A `cantera.conf` left in `CANTERA_ROOT` supplies any option the build script
> does not set explicitly. Rename it for a build that matches CI; the script
> warns when it finds one.

### The self-contained Cantera library

`buildtool buildCanteraLibrary` builds Cantera with every third-party
dependency vendored and statically linked (`system_*=n`, no external
BLAS/LAPACK, no HDF5), then checks with `buildUtilities/audit_library.py` that
the result depends on nothing outside a per-platform allowlist of OS libraries.
MATLAB's `clibgen` copies it next to the generated interface, so it ships
inside the `ctMatlab` bundle automatically.

Two consequences: HDF5 support is off (`ct.usesHDF5` returns false), and dense
linear algebra falls back to Eigen rather than an optimized BLAS.

A full build is slow. The task stamps `build/canteraLib/.build-stamp` with the
Cantera commit and a hash of the build flags, and skips the rebuild when both
are unchanged. To bypass it and use an existing Cantera installation:

```bash
export CANTERA_USE_SYSTEM_LIB=1
export CANTERA_INCLUDE_PATH=...   # must contain a cantera_clib subfolder
export CANTERA_LIB_PATH=...
```

### Build tasks

The build is orchestrated by MATLAB's `buildtool` (see `buildfile.m`). From the
repository root:

| Command                         | Description                                                        |
| ------------------------------- | ----------------------------------------------------------------- |
| `buildtool stage`               | Copy the interface and samples from `CANTERA_ROOT` into `TMP/`.    |
| `buildtool package`             | Build the `.mltbx` into `release/` (depends on `stage`).           |
| `buildtool buildCanteraLibrary` | Build the self-contained Cantera library into `build/canteraLib/`. |
| `buildtool buildInterface`      | Compile the C++ interface into the staged tree (depends on `package` and `buildCanteraLibrary`). |
| `buildtool test`                | Run smoke tests against the staged, built toolbox (depends on `buildInterface`). |
| `buildtool`                     | Run the full chain; `test` is the default task.                    |

`buildCanteraLibrary` builds from `CANTERA_ROOT` rather than the staged tree,
so it is a second root task joining the chain at `buildInterface`:

```
stage ─→ package ─┐
                  ├─→ buildInterface ─→ test
buildCanteraLibrary ─┘
```

**`package` runs before `buildInterface`**, so the distributable `.mltbx` is
produced without the compiled binary (per File Exchange policy). The later
steps build the interface into the staging tree only, to verify it compiles
and loads.

### Outputs

* `TMP/` — staging area (intermediate; safe to delete).
* `build/canteraLib/` — the self-contained Cantera library (`include/`, `lib/`).
* `release/` — the built `.mltbx`.
