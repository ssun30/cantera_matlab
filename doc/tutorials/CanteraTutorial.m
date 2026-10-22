%% Cantera MATLAB Tutorial
% This tutorial introduces the main objects and functions of the Cantera
% MATLAB toolbox: creating a gas mixture, setting and reading its
% thermodynamic state, working with mechanism files, finding chemical
% equilibrium, and computing reaction rates. It follows the
% <https://cantera.org/stable/userguide/python-tutorial.html Cantera Python
% tutorial>, adapted to MATLAB.
%
% It assumes you have completed the *Getting Started* guide, in particular
% running |ct.install| once after installing the toolbox. Run the sections in
% order: each one builds on the previous ones.

%% Load Cantera
% Load the Cantera interface at the start of each MATLAB session. Cantera can
% run in one of two modes:
%
% * *Out-of-process* (the default for |ct.load|): Cantera runs in a separate
%   process. If Cantera crashes, MATLAB keeps running, and |ct.unload| can
%   unload Cantera, for example to load it again after updating the toolbox.
%   But every call to Cantera passes between the two processes, which takes
%   around a millisecond. Code that makes many calls, such as a loop over
%   species or reactions, can run hundreds of times slower than in-process.
% * *In-process*: Cantera runs inside MATLAB itself, and each call takes only
%   microseconds. But a crash inside Cantera also takes down MATLAB, and once
%   loaded in-process, Cantera stays loaded until you restart MATLAB.
%
% This tutorial makes many small calls, so it loads Cantera in-process. If
% Cantera is already loaded out-of-process in this session, for example by the
% Getting Started guide, |ct.load| unloads it first.

ct.load("inprocess")

%% Creating a Gas Mixture
% When using Cantera, the first thing you usually need is an object
% representing some phase of matter. Here, we create a gas mixture:

gas1 = ct.Solution('gri30.yaml');

%%
% To view the state of the mixture, enter the name of the object without a
% semicolon:

gas1

%%
% You have just created an object, |gas1|, that implements GRI-Mech 3.0, the
% 53-species, 325-reaction natural gas combustion mechanism developed by Smith
% et al. (1999).
%
% The |gas1| object has the properties you would expect for a gas mixture: a
% temperature, a pressure, species mole and mass fractions, and many more.
%
% The summary above shows that new objects created from |gri30.yaml| start out
% at 300 K and 1 atm, with a composition of only one species, hydrogen. There
% is nothing special about H2: it is the first species listed in the input
% file. In general, the first species listed initially has a mole fraction of
% 1, and all the others are zero.

%% Setting the State
% The state of the object can easily be changed. State properties that combine
% several quantities, such as |TP| (temperature and pressure), are set with a
% cell array:

gas1.TP = {1200, 101325};

%%
% This sets the temperature to 1200 K and the pressure to 101325 Pa (Cantera
% always uses SI units). The mixture now looks like this:

gas1

%% Molar and Mass Units
% Extensive properties such as enthalpy and entropy can be given per kmol or
% per kg. The |basis| property selects which one the object uses, both for
% the values it returns and for the values you set. A new object uses a molar
% basis. This tutorial uses values per unit mass, so switch to a mass basis:

gas1.basis = 'mass';

%%
% Thermodynamics generally requires that _two_ properties, in addition to the
% composition, are specified to fix the intensive state of a mixture. The
% state can be set using several combinations of two properties. The following
% are all equivalent:

gas1.TP = {1200, 101325};           % temperature, pressure
gas1.TD = {1200, 0.020473};         % temperature, density
gas1.HP = {1.3295e7, 101325};       % specific enthalpy, pressure
gas1.UV = {8.3457e6, 1/0.020473};   % specific internal energy, specific volume
gas1.SP = {85222, 101325};          % specific entropy, pressure
gas1.SV = {85222, 1/0.020473};      % specific entropy, specific volume

%%
% Properties can be read individually or together:

gas1.T

%%

gas1.H

%%

gas1.UV

%% Setting the Composition
% The composition can be set in terms of either mole fractions (|X|) or mass
% fractions (|Y|):

gas1.X = 'CH4:1, O2:2, N2:7.52'

%%
% The composition is given as a comma-separated list of |species:value| pairs.
% The values are relative mole numbers: Cantera normalizes them to produce the
% mole fractions. Mass fractions can be set the same way using |Y| instead of
% |X|.
%
% When the composition is computed, build the string from your variables, for
% example for a lean mixture with equivalence ratio |phi|:

