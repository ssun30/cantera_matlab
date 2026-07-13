function plan = buildfile()
    plan = buildplan(localfunctions);

    plan.DefaultTasks = "test";

    plan("package").Dependencies = "stage";
    plan("buildInterface").Dependencies = "package";
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
