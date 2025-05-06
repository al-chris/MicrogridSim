function forecasts = forecastAllLSTM(history)
%forecastAllLSTM 24h LSTM forecasts for load, irradiance, temp, wind
    series = {'load','irradiance','temperature','wind'};
    h=24;
    forecasts = struct(); 
    for s=series
        y = history.(s{1});
        % Prepare sequences
        [X,Y] = createSeq(y,24);
        layers=[sequenceInputLayer(1); lstmLayer(50); fullyConnectedLayer(1); regressionLayer];
        opts = trainingOptions('adam','MaxEpochs',100,'Verbose',false);
        net = trainNetwork(X,Y,layers,opts);
        % Forecast
        net = resetState(net);
        net = predictAndUpdateState(net,X);
        seq = y(end-23:end);
        pred=zeros(h,1);
        for t=1:h
            [net,pred(t)] = predictAndUpdateState(net,seq(t));
        end
        forecasts.(s{1}) = pred;
    end
end

function [X,Y] = createSeq(y,win)
%createSeq Build predictor-target sequences
    N=numel(y)-win; X=cell(N,1); Y=cell(N,1);
    for i=1:N
        X{i}=y(i:i+win-1)'; Y{i}=y(i+win);
    end
end