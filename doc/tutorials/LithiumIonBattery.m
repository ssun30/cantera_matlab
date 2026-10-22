%% Lithium-Ion Battery Discharge Curves
% This example computes the voltage of a lithium-ion cell with a graphite
% anode and a lithium cobalt oxide (LiCoO2, or LCO) cathode, the active
% materials of many commercial batteries. Cantera evaluates the
% thermodynamics of the electrode materials and the kinetics of the
% charge-transfer reactions at their surfaces; MATLAB solves for the cell
% voltage and plots the results. Starting from the open-circuit voltage, the
% example builds up to discharge curves at different currents.
%
% The example is based on the Cantera lithium-ion battery examples for
% <https://cantera.org/stable/examples/python/kinetics/lithium_ion_battery.html Python>,
% which computes the open-circuit voltage in two ways, and
% <https://cantera.org/stable/examples/matlab/lithium_ion_battery.html MATLAB>,
% which computes a discharge curve at one current. Here, the discharge curve
% is extended to several currents. The model and the thermodynamic data are
% described in detail in:
%
% M. Mayur, S. C. DeCaluwe, B. L. Kee, W. G. Bessler, "Modeling and
% simulation of the thermodynamics of lithium-ion battery intercalation
% materials in the open-source software Cantera," _Electrochim. Acta_ 323,
% 134797 (2019), <https://doi.org/10.1016/j.electacta.2019.134797 doi:10.1016/j.electacta.2019.134797>.
%
% It assumes you have completed the *Getting Started* guide. The
% |CanteraTutorial| live script introduces the Cantera objects used here.

%% The Cell Model
% The cell is represented by one particle of each electrode material,
% connected by a liquid electrolyte:
%
% * The *anode* is graphite, which stores lithium between its carbon layers.
%   It is modeled as a solution of lithium |Li[anode]| and vacant sites
%   |V[anode]|.
% * The *cathode* is LCO, modeled in the same way with |Li[cathode]| and
%   |V[cathode]|.
% * The *electrolyte* is 1 M LiPF6 in a mixture of ethylene carbonate and
%   propylene carbonate. It carries lithium ions between the electrodes and
%   is modeled as a resistor.
%
% At the surface of each electrode, a charge-transfer reaction moves lithium
% between the electrolyte and the electrode:
%
% $$\mathrm{Li^+_{(elyt)} + V_{(elde)} + e^- \rightleftharpoons Li_{(elde)}}$$
%
% During discharge, this reaction runs backwards at the anode, releasing
% lithium ions into the electrolyte and electrons into the external circuit,
% and forwards at the cathode, consuming them.
%
% The thermodynamic properties of the electrode materials come from measured
% open-circuit voltages of half cells, tabulated as the molar enthalpy and
% entropy of lithium as functions of its mole fraction. Cantera's
% |binary-solution-tabulated| thermodynamic model interpolates these tables.
%
% The model assumes that the composition of each particle is uniform, that
% the electrolyte has a constant composition and resistance, and that the
% cell is at a uniform temperature. Each result below is therefore a steady
% state at a given state of charge; the model leaves out the transport
% limitations that further reduce the voltage at high currents.

%% Load Cantera
% Solving for the cell voltage takes thousands of calls to Cantera, so this
% example loads Cantera in-process, where each call takes microseconds (see
% |CanteraTutorial| for the difference between the two modes). If Cantera is
% already loaded out-of-process in this session, |ct.load| unloads it first.

ct.load("inprocess")

%% Import the Phases
% The input file |lithium_ion_battery.yaml| defines the two electrode
% materials, the electrolyte, a phase of electrons, and the two interfaces
% where the electrodes meet the electrolyte. The electron phase is the source
% and sink of electrons at each electrode, and its electric potential is that
% of the electrode.

inputFile = 'lithium_ion_battery.yaml';
anode = ct.Solution(inputFile, 'anode');
cathode = ct.Solution(inputFile, 'cathode');
elde = ct.Solution(inputFile, 'electron');
elyt = ct.Solution(inputFile, 'electrolyte');
anodeInterface = ct.Interface(inputFile, 'edge_anode_electrolyte', ...
                              anode, elde, elyt);
