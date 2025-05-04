function [bestSol, bestCost] = PSO(fitnessFunc, lb, ub, options)
%PSO Perform Particle Swarm Optimization.
%  [bestSol, bestCost] = PSO(fitnessFunc, lb, ub, options) finds the minimum 
%  of fitnessFunc using a PSO algorithm.
    
    dim = length(lb);
    np = options.n_particles;
    max_iter = options.max_iter;
    
    w = options.w;
    w_damp = options.w_damp;
    c1 = options.c1;
    c2 = options.c2;
    
    % Initialize particle positions and velocities
    X = rand(np, dim) .* (ub' - lb') + lb'; 
    V = 0.1 * (rand(np, dim) .* (ub' - lb'));
    
    pbest = X;
    pbest_cost = inf(np, 1);
    for i = 1:np
        pbest_cost(i) = fitnessFunc(X(i, :)');
    end
    
    [bestCost, best_idx] = min(pbest_cost);
    bestSol = pbest(best_idx, :)';
    
    for iter = 1:max_iter
        for i = 1:np
            r1 = rand(1, dim);
            r2 = rand(1, dim);
            V(i, :) = w * V(i, :) + c1 * r1 .* (pbest(i, :) - X(i, :)) + c2 * r2 .* (bestSol' - X(i, :));
            V(i, :) = max(min(V(i, :), options.vel_max), -options.vel_max);
            
            X(i, :) = X(i, :) + V(i, :);
            X(i, :) = min(max(X(i, :), lb'), ub');
            
            cost = fitnessFunc(X(i, :)');
            if cost < pbest_cost(i)
                pbest(i, :) = X(i, :);
                pbest_cost(i) = cost;
            end
            if cost < bestCost
                bestCost = cost;
                bestSol = X(i, :)';
            end
        end
        
        w = w * w_damp;  % inertia damping
    end
end
