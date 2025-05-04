function SoC = simulateBattery(P_batt, BESS_params)
%SIMULATEBATTERY Simulate the battery SoC trajectory over time.
%  SoC = simulateBattery(P_batt, BESS_params) returns the state-of-charge 
%  array for the battery given the power profile P_batt (kW) over time.
%
%  BESS_params is a struct with fields:
%    - capacity: Energy capacity of battery (kWh)
%    - SoC_init: Initial state of charge (fraction of capacity, 0 to 1)
%    - SoC_min: Minimum SoC (fraction of capacity)
%    - SoC_max: Maximum SoC (fraction of capacity)
%    - eff_charge: Charging efficiency (0-1)
%    - eff_discharge: Discharging efficiency (0-1)
%    - dt: time step duration (hours)
%
%  P_batt is a vector of power at each time (kW). P_batt > 0 means battery 
%  discharging (supplying power), P_batt < 0 means charging.
%
%  The output SoC is a vector (same length as P_batt + 1) that includes the 
%  initial SoC and SoC after each time step.
    
    N = length(P_batt);
    SoC = zeros(N+1, 1);
    % Set initial SoC in energy terms (kWh)
    SoC(1) = BESS_params.SoC_init * BESS_params.capacity;
    % Time step
    dt = BESS_params.dt;
    
    for t = 1:N
        if P_batt(t) >= 0
            % Discharging: SoC decreases
            energy_out = P_batt(t) * dt;  % kWh delivered from battery
            energy_from_batt = energy_out / BESS_params.eff_discharge;  % kWh taken from battery (accounting for loss)
            SoC(t+1) = SoC(t) - energy_from_batt;
        else
            % Charging: SoC increases
            energy_in = -P_batt(t) * dt;  % kWh sent into battery (P_batt is negative here)
            energy_stored = energy_in * BESS_params.eff_charge;  % kWh actually stored in battery
            SoC(t+1) = SoC(t) + energy_stored;
        end
        
        % Enforce bounds (SoC cannot exceed min/max capacity)
        if SoC(t+1) > BESS_params.capacity * BESS_params.SoC_max
            SoC(t+1) = BESS_params.capacity * BESS_params.SoC_max;
        elseif SoC(t+1) < BESS_params.capacity * BESS_params.SoC_min
            SoC(t+1) = BESS_params.capacity * BESS_params.SoC_min;
        end
    end
    
    % Convert SoC from energy (kWh) to fraction of capacity for output (optional)
    SoC = SoC / BESS_params.capacity;
end