phi = 0.8;
gas1.X = sprintf('CH4:1, O2:%g, N2:%g', 2/phi, 2*3.76/phi)

%%
% Alternatively, set the composition with a vector that has one entry for each
% species. Use |speciesIndex| to find where each species is stored:

x = zeros(1, gas1.nSpecies);
x(gas1.speciesIndex('CH4')) = 1;
x(gas1.speciesIndex('O2')) = 2/phi;
x(gas1.speciesIndex('N2')) = 2*3.76/phi;
gas1.X = x

%%
% For example, to set all 53 mole fractions to the same value:

gas1.X = ones(1, gas1.nSpecies)

%%
% or all the mass fractions:

gas1.Y = ones(1, gas1.nSpecies)

%%
% When the composition alone is changed, the temperature and density are held
% constant, so the pressure and other intensive properties change. The
% composition can also be set together with the intensive state:

gas1.TPX = {1200, 101325, 'CH4:1, O2:2, N2:7.52'}

%%
% To change one property while holding another constant, pass its current
% value. For example, to change the specific volume to 2.1 m^3/kg while holding
% the entropy constant:

gas1.SV = {gas1.S, 2.1}

%%
% Or to set the composition while holding the temperature and pressure
% constant:

gas1.TPX = {gas1.T, gas1.P, 'CH4:1.0, O2:0.5'}

%% Working with a Subset of Species
% Many properties of a |Solution| have one value for each species in the
% phase. To get the mole fractions of just the major species, in the order
% given, pass their names to |moleFraction|:

majorSpecies = {'CH4', 'O2', 'CO2', 'H2O', 'N2'};
xMajor = gas1.moleFraction(majorSpecies)

%%
% For other per-species properties, find the species' indices with
% |speciesIndex| and use them to index the property:

iMajor = gas1.speciesIndex(majorSpecies);
cpMajor = gas1.partialMolarCp(iMajor)
wdotMajor = gas1.netProdRates(iMajor)

%% Working with Mechanism Files
% So far, we created a gas mixture from |gri30.yaml|, one of the input files
% that ship with the toolbox. Others include mechanisms for high-temperature
% air, hydrogen/oxygen combustion, and several surface reaction mechanisms.
% Cantera looks for input files in its data directories, which you can list:

ct.dataDirectories

%%
% To use input files from another folder, add it to the search path for the
% current session with |ct.addDataDirectories|, for example:
%
%   ct.addDataDirectories(fullfile(userpath, 'my_data_files'))
%
% Cantera input files are plain text files and can be created with any text
% editor. See the
% <https://cantera.org/stable/userguide/input-tutorial.html input file
% tutorial> for more information.
%
% An input file may contain more than one phase, as well as interfaces
% (surfaces and edges) between phases. Here we import a surface phase from
% |diamond.yaml|; the bulk phases adjacent to it are imported along with it:

diamondSurf = ct.Interface('diamond.yaml', 'diamond_100');
diamondSurf.adjacentNames

%% Getting Help
% The classes and functions of the toolbox are documented in MATLAB's help
% system. To get help on a class, such as |ct.Solution|:

help ct.Solution

%%
% To list the properties and methods of an object, use |properties| and
% |methods|:
%
%   properties(gas1)
%   methods(gas1)
%
% To get help on a specific method, such as |speciesIndex|:

help ct.ThermoPhase.speciesIndex

%% Chemical Equilibrium
% To set a gas mixture to a state of chemical equilibrium, use the
% |equilibrate| method:

g = ct.Solution('gri30.yaml');
g.TPX = {300.0, ct.OneAtm, 'CH4:0.95, O2:2, N2:7.52'};
g.equilibrate('TP');
g

%%
% This sets the state of |g| to the state of chemical equilibrium, holding the
% temperature and pressure fixed. Alternatively, the specific enthalpy and
% pressure can be held fixed:

g.TPX = {300.0, ct.OneAtm, 'CH4:0.95, O2:2, N2:7.52'};
g.equilibrate('HP');
g

%%
% Other options are:
%
% * |'UV'|: fixed specific internal energy and specific volume
% * |'SV'|: fixed specific entropy and specific volume
% * |'SP'|: fixed specific entropy and pressure
%
% How can you tell if |equilibrate| has found the state of chemical
% equilibrium? One way is to verify that the net rates of progress of all
% reversible reactions are zero, relative to their forward rates:

