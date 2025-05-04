% main.m - Main script to simulate microgrid and run optimization using CSA and PSO

% 1. Set up system parameters
params.PV.capacity = 50;             % Rated PV power at STC (kW)
params.PV.temp_coeff = -0.004;       % Temperature coefficient (per °C)
params.Wind.rho = 1.225;             % Air density (kg/m^3)
params.Wind.area = pi * (20^2);      % Rotor swept area (m^2), assuming rotor radius of 20m
params.Wind.Cp = 0.4;                % Power coefficient
params.Wind.P_rated = 500;           % Rated power of wind turbine (kW)
params.Wind.v_cutin = 3;             % Cut-in wind speed (m/s)
params.Wind.v_rated = 12;            % Rated wind speed (m/s)
params.Wind.v_cutout = 25;           % Cut-out wind speed (m/s)

params.BESS.capacity = 500;          % Battery storage capacity (kWh)
params.BESS.SoC_init = 0.5;          % Initial state of charge (fraction)
params.BESS.SoC_min = 0.2;           % Minimum state of charge (fraction)
params.BESS.SoC_max = 1.0;           % Maximum state of charge (fraction)
params.BESS.eff_charge = 0.9;        % Charging efficiency
params.BESS.eff_discharge = 0.9;     % Discharging efficiency
params.BESS.dt = 1;                  % Time step duration (hours)
params.BESS.max_discharge = 50;      % Maximum discharging rate (kW)
params.BESS.max_charge = 50;         % Maximum charging rate (kW)

params.C_grid = 0.05;                % Cost per kWh for grid electricity
params.C_diesel = 0.15;              % Cost per kWh for diesel generation
params.C_batt = 0.10;                % Cost per kWh for battery usage

params.max_iter = 100;               % Max iterations for optimization
params.n_nests = 20;                 % Number of nests for CSA
params.n_particles = 20;             % Number of particles for PSO

params.w = 0.8;                      % Inertia weight for PSO
params.w_damp = 0.99;                % Damping factor for PSO
params.c1 = 2;                       % Cognitive weight for PSO
params.c2 = 2;                       % Social weight for PSO

params.vel_max = 0.1;                % Maximum velocity for PSO

% 2. Load data
disp('Loading data...');
% Pass the params structure to loadData
[time, data] = loadData(params);

% 3. Set optimization problem bounds
T = length(time); % Number of time steps (48h = 48 points)

lb = zeros(3*T, 1);    % Lower bound (all power dispatch is >= 0)
ub = [repmat(500, T, 1);  % Upper bound for grid power (max 500 kW)
      repmat(500, T, 1);  % Upper bound fordiesel power (max 500 kW)
      repmat(50, T, 1)]; % Upper bound for battery power (max 50 kW)

% 4. Run optimization using CSA
disp('Running CSA...');
options_CSA = struct('max_iter', params.max_iter, 'n_nests', params.n_nests, 'w', params.w, ...
                     'w_damp', params.w_damp, 'c1', params.c1, 'c2', params.c2);
[bestSol_CSA, bestCost_CSA] = CSA(@(x) fitnessFunction(x, data, params), lb, ub, options_CSA);

% 5. Run optimization using PSO
disp('Running PSO...');
options_PSO = struct('max_iter', params.max_iter, 'n_particles', params.n_particles, 'w', params.w, ...
                     'w_damp', params.w_damp, 'c1', params.c1, 'c2', params.c2, 'vel_max', params.vel_max);
[bestSol_PSO, bestCost_PSO] = PSO(@(x) fitnessFunction(x, data, params), lb, ub, options_PSO);

% 6. Display results
disp('Optimization Results:');
fprintf('CSA Best Cost: %.2f\n', bestCost_CSA);
fprintf('PSO Best Cost: %.2f\n', bestCost_PSO);

% 7. Plot results: Compare dispatch profiles
figure;
subplot(2,1,1);
plot(time, bestSol_CSA(1:T), '-b', 'LineWidth', 1.5); hold on;
plot(time, bestSol_CSA(T+1:2*T), '-r', 'LineWidth', 1.5);
plot(time, bestSol_CSA(2*T+1:3*T), '-k', 'LineWidth', 1.5);
legend('Grid Power (kW)', 'Diesel Power (kW)', 'Battery Power (kW)');
xlabel('Time (hours)');
ylabel('Power (kW)');
title('CSA Optimal Dispatch Profile');

subplot(2,1,2);
plot(time, bestSol_PSO(1:T), '-b', 'LineWidth', 1.5); hold on;
plot(time, bestSol_PSO(T+1:2*T), '-r', 'LineWidth', 1.5);
plot(time, bestSol_PSO(2*T+1:3*T), '-k', 'LineWidth', 1.5);
legend('Grid Power (kW)', 'Diesel Power (kW)', 'Battery Power (kW)');
xlabel('Time (hours)');
ylabel('Power (kW)');
title('PSO Optimal Dispatch Profile');

% 8. Save results to a file
save('optimization_results.mat', 'bestSol_CSA', 'bestCost_CSA', 'bestSol_PSO', 'bestCost_PSO');
disp('Results saved to optimization_results.mat');

% Load data function
function [time, data] = loadData(params)
    % Load atmospheric temperature data
    tempTbl = readtable('data/Atmospheric_Temperature.xlsx', 'Sheet', 'Sheet1');
    
    % Combine date and time columns to create a datetime array
    t_temp = datetime(tempTbl.Date, 'Format', 'MM-dd-yyyy') + hours(tempTbl.Time);  % assuming Time is in hours
    
    temperature = tempTbl{:, 3};

    % Load load schedule data
    loadTbl = readtable('data/1_LOAD_SCHEDULE.xlsx');
    t_load = datetime(loadTbl.Date, 'Format', 'MM-dd-yyyy') + hours(loadTbl.Time);  % similar handling for load time
    load_demand = loadTbl.KW;

    % Load solar and wind data
    resTbl = readtable('data/accurate_my_wind_speed_and_solar_data.xlsx', 'Sheet', 'Sheet1');
    t_res = datetime(resTbl.Date, 'Format', 'MM-dd-yyyy') + hours(resTbl.Time);  % same as above
    irradiance = resTbl.G;
    wind_speed = resTbl.W_S;

    % Synchronize data on common time axis
    TT_temp = timetable(t_temp, temperature);
    TT_load = timetable(t_load, load_demand);
    TT_res = timetable(t_res, irradiance, wind_speed);
    
    % Synchronize the three timetables, using their respective datetime variables
    TT = synchronize(TT_temp, TT_load, TT_res, 'intersection');
    
    % Ensure we're working with the first 48 hours (the Time column of the synchronized timetable is automatically named after the first timetable)
    TT48 = TT(TT.t_temp < TT.t_temp(1) + hours(48), :);

    % Extract time series for the next 48 hours
    time = TT48.t_temp;   % Use the datetime from the first timetable (t_temp)
    data.temperature = TT48.temperature;
    data.load = TT48.load_demand;
    data.irradiance = TT48.irradiance;
    data.wind_speed = TT48.wind_speed;
    data.P_pv = PV_model(data.irradiance, data.temperature, params.PV);
    data.P_wind = Wind_model(data.wind_speed, params.Wind);
end
