function ctPackageToolbox(options)
    arguments
        options.RepoRoot (1,1) string = ""
        options.StageRoot (1,1) string = ""
        options.Version (1,1) string = string(getenv("TOOLBOX_VERSION"))
        options.Clean (1,1) logical = true
        options.Verbose (1,1) logical = true
    end

    if options.RepoRoot == ""
        options.RepoRoot = inferRepoRoot();
    end

    if options.StageRoot == ""
        options.StageRoot = inferStageRoot(options.RepoRoot);
    end

    validateStageRoot(options.StageRoot);

    ver = regexp(options.Version, '\d+\.\d+\.\d+', 'match', 'once');
    if isempty(ver)
        error('Could not parse semantic version from options.Version="%s"', options.Version);
    end
    fprintf('Building toolbox version: %s\n', ver);

    % Read the UUID for the toolbox
    uuidFile = fullfile(options.RepoRoot, 'buildUtilities', 'Cantera_MATLAB_Toolbox.uuid');
    if isfile(uuidFile)
        guid = strtrim(fileread(uuidFile));
        fprintf('The unique identifier for the toolbox is: %s\n', guid);
    else
        error('A unique identifier for the toolbox does not exist! Expected at: %s', uuidFile);
    end

    % Define output file
    outputDir = fullfile(options.RepoRoot, 'release');
    if options.Clean && isfolder(outputDir)
        if options.Verbose
            fprintf("Removing existing release directory: %s\n", outputDir);
        end
        rmdir(outputDir, "s");
    end
    mkdir(outputDir);

    outputFile = fullfile(outputDir, 'Cantera_MATLAB_Toolbox_' + ver + '.mltbx');

    % Convert the Getting Started live script (kept as .m for version control)
    % into a .mlx inside the staged toolbox. Do this before collecting files so
    % the generated .mlx is included in the package.
    guidePath = stageGettingStartedGuide(options.RepoRoot, options.StageRoot);
    stageTutorials(options.RepoRoot, options.StageRoot);

    % Collect packaged files. The library build scripts staged from Cantera's
    % interfaces/matlab/buildUtilities are only used to build the toolbox, so
    % they are left out of the package.
    files = dir(fullfile(options.StageRoot, '**', '*'));
    files = files(~[files.isdir]);
    allFiles = fullfile({files.folder}, {files.name})';
    buildScriptsDir = fullfile(options.StageRoot, 'toolbox', 'buildUtilities');
    allFiles = allFiles(~startsWith(allFiles, buildScriptsDir));

    % The compiled interface ships inside the package. The stage holds one
    % platform's build locally; the release workflow merges all three into it.
    interfaceDir = fullfile(options.StageRoot, 'toolbox', '+ct', '+impl', 'ctMatlab');
    platforms = interfacePlatforms(interfaceDir);
    names = string(fieldnames(platforms));
    included = names(cellfun(@(x) x, struct2cell(platforms)));
    fprintf('Packaging interface binaries for: %s\n', strjoin(included, ', '));

    % The data directory is packaged but kept off the MATLAB path: Cantera
    % resolves data files through its own search path, not MATLAB's. The
    % interface folder is added explicitly, because genpath skips folders
    % inside a package folder, so that the installer puts it on the path.
    matlabPaths = strsplit(genpath(options.StageRoot), pathsep);
    matlabPaths = matlabPaths(~cellfun(@isempty, matlabPaths));
    dataRoot = fullfile(options.StageRoot, 'data');
    matlabPaths = matlabPaths(~startsWith(matlabPaths, dataRoot));
    matlabPaths = matlabPaths(~startsWith(matlabPaths, buildScriptsDir));
    matlabPaths{end+1} = char(interfaceDir);

    % Get path to the icon file
    iconFile = fullfile(options.RepoRoot, 'images', 'cantera-icon.png');

    % Set up toolbox options
    opts = matlab.addons.toolbox.ToolboxOptions(options.StageRoot, guid);
    opts.ToolboxName                     = 'Cantera MATLAB Toolbox';
    opts.ToolboxVersion                  = ver;
    opts.Summary                         = 'MATLAB interface for Cantera.';
    opts.Description = [
        'Cantera is an open-source toolkit for simulating chemical kinetics, ' ...
        'thermodynamics, and transport processes. ' ...
        'This toolbox provides a modern MATLAB interface to Cantera, along with ' ...
        'examples, tutorials, and data files to help users get started quickly.'
    ];
    opts.AuthorName                      = 'Cantera Developers'; % placeholder
    opts.AuthorEmail                     = 'developers@cantera.org'; % placeholder
    opts.ToolboxFiles                    = allFiles;
    opts.ToolboxMatlabPath               = matlabPaths;
    if guidePath ~= ""
        opts.ToolboxGettingStartedGuide  = guidePath;
    end
    opts.ToolboxImageFile                = iconFile;
    % Minimum supported release, verified by CI. Raising this is a breaking
    % change for users on older MATLAB: the Add-On Manager refuses to install
    % the .mltbx below it.
    opts.MinimumMatlabRelease            = 'R2024b';
    opts.OutputFile                      = outputFile;
    opts.SupportedPlatforms.Win64        = platforms.Win64;
    opts.SupportedPlatforms.Glnxa64      = platforms.Glnxa64;
    if isfield(opts.SupportedPlatforms, 'Mac')  % R2026a replaced Maci64 with Mac
        opts.SupportedPlatforms.Mac      = platforms.Mac;
    else
        opts.SupportedPlatforms.Maci64   = platforms.Mac;
    end
    opts.SupportedPlatforms.MatlabOnline = true;

    matlab.addons.toolbox.packageToolbox(opts);
    fprintf('Toolbox built: %s\n', outputFile);
