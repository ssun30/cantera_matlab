# Cantera MATLAB Toolbox — Packaging & Release

[![Cantera MATLAB CI](https://github.com/ssun30/cantera_matlab/actions/workflows/main.yml/badge.svg)](https://github.com/ssun30/cantera_matlab/actions/workflows/main.yml)
[![View on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/183781-cantera_matlab)
[![Latest release](https://img.shields.io/github/v/release/ssun30/cantera_matlab?include_prereleases)](https://github.com/ssun30/cantera_matlab/releases)
![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![MATLAB](https://img.shields.io/badge/MATLAB-R2022b%2B-orange)

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