cathodeInterface = ct.Interface(inputFile, 'edge_cathode_electrolyte', ...
                                cathode, elde, elyt);

%%
% Passing the bulk phases to |ct.Interface| makes each interface use these
% objects as its adjacent phases. Changing the state of |anode|, for example,
% then changes the reaction rates at |anodeInterface|. Both interfaces share
% the electron and electrolyte phases; each calculation below sets their
% electric potentials before evaluating a rate.
%
% Each interface has one reaction, the charge-transfer reaction:

anodeInterface.reactionEquation(1)
cathodeInterface.reactionEquation(1)

%%
% The species of each electrode are lithium and vacancies, in that order:

anode.speciesNames

%% Operating Conditions and Cell Properties
% Cantera uses SI units throughout.

T = 293;            % [K] temperature
P = ct.OneAtm;      % [Pa] pressure
R_elyt = 0.0384;    % [Ohm] ionic resistance of the electrolyte
S_an = 0.7824;      % [m^2] total active surface area of the anode
S_ca = 1.1167;      % [m^2] total active surface area of the cathode
F = ct.FaradayConstant;  % [C/kmol]

phases = {anode, cathode, elde, elyt, anodeInterface, cathodeInterface};
for k = 1:numel(phases)
    phases{k}.TP = {T, P};
end

%% Electrode Balancing
% The state of charge (SOC) is the fraction of the cell's capacity that is
% currently stored, from 0 (fully discharged) to 1 (fully charged). Charging
% moves lithium from the cathode to the anode. The _balancing_ of the
% electrodes relates the SOC to the lithium mole fraction in each active
% material, which changes linearly between these limits:

X_Li_an_0 = 0.01;   % [-] anode Li mole fraction at SOC = 0
X_Li_an_1 = 0.75;   % [-] anode Li mole fraction at SOC = 1
X_Li_ca_0 = 0.99;   % [-] cathode Li mole fraction at SOC = 0
X_Li_ca_1 = 0.49;   % [-] cathode Li mole fraction at SOC = 1

SOC = linspace(0, 1, 101);
X_Li_an = X_Li_an_0 + (X_Li_an_1 - X_Li_an_0) * SOC;
X_Li_ca = X_Li_ca_0 + (X_Li_ca_1 - X_Li_ca_0) * SOC;

%% Open-Circuit Voltage from Thermodynamics
% When no current flows, each charge-transfer reaction is in equilibrium,
% and the net change in electrochemical potential across the reaction is
% zero:
%
% $$\sum_k \nu_k \tilde{\mu}_k = 0, \qquad \tilde{\mu}_k = \mu_k + z_k F \Phi_k$$
%
% where $\mu_k$ is the chemical potential of species $k$, $\nu_k$ its net
% stoichiometric coefficient, $z_k$ its charge, and $\Phi_k$ the electric
% potential of its phase. Solving for the potential difference between the
% electrode and the electrolyte at equilibrium gives:
%
% $$\Delta\Phi_\mathrm{eq} = \left(\Phi_\mathrm{elde} - \Phi_\mathrm{elyt}\right)_\mathrm{eq} = -\frac{\Delta g_\mathrm{rxn}}{n F}$$
%
% where $\Delta g_\mathrm{rxn} = \sum_k \nu_k \mu_k$ is the Gibbs energy change
% of the reaction, available from the |deltaGibbs| property of the interface,
% and $n = 1$ is the number of electrons transferred. The open-circuit voltage
% (OCV) of the cell is the difference between the equilibrium potentials of
% its two electrodes:
%
% $$E_\mathrm{OCV} = \Delta\Phi_\mathrm{eq,ca} - \Delta\Phi_\mathrm{eq,an}$$

tic
dPhi_eq_an = zeros(size(SOC));
dPhi_eq_ca = zeros(size(SOC));
for i = 1:numel(SOC)
    anode.X = [X_Li_an(i), 1 - X_Li_an(i)];
    cathode.X = [X_Li_ca(i), 1 - X_Li_ca(i)];
    dPhi_eq_an(i) = -anodeInterface.deltaGibbs / F;
    dPhi_eq_ca(i) = -cathodeInterface.deltaGibbs / F;
