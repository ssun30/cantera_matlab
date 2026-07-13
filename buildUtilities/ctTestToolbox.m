function results = ctTestToolbox(options)
%CTTESTTOOLBOX Run smoke tests for the staged Cantera MATLAB toolbox.
%
% This utility is intentionally limited to release-repository smoke tests.
% It does not run the full Cantera MATLAB unit test suite from the main
% Cantera repository.

    arguments
        options.RepoRoot (1,1) string = ""
        options.StageRoot (1,1) string = ""
        options.Verbose (1,1) logical = true
    end

    if options.RepoRoot == ""
        options.RepoRoot = inferRepoRoot();
    end

    if options.StageRoot == ""
        options.StageRoot = inferStageRoot(options.RepoRoot);
    end

    toolboxRoot = fullfile(options.StageRoot, "toolbox");

    validateTestInputs(options.RepoRoot, toolboxRoot);

    testFile = fullfile(options.RepoRoot, "tests", "smokeTest.m");
    toolboxRoot = fullfile(options.StageRoot, "toolbox");

    setenv("CANTERA_MATLAB_TOOLBOX_ROOT", toolboxRoot);

    if options.Verbose
        fprintf("Running Cantera MATLAB toolbox smoke tests...\n");
        fprintf("Toolbox root: %s\n", toolboxRoot);
        fprintf("Test file:    %s\n", testFile);
    end

    suite = testsuite(testFile);
    results = run(suite);

    disp(table(results));

    assertSuccess(results);
end

function repoRoot = inferRepoRoot()
%INFERREPOROOT Infer the cantera_matlab repository root.

    thisFile = string(mfilename("fullpath"));
    buildUtilitiesDir = string(fileparts(thisFile));
    repoRoot = string(fileparts(buildUtilitiesDir));

    if ~isfolder(fullfile(repoRoot, "buildUtilities"))
        error("ctTestToolbox:InvalidRepoRoot", ...
            "Could not infer repository root from %s.", thisFile);
    end
end

function stageRoot = inferStageRoot(repoRoot)
%INFERSTAGEROOT Infer the toolbox staging directory.

    stageRoot = fullfile(repoRoot, "TMP");
end

function validateTestInputs(repoRoot, toolboxRoot)
    requiredDirs = [
        toolboxRoot
        fullfile(toolboxRoot, "+ct")
        fullfile(toolboxRoot, "+ct", "+impl", "ctMatlab")
    ];

    for i = 1:numel(requiredDirs)
        if ~isfolder(requiredDirs(i))
            error("ctTestToolbox:InvalidSmokeTestInput", ...
                "Required directory does not exist: %s", requiredDirs(i));
        end
    end

    testFile = fullfile(repoRoot, "tests", "smokeTest.m");

    if ~isfile(testFile)
        error("ctTestToolbox:MissingSmokeTest", ...
            "Smoke test file does not exist: %s", testFile);
    end
end
