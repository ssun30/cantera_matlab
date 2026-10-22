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

1. **Stage** the Cantera MATLAB interface, samples, and data files from a
   checkout of the main Cantera repo.
2. **Build** a self-contained Cantera library from source, with every
   third-party dependency vendored and statically linked, so users need no
   Cantera installation of their own.
3. **Build** the C++ interface against that library, and **test** that the
   staged toolbox loads and works.
4. **Package** everything, binaries included, into a `.mltbx`.

---

## For users — installing the toolbox

The toolbox is distributed through MATLAB File Exchange:

> **Cantera MATLAB Toolbox** (temporary link):
> https://www.mathworks.com/matlabcentral/fileexchange/183781-cantera_matlab

**You do not need to install Cantera separately.** The toolbox includes the
compiled interface for Windows, Linux, and macOS, together with a
self-contained Cantera library — every third-party dependency is vendored and
statically linked, so it depends on nothing beyond the operating system — and
the toolbox ships Cantera's standard data files (`gri30.yaml`, `air.yaml`, and
the rest). No conda environment, no `LD_LIBRARY_PATH`, no compiler.

> **Prefer a guided walkthrough?** When you install the toolbox, MATLAB opens
> its **Getting Started** guide — a live script that runs `ct.install` and a
> first simulation step by step. You can follow it instead of the steps below.
> To reopen it later, go to **Home > Add-Ons > Manage Add-Ons**, click the
> **⋮** menu next to *Cantera MATLAB Toolbox*, and choose **Open Getting
> Started Guide**.

### 1. Install the `.mltbx`

Download the `.mltbx` and double-click it (or use the MATLAB Add-On Manager).

### 2. Run `ct.install` once

```matlab
ct.install
```

This registers the bundled data directory and verifies that Cantera loads. The settings are saved as
MATLAB preferences, so this is needed only once; running it again does nothing
unless the installation is incomplete. To redo it, use `ct.install(Force=true)`.

### 3. Use Cantera

Load Cantera at the start of each session:

```matlab
ct.load
gas = ct.Solution("gri30.yaml");
```

### Tutorials

The toolbox includes tutorial live scripts that go beyond the Getting Started
guide. Open one by name, for example:

```matlab
open CanteraTutorial
```

* `CanteraTutorial` covers setting the thermodynamic state, working with
  mechanism files, chemical equilibrium, and reaction rates.
* `LithiumIonBattery` computes the open-circuit voltage of a lithium-ion cell
  from thermodynamics and from electrode kinetics, and its discharge curves
  at several currents.

### Uninstalling

Run `ct.uninstall` **first**, then remove the toolbox in the Add-On Manager.
`ct.uninstall` clears the saved Cantera preferences and unloads Cantera, and it is
part of the toolbox, so it is no longer available once the toolbox is removed.

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
| `TOOLBOX_VERSION`        | Semantic version for the package, e.g. `3.9.2`; independent of the Cantera version. CI takes it from the pushed tag (`v3.9.2`), or uses `0.0.0` |
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
BLAS/LAPACK, no HDF5), then checks with `audit_library.py` that
the result depends on nothing outside a per-platform allowlist of OS libraries.
Both scripts (`build_cantera_library.py` and `audit_library.py`) live in Cantera's
`interfaces/matlab/buildUtilities`; `buildtool stage` copies them into the staged
toolbox, and `buildtool package` leaves them out of the MLTBX.
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
| `buildtool stage`               | Copy the interface, samples, and data from `CANTERA_ROOT` into `TMP/`. |
| `buildtool buildCanteraLibrary` | Build the self-contained Cantera library into `build/canteraLib/`. |
| `buildtool buildInterface`      | Compile the C++ interface into the staged tree (depends on `stage` and `buildCanteraLibrary`). |
| `buildtool test`                | Run smoke tests against the staged, built toolbox (depends on `buildInterface`). |
| `buildtool package`             | Build the `.mltbx`, binaries included, into `release/` (depends on `buildInterface`). |
| `buildtool`                     | Run `test` and `package`, the default tasks.                       |

`buildCanteraLibrary` builds from `CANTERA_ROOT`, but runs the build scripts
from the staged copy of Cantera's `interfaces/matlab/buildUtilities`, so it
depends on `stage`:

```
stage ─→ buildCanteraLibrary ─→ buildInterface ─┬─→ test
                                                └─→ package
```

A local `buildtool package` includes only the current platform's binaries, and
installs directly for testing. The release workflow builds the interface on
all three platforms, merges them into one stage, and packages once, so the
published `.mltbx` serves every platform.

### Live scripts

The Getting Started guide (`doc/GettingStarted.m`) and the tutorials
(`doc/tutorials/*.m`) are kept as plain `.m` files, so that changes are easy
to review. `buildtool package` converts each of them to a `.mlx` live script in
the same place in the package, in a `doc` folder next to `toolbox`, `samples`,
and `data`:

```
doc/GettingStarted.mlx        registered as the toolbox's Getting Started guide
doc/tutorials/*.mlx           on the toolbox's MATLAB path, so users can open them by name
```

To add a tutorial, add a `.m` file to `doc/tutorials`, using `%%` section
headers and `%` comment lines for the text, like the existing ones.

### Outputs

* `TMP/` — staging area (intermediate; safe to delete).
* `build/canteraLib/` — the self-contained Cantera library (`include/`, `lib/`).
* `release/` — the built `.mltbx`.

### Releasing

Push a tag `vX.Y.Z` to `main`; do not create the release on GitHub by hand.
The release workflow builds the toolbox on all three platforms, packages it as
version `X.Y.Z`, and publishes the GitHub release with the `.mltbx` attached,
which File Exchange then picks up. File Exchange only uses a `.mltbx` that is
attached when the release is published, so a release created by hand, with the
toolbox attached later, ships without it.

To rehearse, run the release workflow manually from the Actions tab. It builds
and packages the toolbox (as version `0.0.0`) without publishing anything.
With *Test the release job* ticked, it also creates a draft release named
`test-<run number>` with the toolbox attached; inspect it on the Releases page,
then delete it. Do not push test tags: any `v*` tag publishes a release.