end
E_ocv = dPhi_eq_ca - dPhi_eq_an;
tThermo = toc;
fprintf('%d open-circuit voltages calculated in %.3g s.\n', numel(SOC), tThermo);

%%
% The OCV rises steeply over the first few percent of SOC, stays between
% about 3.7 and 3.9 V over most of the range, and reaches about 4.1 V in the
% fully charged cell.

figure
plot(100 * SOC, E_ocv, 'LineWidth', 1.5, 'Color', '#2a78d6')
xlabel('State of charge (%)')
ylabel('Open-circuit voltage (V)')
ylim([2.5, 4.3])
grid on

%% Cell Voltage from Kinetics
% The thermodynamic route only applies at equilibrium. To find the voltage
% of a cell that delivers current, we use the kinetics of the charge-transfer
% reactions instead. In this model, the reactions follow Butler-Volmer
% kinetics:
%
% $$I_\mathrm{Far} = S\, i_\circ \left[\exp\left(\frac{\beta F \eta}{RT}\right) - \exp\left(-\frac{(1-\beta) F \eta}{RT}\right)\right]$$
%
% where $S$ is the surface area of the electrode, $i_\circ$ the exchange
% current density, $\beta$ the symmetry factor, and $\eta$ the
% _overpotential_: the departure of the electrode-electrolyte potential
% difference from its equilibrium value,
%
% $$\eta = \Delta\Phi - \Delta\Phi_\mathrm{eq}$$
%
% The input file gives $i_\circ$ and $\beta$ for each reaction. Cantera
% computes $\eta$, and with it the reaction rate, from the electric potentials
% and compositions of the phases. The faradaic current of an electrode is
% then the rate at which its interface produces electrons, multiplied by $F$
% and $S$. The function |electrodeCurrent| at the end of this script does
% this; here we define it for each electrode as a function of the electrode
% potential |phi_s| and the electrolyte potential |phi_l|:

anodeCurrent = @(phi_s, phi_l) ...
    electrodeCurrent(anodeInterface, elde, elyt, phi_s, phi_l, S_an);
cathodeCurrent = @(phi_s, phi_l) ...
    electrodeCurrent(cathodeInterface, elde, elyt, phi_s, phi_l, S_ca);

%%
% In steady state, the same current $I_\mathrm{app}$ flows through the
% external circuit, through each interface, and through the electrolyte,
% where it causes an ohmic potential drop:
%
% $$\Phi_\mathrm{elyt,ca} = \Phi_\mathrm{elyt,an} + R_\mathrm{elyt} I_\mathrm{app}$$
%
% Here, $I_\mathrm{app}$ is positive when the cell is charging, delivering
% lithium ions to the anode, and negative when it is discharging. Only
% potential _differences_ matter, so we set the anode potential to zero. The
% function |cellVoltage| at the end of this script then finds the cell
% voltage in three steps:
%
% # Find the electrolyte potential at the anode for which the anode current
%   matches $I_\mathrm{app}$, using |fzero|.
% # Find the electrolyte potential at the cathode from the ohmic drop.
% # Find the cathode potential for which the cathode current matches
%   $I_\mathrm{app}$, again using |fzero|.
%
% The cell voltage is the difference between the cathode and anode
% potentials.
%
% As a first check, compute the voltage at zero current, which should match
% the open-circuit voltage from thermodynamics:

tic
V_kin = zeros(size(SOC));
for i = 1:numel(SOC)
    anode.X = [X_Li_an(i), 1 - X_Li_an(i)];
    cathode.X = [X_Li_ca(i), 1 - X_Li_ca(i)];
    V_kin(i) = cellVoltage(0, anodeCurrent, cathodeCurrent, R_elyt);
end
tKin = toc;
fprintf('%d cell voltages calculated in %.3g s.\n', numel(SOC), tKin);
fprintf('Largest difference from the thermodynamic OCV: %.2g V\n', ...
        max(abs(V_kin - E_ocv)));

%%

figure
plot(100 * SOC, V_kin, 'LineWidth', 1.5, 'Color', '#2a78d6')
hold on
plot(100 * SOC(1:5:end), E_ocv(1:5:end), 'o', 'MarkerSize', 7, ...
     'LineWidth', 1.5, 'Color', '#eb6834')
