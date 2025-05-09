function forecasts = forecastAllLSTM(history)
%forecastAllLSTM 24h LSTM forecasts for load, irradiance, temp, wind_speed
    series = {'load','irradiance','temperature','wind_speed'};
    h = 24; % Forecast horizon: 24 hours
    win = 312; % Sequence window: 312 hours (use all available history)
    forecasts = struct(); 
    for s = series
        y = history.(s{1});
        if numel(y) < win
            warning('Not enough data for %s: need >= %d, got %d', s{1}, win, numel(y));
            forecasts.(s{1}) = nan(h,1);
            continue;
        end
        % Prepare sequences
        [X, Y] = createSeq(y, win);
        layers = [sequenceInputLayer(1); lstmLayer(50); fullyConnectedLayer(1); regressionLayer];
        opts = trainingOptions('adam', 'MaxEpochs', 100, 'Verbose', false);
        net = trainNetwork(X, Y, layers, opts);
        % Forecast
        net = resetState(net);
        net = predictAndUpdateState(net, X);
        seq = y(end - win + 1:end);
        pred = zeros(h, 1);
        for t = 1:h
            [net, pred(t)] = predictAndUpdateState(net, seq(t));
            seq = [seq(2:end); pred(t)]; % Slide window for next prediction
        end
        forecasts.(s{1}) = pred;
    end
end

function [X, Y] = createSeq(y, win)
%createSeq Build predictor-target sequences
    N = numel(y) - win;
    X = cell(N, 1); Y = cell(N, 1);
    for i = 1:N
        X{i} = y(i:i + win - 1)';
        Y{i} = y(i + win);
    end
end