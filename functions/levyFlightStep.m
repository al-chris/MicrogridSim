function step = levyFlightStep(dim, beta)
% LEVYFLIGHTSTEP Generates a Lévy flight step in the search space.
%   step = levyFlightStep(dim, beta) generates a random Lévy flight step 
%   of the specified dimension 'dim' using the parameter 'beta', which 
%   controls the step size distribution.
%
%   The Lévy flight is a type of random walk in which step lengths are 
%   distributed according to a power-law distribution.

    % Generate a random Lévy flight step based on the distribution
    sigma_u = (gamma(1 + beta) * sin(pi * beta / 2) / gamma((1 + beta) / 2))^(1 / beta);  % scale parameter
    u = randn(dim, 1) * sigma_u;  % generate random "u" values
    v = randn(dim, 1);            % generate random "v" values
    
    % Lévy flight step
    step = u ./ abs(v).^(1 / beta);  % Lévy flight formula
end
