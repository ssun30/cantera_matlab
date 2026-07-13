%% Getting Started with the Cantera MATLAB Toolbox
% This guide takes you from a fresh install to running your first Cantera
% simulation in MATLAB. It assumes *no prior experience* with Cantera or
% GitHub.
%
% *What this toolbox is:* a MATLAB interface to Cantera, the open-source
% toolkit for chemical kinetics, thermodynamics, and transport.
%
% *What this toolbox is NOT:* Cantera itself. The Cantera library and its data
% files (reaction mechanisms such as |gri30.yaml|) are *not* shipped inside this
% toolbox and must be installed separately. Step 1 covers that.
%
% Work through the steps in order. You only need to do Steps 1-3 once.

%% Step 1 - Install Cantera (required; not included with this toolbox)
% Cantera must be installed on your computer separately. The easiest
% cross-platform way is with *conda* (via Miniforge), which installs both the
% Cantera library and the mechanism data files this toolbox needs.
%
% # Install Miniforge: <https://conda-forge.org/download/>
% # Open a terminal - on Windows use the "Miniforge Prompt" from the Start
%   menu; on macOS/Linux use your normal terminal - and run:
%
%     conda create -n cantera -c conda-forge cantera
%
% # Note where the environment was created - you will point the toolbox at its
%   *library folder* in Step 3. Typical locations:
%
%     Windows:      C:\Users\<you>\miniforge3\envs\cantera\Library\bin
%     macOS/Linux:  ~/miniforge3/envs/cantera/lib
%
% (If you already have Cantera installed another way, you can use that
% installation's library folder instead.)

%% Step 2 - Put the downloaded interface library on the MATLAB path
% When you installed this toolbox (the |.mltbx| file), MATLAB downloaded the
% compiled interface library for your platform into an *AdditionalSoftware*
% folder that sits next to the toolbox under MATLAB's Add-Ons directory.
%
% Find its exact location by running this line (place your cursor on it and
% press Ctrl+Enter, or Cmd+Enter on macOS):

CanteraMATLABToolbox.getInstallationLocation("ctMatlabInterface")

%%
% In a file browser, open that folder, then *move* the |ctMatlab| folder inside
% it into the installed toolbox so it ends up here:
%
%     Cantera MATLAB Toolbox/toolbox/+ct/+impl/ctMatlab/
%
% Finally, add that folder to the MATLAB path and save it so MATLAB remembers
% it next time. Edit the path below to match where you moved the folder, then
% run these two lines (delete the leading % to activate them):
%
%   % addpath("<...>/Cantera MATLAB Toolbox/toolbox/+ct/+impl/ctMatlab")
%   % savepath
%
% See the toolbox README for more detail on this step.

%% Step 3 - Load Cantera
% Load the interface:

ct.load

%%
% *The first time* you run |ct.load| on a desktop MATLAB, a dialog asks you to
% select your Cantera *library folder* - the folder from Step 1 that contains
% the Cantera shared library:
%
%     Windows:      ...\miniforge3\envs\cantera\Library\bin   (has cantera_shared.dll)
%     macOS/Linux:  ...\miniforge3/envs/cantera/lib           (has libcantera_shared.*)
%
% Cantera remembers this choice for future sessions, puts the library on the
% loader path, and automatically finds the matching data files (mechanisms like
% |gri30.yaml|). You normally only pick it once, and you do *not* need to launch
% MATLAB from an activated conda environment.
%
% *Prefer not to use the dialog?* Configure it once, non-interactively, before
% calling |ct.load| (edit the path to your library folder):
%
%   % ct.configureCanteraDirectories("C:\Users\<you>\miniforge3\envs\cantera\Library\bin")
%
% Review the current configuration at any time with |ct.configureCanteraDirectories|
% (no arguments), and see the data directories Cantera is searching with:

ct.dataDirectories

%% Step 4 - Run a minimal example
% Compute the adiabatic flame temperature of a stoichiometric methane/air
% mixture. This creates a gas mixture from the GRI-Mech 3.0 mechanism, sets its
% initial state, and finds chemical equilibrium at constant enthalpy and
% pressure.

gas = ct.Solution("gri30.yaml");
gas.TPX = {300, ct.OneAtm, "CH4:1, O2:2, N2:7.52"};
gas.equilibrate("HP");

fprintf("Adiabatic flame temperature: %.1f K\n", gas.T);

%% Step 5 - When you are finished
% Unload the interface to free resources (optional):

ct.unload

%% Troubleshooting
% *Unable to locate namespace 'clib.ctMatlab'* - Step 2 is not complete: the
% |ctMatlab| folder is not on the saved MATLAB path. Re-check the |addpath| /
% |savepath| lines in Step 2.
%
% *Error: could not find input file 'gri30.yaml'* (or similar) - Cantera cannot
% find its data files, usually because the library folder selected in Step 3
% was wrong or has no matching data. Re-point it with
% |ct.configureCanteraDirectories("<library folder>")| and run |ct.load| again;
% |ct.dataDirectories| shows the folders currently searched.
%
% *Nothing happens / functions are not found* - Make sure the toolbox installed
% correctly (MATLAB Home tab > Add-Ons > Manage Add-Ons) and that you have
% restarted MATLAB after Step 2.
