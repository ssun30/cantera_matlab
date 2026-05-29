function stage = ctStageToolbox(options)
%CTSTAGETOOLBOX Stage Cantera MATLAB toolbox files for build tasks.

    arguments
        options.CtRoot (1,1) string = string(getenv("CANTERA_ROOT"))
        options.RepoRoot (1,1) string = inferRepoRoot()
        options.StageRoot (1,1) string = ""
        options.Clean (1,1) logical = true
        options.Verbose (1,1) logical = true
    end

    ctRoot = options.CtRoot;

    if ctRoot == ""
        error("ctStageToolbox:MissingCtRoot", ...
            "CtRoot was not provided and CANTERA_ROOT is not set.");
    end

    ctRoot = mustBeExistingFolder(ctRoot, "CtRoot");
    repoRoot = mustBeExistingFolder(options.RepoRoot, "RepoRoot");

    if options.StageRoot == ""
        stageRoot = fullfile(repoRoot, "TMP");
    else
        stageRoot = string(options.StageRoot);
    end

    if options.Verbose
        fprintf("Staging Cantera MATLAB toolbox files...\n");
        fprintf("Cantera root: %s\n", ctRoot);
        fprintf("Repo root:    %s\n", repoRoot);
        fprintf("Stage root:   %s\n", stageRoot);
    end

    if options.Clean && isfolder(stageRoot)
        if options.Verbose
            fprintf("Removing existing stage directory: %s\n", stageRoot);
        end
        rmdir(stageRoot, "s");
    end

    mkdir(stageRoot);

    mapping = {
        fullfile("interfaces", "matlab"), "toolbox";
        fullfile("samples", "matlab"),    "samples";
    };

    for i = 1:size(mapping, 1)
        src = fullfile(ctRoot, mapping{i, 1});
        dest = fullfile(stageRoot, mapping{i, 2});

        src = mustBeExistingFolder(src, "Source folder");

        if options.Verbose
            fprintf("Copying %s\n    -> %s\n", src, dest);
        end

        copyfile(src, dest);
    end

    removeExcludedDirectories(stageRoot, options.Verbose);
    removeExcludedFiles(stageRoot, options.Verbose);

    stage = struct;
    stage.Root = string(stageRoot);
    stage.Toolbox = string(fullfile(stageRoot, "toolbox"));
    stage.Samples = string(fullfile(stageRoot, "samples"));
    stage.CtRoot = string(ctRoot);
    stage.RepoRoot = string(repoRoot);

    validateStage(stage);

    if options.Verbose
        fprintf("Staging complete.\n");
        fprintf("Staged toolbox: %s\n", stage.Toolbox);
        fprintf("Staged samples: %s\n", stage.Samples);
    end
end

function removeExcludedDirectories(stageRoot, verbose)
    excludeDirs = [
        fullfile(stageRoot, "toolbox", "+ct", "+impl", "ctMatlab")
    ];

    for i = 1:numel(excludeDirs)
        if isfolder(excludeDirs(i))
            if verbose
                fprintf("Removing excluded directory: %s\n", excludeDirs(i));
            end
            rmdir(excludeDirs(i), "s");
        end
    end
end

function removeExcludedFiles(stageRoot, verbose)
    excludePatterns = string.empty;

    for i = 1:numel(excludePatterns)
        files = dir(excludePatterns(i));

        for j = 1:numel(files)
            file = fullfile(files(j).folder, files(j).name);

            if verbose
                fprintf("Deleting excluded file: %s\n", file);
            end

            delete(file);
        end
    end
end

function validateStage(stage)
    mustBeExistingFolder(stage.Root, "Stage root");
    mustBeExistingFolder(stage.Toolbox, "Staged toolbox");
    mustBeExistingFolder(stage.Samples, "Staged samples");

    if ~isfolder(fullfile(stage.Toolbox, "+ct"))
        error("ctStageToolbox:MissingPackageNamespace", ...
            "Staged toolbox does not contain the +ct package folder: %s", ...
            fullfile(stage.Toolbox, "+ct"));
    end
end

function folder = mustBeExistingFolder(folder, label)
    folder = string(folder);

    if ~isfolder(folder)
        error("ctStageToolbox:MissingFolder", ...
            "%s does not exist: %s", label, folder);
    end
end

function repoRoot = inferRepoRoot()
    thisFile = string(mfilename("fullpath"));
    buildUtilitiesDir = string(fileparts(thisFile));
    repoRoot = string(fileparts(buildUtilitiesDir));
end