end

function platforms = interfacePlatforms(interfaceDir)
%INTERFACEPLATFORMS Report which platforms' compiled interfaces are present.

    extensions = struct('Win64', 'dll', 'Glnxa64', 'so', 'Mac', 'dylib');
    platforms = struct();
    for name = string(fieldnames(extensions))'
        platforms.(name) = isfile(fullfile(interfaceDir, ...
            "ctMatlabInterface." + extensions.(name)));
    end

    if ~any(cellfun(@(x) x, struct2cell(platforms)))
        error("ctPackageToolbox:NoInterface", ...
            ("No compiled interface in %s. Run buildtool buildInterface " + ...
             "before packaging."), interfaceDir);
    end
end

function repoRoot = inferRepoRoot()
%inferRepoRoot Infer the cantera_matlab repository root.

    thisFile = string(mfilename("fullpath"));
    buildUtilitiesDir = string(fileparts(thisFile));
    repoRoot = string(fileparts(buildUtilitiesDir));

    if ~isfolder(fullfile(repoRoot, "buildUtilities"))
        error("ctPackageToolbox:InvalidrepoRoot", ...
            "Could not infer release repository root from %s.", thisFile);
    end
end

function stageRoot = inferStageRoot(repoRoot)
%INFERSTAGEROOT Infer the toolbox staging directory.
    arguments
        repoRoot (1,1) string = inferRepoRoot()
    end

    stageRoot = fullfile(repoRoot, "TMP");
end

function validateStageRoot(stageRoot)
%VALIDATESTAGEROOT Validate staged toolbox layout.

    requiredDirs = [
        fullfile(stageRoot, "toolbox")
        fullfile(stageRoot, "samples")
        fullfile(stageRoot, "toolbox", "+ct")
    ];

    for i = 1:numel(requiredDirs)
        if ~isfolder(requiredDirs(i))
            error("ctPackageToolbox:InvalidStageRoot", ...
                "Required staged directory does not exist: %s\nRun ctStageToolbox or buildtool stage first.", ...
                requiredDirs(i));
        end
    end
end

function guidePath = stageGettingStartedGuide(repoRoot, stageRoot)
%STAGEGETTINGSTARTEDGUIDE Convert doc/GettingStarted.m to .mlx in the stage.
%
% The Getting Started guide is authored as a live-script .m (for version
% control) and converted at package time to doc/GettingStarted.mlx at the root
% of the stage, next to the toolbox, samples and data folders, so it can be
% registered as the toolbox Getting Started guide. Returns the staged .mlx path,
% or "" if the source is missing or conversion is unavailable (packaging then
% proceeds without a guide rather than failing).

    guidePath = "";

    guideSrc = fullfile(repoRoot, "doc", "GettingStarted.m");
    if ~isfile(guideSrc)
        warning("ctPackageToolbox:NoGettingStartedGuide", ...
                "Getting Started source not found at %s; packaging without a guide.", ...
                guideSrc);
        return
    end

    docDir = fullfile(stageRoot, "doc");
    if ~isfolder(docDir)
        mkdir(docDir);
    end
    guideDest = fullfile(docDir, "GettingStarted.mlx");
    try
        matlab.internal.liveeditor.openAndSave(char(guideSrc), char(guideDest));
    catch ME
        warning("ctPackageToolbox:GuideConversionFailed", ...
                ("Could not convert %s to .mlx (%s); packaging without a " + ...
                 "Getting Started guide."), guideSrc, ME.message);
        return
    end

    guidePath = guideDest;
    fprintf("Staged Getting Started guide: %s\n", guideDest);
end

function stageTutorials(repoRoot, stageRoot)
%STAGETUTORIALS Convert the tutorials in doc/tutorials to .mlx in the stage.
%
% Like the Getting Started guide, each tutorial is authored as a live-script .m
% and converted to a .mlx in doc/tutorials at the root of the stage. Every
% folder in the stage except data is on the toolbox's MATLAB path, so users can
% open a tutorial by name. A tutorial that cannot be converted is left out with
% a warning rather than failing the package.

    tutorialSrcs = dir(fullfile(repoRoot, "doc", "tutorials", "*.m"));
    if isempty(tutorialSrcs)
        return
    end

    tutorialDir = fullfile(stageRoot, "doc", "tutorials");
    if ~isfolder(tutorialDir)
        mkdir(tutorialDir);
    end

    for k = 1:numel(tutorialSrcs)
        src = fullfile(tutorialSrcs(k).folder, tutorialSrcs(k).name);
        [~, name] = fileparts(src);
        dest = fullfile(tutorialDir, name + ".mlx");
        try
            matlab.internal.liveeditor.openAndSave(char(src), char(dest));
        catch ME
            warning("ctPackageToolbox:TutorialConversionFailed", ...
                    "Could not convert %s to .mlx (%s); leaving it out.", ...
                    src, ME.message);
            continue
        end
        fprintf("Staged tutorial: %s\n", dest);
    end
end
