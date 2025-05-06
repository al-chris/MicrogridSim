function Cp = WindModel_CpLambdaBeta(lambda, beta)
%WindModel_CpLambdaBeta Power coefficient as function of tip-speed ratio and pitch
%   Cp = WindModel_CpLambdaBeta(lambda, beta)
%   computes the power coefficient Cp of a wind turbine as a function of
%   the tip-speed ratio (lambda) and the pitch angle (beta).
%   The function uses a modified version of the Betz limit to calculate Cp.

    c1 = 0.5176;
    c2 = 116; 
    c3 = 0.4; 
    c4 = 5; 
    c5 = 21; 
    c6 = 0.0068;

    if lambda == 0
        Cp = 0; 
        return; 
    end

    lam_i = 1./((1./(lambda + 0.08*beta)) - 0.035./(beta.^3 + 1));

    Cp = c1*((c2./lam_i) - c3*beta - c4).*exp(-c5./lam_i) + c6*lambda;

    Cp = max(0, min(Cp, 0.5926));
end