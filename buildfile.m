function plan = buildfile()
    plan = buildplan(localfunctions);

    plan.DefaultTasks = ["test", "package"];

    % buildCanteraLibrary builds from CANTERA_ROOT, but runs the build scripts
    % from the staged copy of Cantera's interfaces/matlab/buildUtilities.
    plan("buildCanteraLibrary").Dependencies = "stage";
    plan("buildInterface").Dependencies = ["stage", "buildCanteraLibrary"];
    plan("test").Dependencies = "buildInterface";
    % The package includes the compiled interface, so it comes last.
    plan("package").Dependencies = "buildInterface";
end

function stageTask(context)
    root = string(context.Plan.RootFolder);

    withBuildUtilities(root, @() ctStageToolbox());
end

function packageTask(context)
    root = string(context.Plan.RootFolder);

    withBuildUtilities(root, @() ctPackageToolbox());
end

function buildCanteraLibraryTask(context)
    root = string(context.Plan.RootFolder);

    withBuildUtilities(root, @() ctBuildCanteraLibrary());
end

function buildInterfaceTask(context)
    root = string(context.Plan.RootFolder);

    withBuildUtilities(root, @() ctBuildInterface());
end

function testTask(context)
    root = string(context.Plan.RootFolder);

    withBuildUtilities(root, @() ctTestToolbox());
end

function withBuildUtilities(root, taskFcn)
    oldPath = addpath(fullfile(root, "buildUtilities"));
    cleanupObj = onCleanup(@() path(oldPath));
    taskFcn();
end
