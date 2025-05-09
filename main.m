% main.m - Main script to simulate microgrid and run optimization using CSA and PSO

addpath('C:\Users\CHRISTOPHER\Documents\MATLAB\MicrogridSim\functions')
addpath('C:\Users\CHRISTOPHER\Documents\MATLAB\MicrogridSim\forecasting')

% 1. System parameters
% PV single-diode parameters
params.PV.Iph_ref   = 5;           % A, reference photocurrent at STC (user to adjust)
params.PV.I0_ref    = 1e-10;       % A, reference saturation current
params.PV.alpha_I   = 0.002;       % A/K, temp coefficient for current
params.PV.Eg        = 1.12;        % eV, bandgap energy for silicon
params.PV.T_ref     = 298.15;      % K, reference temperature (25°C)
params.PV.Rs        = 0.5;         % Ω, series resistance
params.PV.Rsh       = 1000;        % Ω, shunt resistance
params.PV.n         = 1.3;         % diode ideality factor
params.PV.Vmp       = 30;          % V, module voltage at MPP

% Wind turbine parameters
params.Wind.rho     = 1.225;       % kg/m^3, air density
params.Wind.area    = pi*(20^2);   % m^2, rotor swept area
params.Wind.beta    = 0;           % deg, blade pitch angle
params.Wind.omega   = 2*pi*15;     % rad/s, rotor speed

% Battery storage parameters
params.BESS.capacity    = 500;     % kWh
params.BESS.SoC_init    = 0.5;     % fraction
params.BESS.SoC_min     = 0.2;     % fraction
params.BESS.SoC_max     = 1.0;     % fraction
params.BESS.eff_charge  = 0.9;     % charging efficiency
params.BESS.eff_discharge = 0.9;    % discharging efficiency
params.BESS.dt          = 1;       % h, time step duration
params.BESS.max_discharge = 50;    % kW
params.BESS.max_charge    = 50;    % kW

% Cost parameters
params.C_grid       = 0.05;        % $/kWh grid electricity
params.C_diesel     = 0.15;        % $/kWh diesel generation
params.C_batt       = 0.10;        % $/kWh battery throughput

% New parameter: Maximum grid power (define this based on system constraints)
params.max_grid     = 500;         % kW, maximum grid power available for dispatch
params.max_diesel   = 500;         % kW, maximum diesel power available for dispatch

% Optimization parameters
params.max_iter     = 100;
params.n_nests      = 20;
params.n_particles  = 20;
params.w            = 0.8;         % Inertia weight
params.w_damp       = 0.99;        % Damping
params.c1           = 2;
params.c2           = 2;
params.vel_max      = 0.1;
% Adaptive CSA parameters
params.alpha0       = 1;           % initial Lévy scaling
params.beta         = 1.5;         % Lévy distribution exponent

% 2. Load historical data
disp('Loading data...');
[time, data] = loadData(params);

% 3. Forecast next 24 hours (ARIMA or LSTM)
nForecast = 24;
history.load        = data.load;
history.irradiance = data.irradiance;
history.temperature = data.temperature;
history.wind_speed  = data.wind_speed;

% Use ARIMA forecasts
fi = forecastAllARIMA(history);
% Or use LSTM forecasts:
%fl = forecastAllLSTM(history);

% Update data with forecasts
data.load        = [history.load;        max(fi.load, 0)];
data.irradiance  = [history.irradiance;  max(fi.irradiance, 0)];
data.temperature = [history.temperature; fi.temperature];
data.wind_speed  = [history.wind_speed;  max(fi.wind_speed, 0)];

