# Cantera MATLAB Toolbox — Packaging & Release

[![Cantera MATLAB CI](https://github.com/ssun30/cantera_matlab/actions/workflows/main.yml/badge.svg)](https://github.com/ssun30/cantera_matlab/actions/workflows/main.yml)

This repository independently hosts the tooling needed to **build, test, and
release** the Cantera MATLAB Toolbox as a `.mltbx` package for easy
installation. It does not contain the MATLAB interface source code itself —
that is maintained in the main [Cantera repository](https://github.com/Cantera/cantera)
under `interfaces/matlab`.

The pipeline:

1. **Stage** the Cantera MATLAB interface (and samples) from a checkout of the
   main Cantera repo.
2. **Build** a C++ interface library against a Cantera installation.
3. **Test** that the staged, built toolbox loads and works.
4. **Package** everything into a `.mltbx` file for distribution.

---

## For users — installing the toolbox

The toolbox is distributed through MATLAB File Exchange:

> **Cantera MATLAB Toolbox** (temporary link):
> https://www.mathworks.com/matlabcentral/fileexchange/183781-cantera_matlab

Because of MathWorks File Exchange policy, the **pre-built interface library is
not shipped inside the `.mltbx`**. Installation therefore has two parts:

### 1. Install the `.mltbx`

Download the `.mltbx` and double-click it (or use the MATLAB Add-On Manager) to
add the toolbox to MATLAB's add-ons.

### 2. Provide the compiled interface library

Obtain the interface library either way:

* **Download the pre-built assets** matching your platform, MATLAB release, and
  Cantera version from the co-hosted releases:
  https://github.com/ssun30/cantera_matlab/releases
* **Build it yourself** with `ct.buildInterface` (see the interface README in
  the main Cantera repo).

Then place the libraries inside the installed toolbox: create a `ctMatlab`
folder under

```
toolbox/+ct/+impl/ctMatlab/
```

and move the `ctMatlabInterface` library and the Cantera shared library into it.

> This manual placement step will be automated in a future release.

### 3. Load Cantera

Run `ct.load` for the first time. You will be prompted to locate your Cantera
library directory (e.g. a conda environment's library folder); the choice is
remembered for future sessions, and the data directory is registered
automatically. See the interface usage guide for details
(`ct.configureCanteraDirectories`, execution modes, etc.).

---

## For maintainers — building, testing, releasing

### Prerequisites

* **MATLAB** (R2024a or later) with a MATLAB-compatible C++ compiler.
* A checkout of the **main Cantera repository** (provides `interfaces/matlab`
  and `samples/matlab`).
* A **Cantera development installation** providing the `cantera_clib` headers
  and the shared library — e.g. `conda install -c conda-forge libcantera-devel`.

Set these environment variables before building:

| Variable               | Purpose                                              |
| ---------------------- | --------------------------------------------------- |
| `CANTERA_ROOT`         | Path to the main Cantera source checkout (to stage) |
| `CANTERA_INCLUDE_PATH` | Include directory containing `cantera_clib`         |
| `CANTERA_LIB_PATH`     | Directory containing the Cantera shared library     |
| `TOOLBOX_VERSION`      | Semantic version for the package, e.g. `3.2.0`      |

### Build tasks

The build is orchestrated by MATLAB's `buildtool` (see `buildfile.m`). From the
repository root:

| Command                    | Description                                                        |
| -------------------------- | ----------------------------------------------------------------- |
| `buildtool stage`          | Copy the interface and samples from `CANTERA_ROOT` into `TMP/`.    |
| `buildtool package`        | Build the `.mltbx` into `release/` (depends on `stage`).           |
| `buildtool buildInterface` | Compile the C++ interface into the staged tree (depends on `package`). |
| `buildtool test`           | Run smoke tests against the staged, built toolbox (depends on `buildInterface`). |
| `buildtool`                | Run the full chain (`stage → package → buildInterface → test`); `test` is the default task. |

Note that **`package` runs before `buildInterface`**, so the distributable
`.mltbx` is produced *without* the compiled binary (per File Exchange policy).
The subsequent `buildInterface` + `test` steps build the interface into the
staging tree only, to verify that it compiles and loads.

### Outputs

* `TMP/` — staging area (intermediate; safe to delete).
* `release/` — the built `.mltbx`.
