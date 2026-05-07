function ctBuildInterface(options)
%CTBUILDINTERFACE Build the Cantera MATLAB C++ interface in the staged toolbox.
%
% This utility builds the generated MATLAB interface needed by the smoke
% tests. It operates on the staged toolbox tree under TMP/mltbx/toolbox.

    arguments
        options.RepoRoot (1,1) string = ""
        options.StageRoot (1,1) string = ""
        options.IncludePath (1,1) string = string(getenv("CANTERA_INCLUDE_PATH"))
        options.LibPath (1,1) string = string(getenv("CANTERA_LIB_PATH"))
        options.Verbose (1,1) logical = true
    end

    if options.RepoRoot == ""
        options.RepoRoot = inferRepoRoot();
    end

    if options.StageRoot == ""
        options.StageRoot = inferStageRoot(options.RepoRoot);
    end

    toolboxRoot = fullfile(options.StageRoot, "toolbox");
    toolboxRoot = mustBeExistingFolder(toolboxRoot, "Staged toolbox root");

    options.IncludePath = mustBeExistingFolder( ...
        options.IncludePath, "IncludePath");

    options.LibPath = mustBeExistingFolder( ...
        options.LibPath, "LibPath");

    if options.Verbose
        fprintf("Building Cantera MATLAB C++ interface...\n");
        fprintf("Toolbox root: %s\n", toolboxRoot);
        fprintf("Include path: %s\n", options.IncludePath);
        fprintf("Library path: %s\n", options.LibPath);
    end

    oldPath = path;
    cleanupPath = onCleanup(@() path(oldPath));

    addpath(genpath(toolboxRoot));

    ct.buildInterface(toolboxRoot, options.IncludePath, options.LibPath);

    if options.Verbose
        fprintf("Cantera MATLAB C++ interface build complete.\n");
    end
end

function repoRoot = inferRepoRoot()
    thisFile = string(mfilename("fullpath"));
    buildUtilitiesDir = string(fileparts(thisFile));
    repoRoot = string(fileparts(buildUtilitiesDir));

    if ~isfolder(fullfile(repoRoot, "buildUtilities"))
        error("ctBuildInterface:InvalidRepoRoot", ...
            "Could not infer repository root from %s.", thisFile);
    end
end

function stageRoot = inferStageRoot(repoRoot)
    stageRoot = fullfile(repoRoot, "TMP");
end

function folder = mustBeExistingFolder(folder, label)
    folder = string(folder);

    if ~isfolder(folder)
        error("ctBuildInterface:MissingFolder", ...
            "%s does not exist: %s", label, folder);
    end
end