% Update time vector to match new data length
time = [time; time(end) + hours(1:nForecast)'];

% 4. Compute renewable outputs using new models
Tsteps = numel(time);
P_pv = zeros(Tsteps,1);
for t = 1:Tsteps
    tempK = max(data.temperature(t) + 273.15, 200);
    irr = max(data.irradiance(t), 0);
    I = PVModel_SingleDiode(params.PV.Vmp, irr, tempK, params.PV);
    P_pv(t) = (I * params.PV.Vmp) / 1000;  % kW
end

% Wind power
R = sqrt(params.Wind.area/pi); % rotor radius (m)
lambda = (params.Wind.omega * R) ./ data.wind_speed(1:Tsteps);
Cp = WindModel_CpLambdaBeta(lambda, params.Wind.beta);
P_wind = 0.5 * params.Wind.rho * params.Wind.area .* Cp .* (data.wind_speed(1:Tsteps).^3) / 1000; % kW

data.P_pv   = P_pv;
data.P_wind = P_wind;

% 5. Set optimization bounds
T = Tsteps;
lb = zeros(3*T,1);
ub = [repmat(params.max_grid, T,1);
      repmat(params.max_diesel, T,1);
      repmat(params.BESS.max_discharge, T,1)];

% 6. Run Adaptive CSA
disp('Running CSA_Adaptive...');
optsCSA = struct('max_iter', params.max_iter, 'n_nests', params.n_nests, 'alpha0', params.alpha0, 'beta', params.beta);
[bestSol_CSA, bestCost_CSA] = CSA_Adaptive(@(x) fitnessFunction(x, data, params), lb, ub, optsCSA);

% 7. Run PSO
disp('Running PSO...');
optsPSO = struct('max_iter', params.max_iter, 'n_particles', params.n_particles, 'w', params.w, 'w_damp', params.w_damp, 'c1', params.c1, 'c2', params.c2, 'vel_max', params.vel_max);
[bestSol_PSO, bestCost_PSO] = PSO(@(x) fitnessFunction(x, data, params), lb, ub, optsPSO);

% 8. Display results
fprintf('\nOptimization Results:\n');
fprintf('  CSA Best Cost: %.2f\n', bestCost_CSA);
fprintf('  PSO Best Cost: %.2f\n\n', bestCost_PSO);

% 9. Plot dispatch profiles
figure;
subplot(2,1,1);
plot(time, bestSol_CSA(1:T), '-b', 'LineWidth', 1.5); hold on;
plot(time, bestSol_CSA(T+1:2*T), '-r', 'LineWidth', 1.5);
plot(time, bestSol_CSA(2*T+1:3*T), '-k', 'LineWidth', 1.5);
legend('Grid','Diesel','Battery'); xlabel('Time (h)'); ylabel('Power (kW)');
title('CSA Adaptive Dispatch Profile');

subplot(2,1,2);
plot(time, bestSol_PSO(1:T), '-b', 'LineWidth', 1.5); hold on;
plot(time, bestSol_PSO(T+1:2*T), '-r', 'LineWidth', 1.5);
plot(time, bestSol_PSO(2*T+1:3*T), '-k', 'LineWidth', 1.5);
legend('Grid','Diesel','Battery'); xlabel('Time (h)'); ylabel('Power (kW)');
title('PSO Dispatch Profile');

% 10. Save results
save('optimization_results.mat','bestSol_CSA','bestCost_CSA','bestSol_PSO','bestCost_PSO');
disp('Results saved to optimization_results.mat');

% Load data function (first 312 hours)
function [time, data] = loadData(~)
    % Load atmospheric temperature data
    tempTbl = readtable('data/Atmospheric_Temperature.xlsx', 'Sheet', 'Sheet1');
    t_temp = datetime(tempTbl.Date, 'Format', 'MM-dd-yyyy ss:mm:hh') + hours(tempTbl.Time);
    temperature = tempTbl{:, 3};

    % Load load schedule data
    loadTbl = readtable('data/1_LOAD_SCHEDULE.xlsx', 'Sheet', 'Sheet1');
    t_load = datetime(loadTbl.Date, 'Format', 'MM-dd-yyyy ss:mm:hh') + hours(loadTbl.Time);
    load_demand = loadTbl.KW;

    % Load solar and wind data
    resTbl = readtable('data/accurate_my_wind_speed_and_solar_data.xlsx', 'Sheet', 'Sheet1');
    t_res = datetime(resTbl.Date, 'Format', 'MM-dd-yyyy ss:mm:hh') + hours(resTbl.Time);
    irradiance = resTbl.G;
    wind_speed = resTbl.W_S;

    % Synchronize data on common time axis
    TT_temp = timetable(t_temp, temperature);
    TT_load = timetable(t_load, load_demand);
    TT_res = timetable(t_res, irradiance, wind_speed);

    disp(height(TT_temp));
    disp(height(TT_load));
    disp(height(TT_res));

    % Synchronize the three timetables, using their respective datetime variables
    TT = synchronize(TT_temp, TT_load, TT_res, 'intersection');

    disp(height(TT));

    % Use the first 312 hours for training
    TT312 = TT(TT.t_temp < TT.t_temp(1) + hours(312), :);

    % Extract time series for the first 312 hours
    time = TT312.t_temp;
    data.temperature = TT312.temperature;
    data.load = TT312.load_demand;
    data.irradiance = TT312.irradiance;
    data.wind_speed = TT312.wind_speed;
end
