function I = PVModel_SingleDiode(V, G, T, params)
    % PVModel_SingleDiode: Five-parameter single-diode PV model
    % V: terminal voltage (V), G: irradiance (W/m^2), T: cell temp (K)
    % params: structure with Iph_ref, I0_ref, alpha_I, Eg, T_ref, Rs, Rsh, n
    
    q = 1.602e-19;  % Charge of electron (C)
    k = 1.381e-23;  % Boltzmann constant (J/K)
    
    % Calculate photocurrent (Iph) based on irradiance and temperature
    Iph = (params.Iph_ref + params.alpha_I * (T - params.T_ref)) * (G / 1000);
    
    % Calculate saturation current (I0) based on temperature
    I0 = params.I0_ref * (T / params.T_ref)^3 * exp((q * params.Eg / (k * params.n)) * (1 / params.T_ref - 1 / T));
    
    Rs = params.Rs;  % Series resistance
    Rsh = params.Rsh;  % Shunt resistance
    n = params.n;  % Diode ideality factor
    
    % Define the function to solve
    func = @(I) Iph - I0 * (exp(q * (V + I * Rs) / (n * k * T)) - 1) - (V + I * Rs) / Rsh - I;
    
    % Initial guess (Iph can sometimes be too large or small, so try a different guess)
    initialGuess = max(0, Iph / 10);  % Start with a smaller value if Iph is too large
    
    % Try to solve the function with error handling
    try
        I = fzero(func, initialGuess);
        
        % Check if the solution is valid
        if ~isreal(I) || ~isfinite(I)
            error('The root-finding process did not converge to a valid solution.');
        end
        
    catch
        % If fzero fails, provide an error message or fallback solution
        warning('fzero failed, using default value for I');
        I = 0;  % Default fallback current (use a safe value)
    end
end
