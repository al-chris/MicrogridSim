function [bestSol, bestCost] = CSA_Adaptive(fitFunc, lb, ub, opts)
%CSA_Adaptive Cuckoo Search with adaptive Lévy scaling
    dim = numel(lb); 
    np = opts.n_nests; 
    maxIter = opts.max_iter;
    alpha = opts.alpha0; 
    stagnWindow = 10;

    nests = rand(np,dim).*(ub'-lb') + lb'; fitness = inf(np,1);

    for i=1:np 
        fitness(i)=fitFunc(nests(i,:)'); 
    end

    [bestCost, idx]=min(fitness); bestSol=nests(idx,:)';

    history = inf(maxIter,1);

    for iter=1:maxIter
        for i=1:np
            step = levyFlightStep(dim, opts.beta);
            new = nests(i,:) + alpha*step'.*(nests(i,:)-bestSol');
            new = min(max(new, lb'), ub');
            cost = fitFunc(new');
            j = randi(np);

            if cost<fitness(j)
                nests(j,:)=new; 
                fitness(j)=cost; 
            end
        end

        [~,worst]=maxk(fitness,floor(0.25*np));

        for w=worst'
            nests(w,:)=rand(1,dim).*(ub'-lb')+lb'; 
            fitness(w)=fitFunc(nests(w,:)'); 
        end

        [currBest, idx]=min(fitness); 
        
        if currBest<bestCost
            bestCost=currBest; 
            bestSol=nests(idx,:)'; 
        end

        history(iter)=bestCost;
        
        if iter>stagnWindow && history(iter-stagnWindow)-bestCost < 0.05*history(iter-stagnWindow)
            alpha = 1.2*alpha;
        end
    end
end