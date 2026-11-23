function ctBuildCanteraLibrary(options)
%CTBUILDCANTERALIBRARY Build a self-contained Cantera library for the toolbox.
%
% Builds Cantera from source with every third-party dependency vendored and
% statically linked, installing it under build/canteraLib. Sets
% CANTERA_INCLUDE_PATH and CANTERA_LIB_PATH to the result, which is where
% ctBuildInterface picks them up.
%
% Set CANTERA_USE_SYSTEM_LIB=1 to skip the build and use whatever those two
% variables already point at.

    arguments
        options.RepoRoot (1,1) string = ""
        options.CanteraRoot (1,1) string = string(getenv("CANTERA_ROOT"))
        options.Prefix (1,1) string = ""
        options.Force (1,1) logical = false
        options.Verbose (1,1) logical = true
    end

    if options.RepoRoot == ""
        options.RepoRoot = inferRepoRoot();
    end

    if options.Prefix == ""
        % Outside TMP: ctStageToolbox deletes the whole staging root, and
        % buildtool does not fix the order of the two root tasks.
        options.Prefix = fullfile(options.RepoRoot, "build", "canteraLib");
    end

    if useSystemLibrary()
        fprintf(['CANTERA_USE_SYSTEM_LIB is set; skipping the Cantera ' ...
                 'library build.\n']);
        fprintf("Using CANTERA_INCLUDE_PATH: %s\n", getenv("CANTERA_INCLUDE_PATH"));
        fprintf("Using CANTERA_LIB_PATH:     %s\n", getenv("CANTERA_LIB_PATH"));
        return
    end

    if options.CanteraRoot == ""
        error("ctBuildCanteraLibrary:MissingCanteraRoot", ...
            ("CANTERA_ROOT is not set. Point it at a checkout of the main " + ...
             "Cantera repository, or set CANTERA_USE_SYSTEM_LIB=1 to build " + ...
             "against an existing Cantera installation."));
    end

    if ~isfolder(options.CanteraRoot)
        error("ctBuildCanteraLibrary:MissingFolder", ...
            "CANTERA_ROOT does not exist: %s", options.CanteraRoot);
    end

    if options.Verbose
        fprintf("Building self-contained Cantera library...\n");
        fprintf("Cantera source: %s\n", options.CanteraRoot);
        fprintf("Install prefix: %s\n", options.Prefix);
    end

    runBuildScript(options);

    includePath = fullfile(options.Prefix, "include");
    libPath = fullfile(options.Prefix, "lib");

    if ~isfolder(fullfile(includePath, "cantera_clib"))
        error("ctBuildCanteraLibrary:MissingHeaders", ...
            ("The build did not produce %s. ctBuildInterface requires a " + ...
             "cantera_clib subfolder in the include directory."), ...
            fullfile(includePath, "cantera_clib"));
    end

    setenv("CANTERA_INCLUDE_PATH", includePath);
    setenv("CANTERA_LIB_PATH", libPath);

    if options.Verbose
        fprintf("Cantera library build complete.\n");
        fprintf("CANTERA_INCLUDE_PATH=%s\n", includePath);
        fprintf("CANTERA_LIB_PATH=%s\n", libPath);
    end
end

function runBuildScript(options)
%RUNBUILDSCRIPT Invoke the SCons driver outside MATLAB's library environment.

    script = fullfile(fileparts(mfilename("fullpath")), "build_cantera_library.py");

    cmd = string(sprintf('%s "%s" --cantera-root "%s" --prefix "%s"', ...
        quoteIfNeeded(pythonExecutable()), script, ...
        options.CanteraRoot, options.Prefix));

    if options.Force
        cmd = cmd + " --force";
    end

    if options.Verbose
        cmd = cmd + " --verbose";
    end

    cleanupEnv = shieldFromMatlabRuntime();  %#ok<NASGU> restored on exit

    status = system(cmd, "-echo");
    if status ~= 0
        error("ctBuildCanteraLibrary:BuildFailed", ...
            "Cantera library build failed (exit code %d).", status);
    end
end

function cleanupObj = shieldFromMatlabRuntime()
%SHIELDFROMMATLABRUNTIME Temporarily clear MATLAB's injected loader paths.
%
% MATLAB prepends its own libraries for child processes, which makes compilers
% and linkers pick up MATLAB's runtime instead of the toolchain's.

    names = ["LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "LD_PRELOAD"];
    saved = arrayfun(@(n) string(getenv(n)), names);

    for i = 1:numel(names)
        setenv(names(i), "");
    end

    cleanupObj = onCleanup(@() restoreEnv(names, saved));
end

function restoreEnv(names, saved)
%RESTOREENV Put the saved loader-path variables back.

    for i = 1:numel(names)
        setenv(names(i), saved(i));
    end
end

function exe = pythonExecutable()
%PYTHONEXECUTABLE Resolve a working Python interpreter to drive SCons.
%
% Tries PYTHON, then MATLAB's configured interpreter, then python3/python from
% PATH. Each candidate is verified by running it: on Windows, MATLAB's PATH
% often holds only the Microsoft Store stub, which exits 9009.

    override = strip(string(getenv("PYTHON")));
    if override ~= ""
        if ~isWorkingPython(override)
            error("ctBuildCanteraLibrary:BadPython", ...
                "PYTHON is set to '%s', but running it failed.", override);
        end
        exe = override;
        return
    end

    candidates = string.empty;

    try
        configured = string(pyenv().Executable);
        if configured ~= "" && isfile(configured)
            candidates(end+1) = configured;
        end
    catch
        % No Python configured for MATLAB; fall through to PATH.
    end

    candidates = [candidates, "python3", "python"];

    for i = 1:numel(candidates)
        if isWorkingPython(candidates(i))
            exe = candidates(i);
            return
        end
    end

    error("ctBuildCanteraLibrary:NoPython", ...
        ("Could not find a working Python interpreter to drive SCons.\n" + ...
         "Set PYTHON to its full path, for example:\n" + ...
         "    setenv(""PYTHON"", ""C:\\path\\to\\python.exe"")"));
end

function tf = isWorkingPython(exe)
%ISWORKINGPYTHON Check that a candidate interpreter actually runs.

    [status, ~] = system(quoteIfNeeded(exe) + " --version");
    tf = status == 0;
end

function quoted = quoteIfNeeded(exe)
%QUOTEIFNEEDED Quote a command only when it contains whitespace.
%
% cmd.exe mishandles a command line whose first character is a quote, so bare
% names are left unquoted.

    if contains(exe, " ")
        quoted = """" + exe + """";
    else
        quoted = exe;
    end
end

function tf = useSystemLibrary()
%USESYSTEMLIBRARY Report whether CANTERA_USE_SYSTEM_LIB requests a skip.

    value = lower(strip(string(getenv("CANTERA_USE_SYSTEM_LIB"))));
    tf = ismember(value, ["1", "y", "yes", "true", "on"]);
end

function repoRoot = inferRepoRoot()
%INFERREPOROOT Infer the cantera_matlab repository root.

    thisFile = string(mfilename("fullpath"));
    buildUtilitiesDir = string(fileparts(thisFile));
    repoRoot = string(fileparts(buildUtilitiesDir));

    if ~isfolder(fullfile(repoRoot, "buildUtilities"))
        error("ctBuildCanteraLibrary:InvalidRepoRoot", ...
            "Could not infer repository root from %s.", thisFile);
    end
end