hold off
xlabel('State of charge (%)')
ylabel('Open-circuit voltage (V)')
ylim([2.5, 4.3])
legend('Kinetic', 'Thermodynamic', 'Location', 'southeast')
grid on

%%
% The two approaches agree to within round-off error. The thermodynamic
% route is faster, because it evaluates the voltage directly, while the
% kinetic route searches for the potentials that balance the currents:

fprintf('The thermodynamic route is %.0f times faster.\n', tKin / tThermo);

%%
% But only the kinetic route can find the voltage of a cell that carries a
% current.

%% Discharge Curves
% Now discharge the cell at several currents:

I_dis = [1, 5, 10, 15, 20];  % [A] discharge currents

V_dis = zeros(numel(I_dis), numel(SOC));
for j = 1:numel(I_dis)
    for i = 1:numel(SOC)
        anode.X = [X_Li_an(i), 1 - X_Li_an(i)];
        cathode.X = [X_Li_ca(i), 1 - X_Li_ca(i)];
        V_dis(j, i) = cellVoltage(-I_dis(j), anodeCurrent, cathodeCurrent, R_elyt);
    end
end

%%

blues = ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"];
figure
plot(100 * SOC, E_ocv, '--', 'LineWidth', 1.5, 'Color', '#7f7f7f', ...
     'DisplayName', 'Open circuit')
hold on
for j = 1:numel(I_dis)
    plot(100 * SOC, V_dis(j, :), 'LineWidth', 1.5, 'Color', blues(j), ...
         'DisplayName', sprintf('%g A', I_dis(j)))
end
hold off
xlabel('State of charge (%)')
ylabel('Cell voltage (V)')
ylim([2.5, 4.3])
legend('Location', 'eastoutside')
grid on

%%
% The voltage under load is lower than the OCV, and the gap grows with the
% current. Part of the gap is the overpotential that drives the reaction at
% each electrode, and part is the ohmic drop in the electrolyte,
% $R_\mathrm{elyt} |I_\mathrm{app}|$.

%% Next Steps
% Some things to try:
%
% * Change the temperature |T| and run the script again. The charge-transfer
%   reactions slow down at low temperature, and the cathode reaction, with
%   its higher activation energy, slows down the most.
% * Change the electrolyte resistance |R_elyt| or the surface areas |S_an|
%   and |S_ca| to see how cell design affects the discharge curves.
% * Use |I_app| > 0 in |cellVoltage| to compute charging curves.
%
% For more about the input file, including the sources of its data, see
% <https://cantera.org/stable/examples/input/lithium_ion_battery.html lithium_ion_battery.yaml>.
% The Mayur et al. paper cited above derives the thermodynamic model and
% compares it to measurements.

%% Local Functions

function I = electrodeCurrent(interface, elde, elyt, phi_s, phi_l, S)
    % Faradaic current [A] at an electrode surface, for the electric
    % potentials of the electrode, phi_s, and the electrolyte, phi_l [V].
    % The current is positive when the reaction releases electrons into the
    % electrode (oxidation). Set the composition of the electrode before
    % calling this function.
    elde.electricPotential = phi_s;
    elyt.electricPotential = phi_l;
    kElectron = interface.kineticsSpeciesIndex('electron');
    I = ct.FaradayConstant * S * interface.netProdRates(kElectron);
end

function V = cellVoltage(I_app, anodeCurrent, cathodeCurrent, R_elyt)
    % Cell voltage V [V] when the current I_app [A] flows through the cell,
    % positive for charging.
    phiGuess = 3;   % [V] starting guess for fzero
    phi_s_an = 0;   % the anode is the reference potential

    % 1. Electrolyte potential at the anode: the anode releases electrons at
    %    the rate the external circuit removes them.
    phi_l_an = fzero(@(phi_l) anodeCurrent(phi_s_an, phi_l) + I_app, phiGuess);

    % 2. Electrolyte potential at the cathode, from the ohmic drop.
    phi_l_ca = phi_l_an + R_elyt * I_app;

    % 3. Cathode potential: the cathode consumes electrons at the rate the
    %    external circuit delivers them.
    phi_s_ca = fzero(@(phi_s) cathodeCurrent(phi_s, phi_l_ca) - I_app, phiGuess);

    V = phi_s_ca - phi_s_an;
end
