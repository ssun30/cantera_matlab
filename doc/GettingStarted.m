%% Getting Started with the Cantera MATLAB Toolbox
% This guide takes you from a fresh install to running your first Cantera
% simulation in MATLAB. It assumes *no prior experience* with Cantera or
% GitHub.
%
% *What this toolbox is:* a MATLAB interface to Cantera, the open-source
% toolkit for chemical kinetics, thermodynamics, and transport.
%
% *Everything you need is included.* The toolbox ships a self-contained
% Cantera library for your platform and Cantera's standard data files
% (reaction mechanisms such as |gri30.yaml|). You do *not* need to install
% Cantera, conda, or a compiler.
%
% Work through the steps in order. You only need to do Step 1 once.

%% Step 1 - Finish the installation (once)
% Run the line below (place your cursor on it and press Ctrl+Enter, or
% Cmd+Enter on macOS):

ct.install

%%
% This registers the bundled data files and checks that Cantera loads. MATLAB
% remembers the result, so you never need to run it again; running it again
% does nothing.

%% Step 2 - Load Cantera
% Load the interface at the start of each MATLAB session:

ct.load

%%
% The data folders Cantera searches for mechanism files are listed by:

ct.dataDirectories

%% Step 3 - Run a minimal example
% Compute the adiabatic flame temperature of a stoichiometric methane/air
% mixture. This creates a gas mixture from the GRI-Mech 3.0 mechanism, sets its
% initial state, and finds chemical equilibrium at constant enthalpy and
% pressure.

gas = ct.Solution("gri30.yaml");
gas.TPX = {300, ct.OneAtm, "CH4:1, O2:2, N2:7.52"};
gas.equilibrate("HP");

fprintf("Adiabatic flame temperature: %.1f K\n", gas.T);

%% Step 4 - When you are finished
% Unload the interface to free resources (optional):

ct.unload

%% Next Steps
% The toolbox includes a tutorial that goes further: setting the thermodynamic
% state, working with mechanism files, chemical equilibrium, and reaction
% rates. Open it with:
%
%   open CanteraTutorial
%
% A second tutorial applies Cantera to a lithium-ion battery, computing its
% open-circuit voltage and discharge curves:
%
%   open LithiumIonBattery
%
% The example scripts in the |samples| folder of the toolbox show complete
% simulations, including reactor networks and flames.

%% Uninstalling
% Run |ct.uninstall| *before* removing the toolbox in the Add-On Manager. It
% clears the settings saved by |ct.install|, and it is part of the toolbox, so
% it is no longer available once the toolbox is removed:
%
%   % ct.uninstall

%% Troubleshooting
% *The Cantera MATLAB interface was not found* (from |ct.load|) - the
% installed toolbox has no compiled interface for your platform. Reinstall
% the toolbox; if the error persists, this release does not support your
% platform.
%
% *Error: could not find input file 'gri30.yaml'* (or similar) - the data
% folder is not registered. Run |ct.install(Force=true)| to set it up again;
% |ct.dataDirectories| shows the folders currently searched.
%
% *Nothing happens / functions are not found* - Make sure the toolbox installed
% correctly (MATLAB Home tab > Add-Ons > Manage Add-Ons).
