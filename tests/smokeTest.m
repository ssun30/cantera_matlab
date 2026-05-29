classdef smokeTest < matlab.unittest.TestCase
    %SMOKETEST Smoke tests for the packaged Cantera MATLAB toolbox.

    properties
        ToolboxRoot string
        ExpectedVersion string
    end

    methods (TestClassSetup)
        function resolvePaths(testCase)
            testCase.ToolboxRoot = string(getenv("CANTERA_MATLAB_TOOLBOX_ROOT"));
            testCase.ExpectedVersion = inferExpectedVersion();

            testCase.assertNotEmpty(testCase.ToolboxRoot, ...
                "CANTERA_MATLAB_TOOLBOX_ROOT must be set before running smokeTest.");

            testCase.assertTrue(isfolder(testCase.ToolboxRoot), ...
                "Toolbox root does not exist: " + testCase.ToolboxRoot);

            testCase.assertTrue(isfolder(fullfile(testCase.ToolboxRoot, "+ct")), ...
                "Toolbox root does not contain +ct: " + testCase.ToolboxRoot);

            testCase.assertTrue(isfolder(fullfile(testCase.ToolboxRoot, "+ct", "+impl", "ctMatlab")), ...
                "Built interface folder +ct/ctMatlab does not exist. Run ctBuildInterface first.");

            oldPath = path;
            testCase.addTeardown(@() path(oldPath));
            addpath(genpath(testCase.ToolboxRoot));
            addpath(fullfile(testCase.ToolboxRoot, "+ct", "+impl", "ctMatlab"));
        end
    end

    methods (TestMethodSetup)
        function unloadBeforeEachTest(~)
            safeUnloadCantera();
        end
    end

    methods (TestClassTeardown)
        function unloadAfterTests(~)
            safeUnloadCantera();
        end
    end

    methods (Test)
        function testLoadUnload(testCase)
            ct.load();
            ct.unload();

            testCase.verifyTrue(true);
        end

        function testVersion(testCase)
            ct.load();

            actualVersion = string(ct.version());

            testCase.verifyNotEmpty(actualVersion, ...
                "ct.version returned an empty value.");

            if testCase.ExpectedVersion ~= ""
                testCase.verifyTrue( ...
                    startsWith(actualVersion, testCase.ExpectedVersion), ...
                    "Expected ct.version to start with '" + ...
                    testCase.ExpectedVersion + "', but got '" + ...
                    actualVersion + "'.");
            end
        end

        function testCreateSolution(testCase)
            ct.load();

            gas = ct.Solution("gri30.yaml");

            testCase.verifyClass(gas, "ct.Solution");
        end
    end
end

function version = inferExpectedVersion()
    version = string(getenv("TOOLBOX_VERSION"));

    if version == ""
        version = string(getenv("GITHUB_REF_NAME"));
    end

    version = strip(version);

    if startsWith(version, "v")
        version = extractAfter(version, 1);
    end
end

function safeUnloadCantera()
    try
        ct.unload();
    catch
    end
end
