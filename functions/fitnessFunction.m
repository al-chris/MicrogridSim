function totalCost = fitnessFunction(x, data, params)
%FITNESSFUNCTION Calculate total operational cost (with penalties) for a given dispatch plan.
%  totalCost = fitnessFunction(x, data, params) evaluates the objective for 
%  decision vector x, given input data (load and renewable profiles) and system parameters.
%
%  Inputs:
%    x     - Decision vector [P_grid(1..T), P_diesel(1..T), P_batt(1..T)] (1D array)
%    data  - Struct with time-series data arrays:
%              data.P_pv (T x 1 vector of PV power available, kW)
%              data.P_wind (T x 1 vector of wind power available, kW)
%              data.load (T x 1 vector of load demand, kW)
%    params - Struct with system parameters:
%              params.C_grid      - cost per kWh of grid power ($/kWh)
%              params.C_diesel    - cost per kWh of diesel generation ($/kWh)
%              params.C_batt      - cost per kWh of battery throughput (degradation cost)
%              params.max_grid    - max grid import (kW)
%              params.max_diesel  - diesel generator capacity (kW)
%              params.max_charge  - max battery charging power (kW) (positive value)
%              params.max_discharge - max battery discharging power (kW)
%              params.BESS        - struct of battery parameters (SoC_init, SoC_min, SoC_max, eff_charge, eff_discharge, capacity, dt)
%
%  Output:
%    totalCost - The total cost of the plan x (including penalty for any constraint violations).
%
%  The function computes the cost components (grid, diesel, battery) and adds penalty for:
%    - Power balance mismatch
%    - SoC violations
%    - Power limit violations (grid, diesel, battery)
    
    % Determine horizon from decision vector
    T = floor(numel(x)/3);

    % Truncate all data series to this horizon
    data.P_pv   = data.P_pv(:);
    data.P_wind = data.P_wind(:);
    data.load   = data.load(:);
    data.P_pv   = data.P_pv(1:T);
    data.P_wind = data.P_wind(1:T);
    data.load   = data.load(1:T);
    
    % Extract decision variables
    P_grid   = x(1:T);
    P_diesel = x(T+1:2*T);
    P_batt   = x(2*T+1:3*T);
    
    % Compute base cost (without penalties)
    cost_grid   = params.C_grid   * max(P_grid, 0);
    cost_diesel = params.C_diesel * max(P_diesel, 0);
    cost_batt   = params.C_batt   * abs(P_batt);
    baseCost    = sum(cost_grid + cost_diesel + cost_batt);
    
    % Compute penalty (now using truncated data)
    penalty = constraintPenalty([P_grid; P_diesel; P_batt], data, params);
    
    % Total fitness value
    totalCost = baseCost + penalty;
end
