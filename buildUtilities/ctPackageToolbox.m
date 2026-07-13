function ctPackageToolbox(options)
    arguments
        options.RepoRoot (1,1) string = ""
        options.StageRoot (1,1) string = ""
        options.Version (1,1) string = string(getenv("TOOLBOX_VERSION"))
        options.RepoSlug (1,1) string = ""
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

    % Collect packaged files
    files = dir(fullfile(options.StageRoot, '**', '*'));
    files = files(~[files.isdir]);
    allFiles = fullfile({files.folder}, {files.name})';

    % Get relative MATLAB paths from actual packaged file locations
    matlabPaths = strsplit(genpath(options.StageRoot), pathsep);
    matlabPaths = matlabPaths(~cellfun(@isempty, matlabPaths));

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
    % opts.ToolboxGettingStartedGuide      = guidePath;
    opts.ToolboxImageFile                = iconFile;
    opts.MinimumMatlabRelease            = 'R2022b';
    opts.OutputFile                      = outputFile;
    opts.SupportedPlatforms.Win64        = true;
    opts.SupportedPlatforms.Glnxa64      = true;
    opts.SupportedPlatforms.Maci64       = true;
    opts.SupportedPlatforms.MatlabOnline = false;

    % Download the platform-specific compiled interface on install.
    % The clib interface (plus the bundled cantera_shared runtime) is too
    % platform-specific to embed in a single cross-platform .mltbx, so it is
    % published as per-OS release assets and fetched by MATLAB at install time
    % based on the user's platform. Resolve the publishing repo from
    % GITHUB_REPOSITORY (set automatically in CI) with a fallback for local
    % packaging.
    % TEMP (pre-alpha): fallback slug points at the fork; drop it once the
    % toolbox repo is finalized (see CANTERA_REPO note in release.yml).
    repoSlug = options.RepoSlug;
    if repoSlug == ""
        repoSlug = strip(string(getenv("GITHUB_REPOSITORY")));
    end
    if repoSlug == ""
        repoSlug = "ssun30/cantera_matlab";
    end

    relBase = "https://github.com/" + repoSlug + "/releases/download/v" + ver;
    licenseURL = "https://raw.githubusercontent.com/" + repoSlug + "/v" + ver + "/LICENSE";

    % Map release asset labels (linux/windows/macos) to MATLAB platform keys.
    opts.RequiredAdditionalSoftware = [
        struct("Name", "ctMatlabInterface", "Platform", "win64", ...
               "DownloadURL", relBase + "/cantera-matlab-interface-windows.zip", ...
               "LicenseURL", licenseURL)
        struct("Name", "ctMatlabInterface", "Platform", "glnxa64", ...
               "DownloadURL", relBase + "/cantera-matlab-interface-linux.zip", ...
               "LicenseURL", licenseURL)
        struct("Name", "ctMatlabInterface", "Platform", "mac", ...
               "DownloadURL", relBase + "/cantera-matlab-interface-macos.zip", ...
               "LicenseURL", licenseURL)
    ];

    % Package the toolbox
    try
        matlab.addons.toolbox.packageToolbox(opts);
        fprintf('✅ Toolbox built successfully!\n');
    catch ME
        fprintf('❌ Toolbox build failed: %s\n', ME.message);
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

% function guidePath = stageTutorialsAsLiveScripts(srcTutorialDir, destTutorialDir)
%     % Convert all .m tutorials into .mlx files. Returns the staged path to
%     % GettingStartedGuide.mlx.

%     if ~isfolder(destTutorialDir)
%         mkdir(destTutorialDir);
%     end

%     tutorialFiles = dir(fullfile(srcTutorialDir, '*.m'));
%     guidePath = '';

%     for k = 1:numel(tutorialFiles)
%         srcFile = fullfile(tutorialFiles(k).folder, tutorialFiles(k).name);
%         [~, baseName] = fileparts(tutorialFiles(k).name);
%         destFile = fullfile(destTutorialDir, [baseName, '.mlx']);

%         try
%             matlab.internal.liveeditor.openAndSave(srcFile, destFile);
%         catch ME
%             error('Failed to convert "%s" to live script: %s', srcFile, ME.message);
%         end

%         if strcmp(baseName, 'GettingStartedGuide')
%             guidePath = destFile;
%         end
%     end
% end
