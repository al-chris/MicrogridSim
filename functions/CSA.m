function [bestSol, bestCost] = CSA(fitnessFunc, lb, ub, options)
%CSA Perform Cuckoo Search optimization with Lévy flights.
%  [bestSol, bestCost] = CSA(fitnessFunc, lb, ub, options) finds the minimum 
%  of the fitnessFunc using the Cuckoo Search Algorithm.
    
    dim = length(lb);
    np = options.n_nests;
    max_iter = options.max_iter;
    
    w = options.w;
    w_damp = options.w_damp;
    c1 = options.c1;
    c2 = options.c2;
    
    % Initialize population of nests within bounds
    nests = rand(np, dim) .* repmat((ub(:) - lb(:))', np, 1) + repmat(lb(:)', np, 1); 
    fitness = zeros(np, 1);
    for i = 1:np
        fitness(i) = fitnessFunc(nests(i, :)');
    end
    [bestCost, best_idx] = min(fitness);
    bestSol = nests(best_idx, :)';
    
    for iter = 1:max_iter
        for i = 1:np
            step = levyFlightStep(dim, 1.5);  % Lévy flight step
            newSol = nests(i, :) + w * step .* (nests(i, :) - bestSol');
            newSol = min(max(newSol, lb'), ub');
            
            % Ensure newSol is a row vector, pass as column to fitnessFunc
            newCost = fitnessFunc(newSol(:));
            j = randi(np);
            if newCost < fitness(j)
                nests(j, :) = newSol(1, :);
                disp(size(newCost)); % Should print [1 1]
                fitness(j) = newCost;
            end
        end
        
        K = floor(np * 0.25);  % abandon 25% of worst nests
        [~, worst_idx] = maxk(fitness, K);
        for idx = worst_idx'
            nests(idx, :) = rand(1, dim) .* (ub' - lb') + lb';
            fitness(idx) = fitnessFunc(nests(idx, :)');
        end
        
        [currentBestCost, best_idx] = min(fitness);
        if currentBestCost < bestCost
            bestCost = currentBestCost;
            bestSol = nests(best_idx, :)';
        end
        
        w = w * w_damp;  % inertia damping
    end
end
