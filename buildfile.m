function plan = buildfile()
    plan = buildplan(localfunctions);

    plan.DefaultTasks = "test";

    plan("package").Dependencies = "stage";
    % buildCanteraLibrary builds from CANTERA_ROOT rather than the staged tree,
    % so it is a second root task; buildInterface is where the two meet.
    plan("buildInterface").Dependencies = ["package", "buildCanteraLibrary"];
    plan("test").Dependencies = "buildInterface";
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
