function P_pv = PV_model(irradiance, temperature, PV_params)
%PV_MODEL Compute PV array power output using a single-diode PV model approximation.
%  P_pv = PV_model(irradiance, temperature, PV_params) returns the photovoltaic 
%  power output (in kW) for each time step given the irradiance (W/m^2) and cell 
%  temperature (deg C).
%
%  PV_params is a struct with fields:
%    - capacity: Rated PV array power at STC (kW at 1000 W/m^2, 25°C)
%    - temp_coeff: Power temperature coefficient (per °C, typically negative)
%
%  The model scales the output with irradiance and adjusts for temperature.
%
%  Example:
%    PV_params.capacity = 50;    % 50 kW PV array at STC
%    PV_params.temp_coeff = -0.004;  % -0.4% per °C temperature coefficient
%    P_pv = PV_model(G, T, PV_params);

    % Ensure vectors are column for consistency
    G = irradiance(:);
    T = temperature(:);
    
    % Unpack parameters
    P_stc = PV_params.capacity;
    gamma = PV_params.temp_coeff;
    
    % Compute power output at each time step
    P_pv = P_stc * (G / 1000) .* (1 + gamma * (T - 25));
    
    % Ensure no negative power (just in case of extreme conditions)
    P_pv(P_pv < 0) = 0;
    
    % Cap the PV output at the rated capacity (cannot exceed STC capacity significantly)
    P_pv = min(P_pv, P_stc);
end