rf = g.forwardRatesOfProgress;
rr = g.reverseRatesOfProgress;
isRev = arrayfun(@(i) g.isReversible(i), 1:g.nReactions);
check = isRev & rf ~= 0;
relativeImbalance = (rf(check) - rr(check)) ./ rf(check);
fprintf('Largest relative imbalance of %d reversible reactions: %.3g\n', ...
        nnz(check), max(abs(relativeImbalance)));

%%
% A very small value means that every reversible reaction is very nearly
% equilibrated, which only occurs if the gas is in chemical equilibrium.
%
% You might wonder how |equilibrate| works. It uses an element potential
% method, one of a class of _nonstoichiometric_ methods that reduce the
% problem to solving M nonlinear algebraic equations, where M is the number of
% elements (not species). _Stoichiometric_ methods, such as Gibbs
% minimization, require solving K nonlinear equations, where K is the number
% of species, usually much larger than M. Cantera solves the equations with a
% damped Newton method, together with steps that produce a good starting guess
% and a reasonably robust algorithm.

%% Chemical Kinetics
% |Solution| objects are also |Kinetics| objects. They provide the
% thermodynamic quantities associated with each reaction, reaction rates, and
% species creation and destruction rates, as well as the quantities that
% define each reaction, such as the rate constants and stoichiometric
% coefficients. These calculations are used throughout Cantera's reactor
% network and 1D flame models.
%
% Reactions are numbered from 1. Here is the equation of the third reaction:

g = ct.Solution('gri30.yaml');
g.reactionEquation(3)

%%
% The stoichiometric coefficients are available from |reactantStoichCoeffs|
% and |productStoichCoeffs| as matrices with one row per species and one
% column per reaction. Each coefficient takes one call to Cantera, so request
% only the species and reactions you need rather than all of them. For
% example, to find just the reactions that convert CO into CO2:

iCO = g.speciesIndex('CO');
iCO2 = g.speciesIndex('CO2');
allReactions = 1:g.nReactions;
nuReactants = g.reactantStoichCoeffs(iCO, allReactions);
nuProducts = g.productStoichCoeffs(iCO2, allReactions);
II = find(nuReactants(iCO, :) > 0 & nuProducts(iCO2, :) > 0);
for i = II
    disp(g.reactionEquation(i))
end

%%
% (We should also include reactions written with CO2 as a reactant and CO as a
% product, but for this example, we stick to this smaller set.) Now, set the
% composition to an interesting equilibrium state:

g.TPX = {300, 101325, 'CH4:0.6, O2:1.0, N2:3.76'};
g.equilibrate('HP');
g

%%
% The net rates of progress of these reactions, in kmol/m^3/s, are essentially
% zero, as expected at equilibrium:

ropNet = g.netRatesOfProgress;
for i = II
    fprintf('%-26s %11.4g\n', g.reactionEquation(i), ropNet(i));
end

%%
% Now, see what happens if we decrease the temperature of the mixture by
% 100 K:

g.TP = {g.T - 100, g.P};
ropNet = g.netRatesOfProgress;
for i = II
    fprintf('%-26s %11.4g\n', g.reactionEquation(i), ropNet(i));
end

%%
% All of the rates are positive, favoring the formation of CO2 from CO, with
% the third reaction, |CO + OH <=> CO2 + H|, proceeding the fastest. The
% enthalpy change of each of these reactions, in J/kmol, is:

dH = g.deltaEnthalpy;
for i = II
    fprintf('%-26s %11.4g\n', g.reactionEquation(i), dH(i));
end

%%
% The change is negative in each case, indicating a net release of thermal
% energy. The total heat release rate, in W/m^3, can be computed either from
% the reaction rates:

sum(ropNet .* dH)

%%
% or from the species production rates:

sum(g.netProdRates .* g.partialMolarEnthalpies)

%%
% The contribution from just the selected reactions is:

sum(ropNet(II) .* dH(II))

%%
% or about 16% of the total heat release rate.

%% Next Steps
% Congratulations! You have finished the Cantera MATLAB tutorial and should be
% ready to start using Cantera on your own.
%
% * The |LithiumIonBattery| tutorial applies Cantera to a lithium-ion battery,
%   computing its open-circuit voltage and discharge curves. Open it with
%   |open LithiumIonBattery|.
% * The example scripts in the |samples| folder of the toolbox show complete
%   simulations, including reactor networks and flames.
% * The <https://cantera.org/stable/userguide/index.html Cantera User Guide>
%   covers intermediate and advanced topics; its examples use Python, but the
%   concepts carry over to MATLAB.
