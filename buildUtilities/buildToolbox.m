function buildToolbox(arg)
    arguments
        arg.version (1,:) char = '0.0.0';
        arg.ctRoot (1,:) char = mfilename('fullpath');
    end

    ver = regexp(arg.version, '\d+\.\d+\.\d+', 'match', 'once');
    if isempty(ver)
        error('Could not parse semantic version from arg.version="%s"', arg.version);
    end
    fprintf('Building toolbox version: %s\n', ver);

    thisDir = fileparts(mfilename('fullpath'));

    % Read the UUID for the toolbox
    thisDir = fileparts(mfilename('fullpath'));

    uuidFile = fullfile(thisDir, 'Cantera_MATLAB_Toolbox.uuid');
    if isfile(uuidFile)
        guid = strtrim(fileread(uuidFile));
        fprintf('The unique identifier for the toolbox is: %s\n', guid);
    else
        error('A unique identifier for the toolbox does not exist! Expected at: %s', uuidFile);
    end

    % Define output file
    outputDir = fullfile(thisDir, '..', 'release');
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    outputFile = fullfile(outputDir, ['Cantera_MATLAB_Toolbox_', ver, '.mltbx']);

    % Create temporary folder for reorganizing and faster execution
    tmpDir = fullfile(arg.ctRoot, 'build', 'mltbx');
    if isfolder(tmpDir)
        rmdir(tmpDir, 's');
    end
    mkdir(tmpDir);

    mapping = {
        'interfaces/matlab', 'toolbox';
        'samples/matlab', 'toolbox/samples';
        'data', 'toolbox/data'
        };

    % Convert tutorials to live scripts and stage them in the temporary folder
    % disabled until we add tutorials to the Matlab toolbox
    % srcTutorialDir = fullfile(arg.ctRoot, 'samples', 'matlab', 'tutorials');
    % destTutorialDir = fullfile(tmpDir, 'toolbox', 'tutorials');
    % guidePath = stageTutorialsAsLiveScripts(srcTutorialDir, destTutorialDir);

    % Move all files to temporary folder
    for i = 1:size(mapping, 1)
        src = fullfile(arg.ctRoot, mapping{i, 1});
        dest = fullfile(tmpDir, mapping{i, 2});
        copyfile(src, dest);
    end

    % Remove folders that should not be packaged
    % The Packaging folder contains files related to building the toolbox that are not
    % needed in the distributed version.
    % The ctMatlab folder contains library and interface files that are built
    % separately and should not be included in the toolbox.

    excludeDirs = {
        fullfile(tmpDir, 'toolbox', '+ct', 'ctMatlab')
        };

    for i = 1:numel(excludeDirs)
        if isfolder(excludeDirs{i})
            rmdir(excludeDirs{i}, 's');
        end
    end

    % Remove files that should not be packaged
    % Readme is not necessary in the distributed toolbox, and the .m files in the
    % tutorials folder have been converted to .mlx live scripts.

    % excludeFiles = {
    %                 fullfile(tmpDir, 'toolbox', 'tutorials', '*.m')
    % };
    % delete(excludeFiles{:});

    % Collect packaged files
    files = dir(fullfile(tmpDir, '**', '*'));
    files = files(~[files.isdir]);
    allFiles = fullfile({files.folder}, {files.name})';

    % Get relative MATLAB paths from actual packaged file locations
    matlabPaths = strsplit(genpath(tmpDir), pathsep);
    matlabPaths = matlabPaths(~cellfun(@isempty, matlabPaths));

    % Get path to the icon file
    iconFile = fullfile(arg.ctRoot, 'doc', 'sphinx', '_static', ...
                        'images', 'cantera-logo.png');

    % Set up toolbox options
    opts = matlab.addons.toolbox.ToolboxOptions(tmpDir, guid);
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

    % Package the toolbox
    try
        matlab.addons.toolbox.packageToolbox(opts);
        fprintf('✅ Toolbox built successfully!\n');
    catch ME
        fprintf('❌ Toolbox build failed: %s\n', ME.message);
    end

    % Remove the temporary folder
    rmdir(tmpDir, 's');
end

function guidePath = stageTutorialsAsLiveScripts(srcTutorialDir, destTutorialDir)
    % Convert all .m tutorials into .mlx files. Returns the staged path to
    % GettingStartedGuide.mlx.

    if ~isfolder(destTutorialDir)
        mkdir(destTutorialDir);
    end

    tutorialFiles = dir(fullfile(srcTutorialDir, '*.m'));
    guidePath = '';

    for k = 1:numel(tutorialFiles)
        srcFile = fullfile(tutorialFiles(k).folder, tutorialFiles(k).name);
        [~, baseName] = fileparts(tutorialFiles(k).name);
        destFile = fullfile(destTutorialDir, [baseName, '.mlx']);

        try
            matlab.internal.liveeditor.openAndSave(srcFile, destFile);
        catch ME
            error('Failed to convert "%s" to live script: %s', srcFile, ME.message);
        end

        if strcmp(baseName, 'GettingStartedGuide')
            guidePath = destFile;
        end
    end
end
