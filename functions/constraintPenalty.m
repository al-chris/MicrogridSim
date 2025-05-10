function penalty = constraintPenalty(x, data, params)
%CONSTRAINTPENALTY Compute penalty cost for any constraint violations of a dispatch plan.
%  penalty = constraintPenalty(x, data, params) returns a large penalty value if
%  constraints are violated, proportional to the degree of violation.
%
%  Constraints checked:
%    - Power balance: P_pv + P_wind + P_grid + P_diesel + P_batt == P_load (every time step)
%    - SoC bounds: SoC_min <= SoC(t) <= SoC_max
%    - Power limits: 0 <= P_grid <= max_grid, 0 <= P_diesel <= max_diesel, and P_batt within [-max_charge, max_discharge]
    
    % Unpack data and decision variables
    P_pv   = data.P_pv(:);
    P_wind = data.P_wind(:);
    P_load = data.load(:);
    T = length(P_load);
    
    P_grid   = x(1:T);
    P_diesel = x(T+1:2*T);
    P_batt   = x(2*T+1:3*T);
    
    penalty = 0;
    w_balance = 1e3;    % weight for power balance mismatch (cost per kW imbalance)
    w_bounds  = 1e5;    % weight for violating hard bounds (SoC, power limits)
    
    %% Power balance constraint
    net_supply = P_pv + P_wind + P_grid + P_diesel + P_batt - P_load;
    imbalance = net_supply;
    penalty = penalty + w_balance * sum(imbalance .^ 2);
    
    %% Battery SoC constraint
    SoC = simulateBattery(P_batt, params.BESS);
    SoC_min = params.BESS.SoC_min;
    SoC_max = params.BESS.SoC_max;
    
    below_min = SoC < SoC_min;
    above_max = SoC > SoC_max;
    if any(below_min)
        diff = SoC_min - SoC(below_min);
        disp(['SoC below min: ', num2str(sum(diff))]);
        penalty = penalty + w_bounds * sum(diff.^2);
    end
    if any(above_max)
        diff = SoC(above_max) - SoC_max;
        disp(['SoC above max: ', num2str(sum(diff))]);
        penalty = penalty + w_bounds * sum(diff.^2);
    end
    if any(P_grid < 0)
        diff = -P_grid(P_grid < 0);
        disp(['P_grid below 0: ', num2str(sum(diff))]);
        penalty = penalty + w_bounds * sum(diff.^2);
    end
    if any(P_diesel < 0)
        diff = -P_diesel(P_diesel < 0);
        disp(['P_diesel below 0: ', num2str(sum(diff))]);
        penalty = penalty + w_bounds * sum(diff.^2);
    end
    if any(P_batt > params.BESS.max_discharge)
        diff = P_batt(P_batt > params.BESS.max_discharge) - params.BESS.max_discharge;
        disp(['P_batt above max discharge: ', num2str(sum(diff))]);
        penalty = penalty + w_bounds * sum(diff.^2);
    end
    if any(P_batt < -params.BESS.max_charge)
        diff = -params.BESS.max_charge - P_batt(P_batt < -params.BESS.max_charge);
        disp(['P_batt below max charge: ', num2str(sum(diff))]);
        penalty = penalty + w_bounds * sum(diff.^2);
    end
    assert(isscalar(penalty), "Penalty is not scalar!");
end
