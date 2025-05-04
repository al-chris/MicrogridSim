function P_wind = Wind_model(wind_speed, Wind_params)
%WIND_MODEL Compute wind turbine power output from wind speed.
%  P_wind = Wind_model(wind_speed, Wind_params) returns the wind turbine 
%  power output (in kW) for each time step given the wind_speed (m/s).
%
%  Wind_params is a struct with fields:
%    - rho: Air density (kg/m^3), e.g., 1.225 at sea level
%    - area: Rotor swept area (m^2), A = pi*R^2 for rotor radius R
%    - Cp: Power coefficient (0 < Cp < Betz limit ~0.59, e.g., 0.4)
%    - P_rated: Rated power of the turbine (kW)
%    - v_cutin: Cut-in wind speed (m/s) where the turbine starts generating
%    - v_rated: Wind speed at which turbine reaches rated power (m/s)
%    - v_cutout: Cut-out wind speed (m/s) above which turbine shuts off
%
%  The model uses the formula P = 0.5 * rho * area * Cp * v^3 in the 
%  operating range, capped by P_rated, and 0 outside the range.
%
%  Example:
%    Wind_params.rho = 1.225;
%    Wind_params.area = pi*(20^2);  % rotor radius 20 m
%    Wind_params.Cp = 0.4;
%    Wind_params.P_rated = 500;     % 500 kW turbine
%    Wind_params.v_cutin = 3;
%    Wind_params.v_rated = 12;
%    Wind_params.v_cutout = 25;
%    P_wind = Wind_model(wind_speed, Wind_params);

    v = wind_speed(:);
    P_wind = zeros(size(v));
    
    % Unpack parameters
    rho = Wind_params.rho;
    A   = Wind_params.area;
    Cp  = Wind_params.Cp;
    P_max = Wind_params.P_rated;
    v_in  = Wind_params.v_cutin;
    v_out = Wind_params.v_cutout;
    v_r   = Wind_params.v_rated;
    
    % Compute theoretical power for each time step
    P_theoretical = 0.5 * rho * A * Cp .* (v .^ 3) / 1000;  % /1000 to convert W to kW
    
    % Apply power curve limits
    for t = 1:length(v)
        if v(t) < v_in || v(t) >= v_out
            % Below cut-in or above cut-out speed: no power
            P_wind(t) = 0;
        elseif v(t) <= v_r
            % Between cut-in and rated: use cubic law (cap at P_max just in case)
            P_wind(t) = min(P_theoretical(t), P_max);
        else
            % Between rated and cut-out: output at rated power
            P_wind(t) = P_max;
        end
    end
end
