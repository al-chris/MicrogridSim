function forecasts = forecastAllLSTM(history)
% forecastAllLSTM trains a multivariate LSTM and forecasts 24 hours ahead.
% Input: history (struct with fields: load, irradiance, temperature, wind_speed)
% Output: forecasts (struct with 24x1 vectors for each field)

    % Ensure data is in column vector form and of type double
    load_data       = double(history.load(:));
    irr_data        = double(history.irradiance(:));
    temp_data       = double(history.temperature(:));
    wind_data       = double(history.wind_speed(:));
    T_total = length(load_data);
    % Verify all series have equal length
    if any([length(irr_data), length(temp_data), length(wind_data)] ~= T_total)
        error('All time series in history must have the same length.');
    end

    % Define sliding window length and forecast horizon
    win = 24;                     % window size (e.g. 24 hours of history for prediction)
    forecastHorizon = 24;         % forecast 24 hours ahead

    % Determine last index to use for training (exclude last 24 hours for testing)
    T_train_end = T_total - forecastHorizon;
    if T_train_end <= win
        error('Not enough data points (%d) for the specified window size (%d) + 24 forecast.', T_total, win);
    end

    % Construct training sequences (XTrain) and targets (YTrain)
    N = T_train_end - win;                  % number of training samples
    XTrain = cell(N, 1);
    YTrain = zeros(N, 4);
    for i = 1:N
        % Input window [i ... i+win-1] for all 4 variables
        idxStart = i;
        idxEnd   = i + win - 1;
        % Each XTrain{i} is 4 x win (rows = variables, cols = time steps in window)
        XTrain{i} = [ ...
            load_data(idxStart:idxEnd)'; ...
            irr_data(idxStart:idxEnd)'; ...
            temp_data(idxStart:idxEnd)'; ...
            wind_data(idxStart:idxEnd)'  ];
        % Next hour values (at i+win) for each variable as target
        YTrain(i, :) = [ ...
            load_data(i+win), ...
            irr_data(i+win), ...
            temp_data(i+win), ...
            wind_data(i+win) ];
    end
    % XTrain is a cell array of 4xwin sequences, YTrain is an N×4 numeric matrix (no NaNs)

    % Define LSTM network architecture (4 inputs -> 4 outputs)
    inputSize = 4;
    numResponses = 4;
    numHiddenUnits = 100;
    layers = [ ...
        sequenceInputLayer(inputSize)
        lstmLayer(numHiddenUnits, 'OutputMode','last')
        fullyConnectedLayer(numResponses)
        regressionLayer ];

    % Training options (adjust epochs, mini-batch, etc., as needed)
    miniBatchSize = min(64, N);
    options = trainingOptions('adam', ...
        'MaxEpochs', 200, ...
        'MiniBatchSize', miniBatchSize, ...
        'GradientThreshold', 1, ...
        'InitialLearnRate', 0.005, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', 0, ...
        'Plots', 'training-progress');

    % Train the LSTM network
    net = trainNetwork(XTrain, YTrain, layers, options);

    % Closed-loop forecasting for 24 hours ahead
    % Start with the last 'win' hours of training data as initial sequence
    initialSeqStart = T_train_end - win + 1;
    initialSeqEnd   = T_train_end;
    initialSequence = [ ...
        load_data(initialSeqStart:initialSeqEnd)'; ...
        irr_data(initialSeqStart:initialSeqEnd)'; ...
        temp_data(initialSeqStart:initialSeqEnd)'; ...
        wind_data(initialSeqStart:initialSeqEnd)' ];
    % Reset network state and make initial prediction for t = T_train_end + 1
    net = resetState(net);
    [net, firstPred] = predictAndUpdateState(net, initialSequence);
    % Store the first predicted 1-hour ahead values
    predictions = zeros(forecastHorizon, 4);
    predictions(1, :) = firstPred(:)';   % ensure row vector

    % Iteratively predict subsequent hours, feeding back previous prediction
    for t = 2:forecastHorizon
        % Ensure the input is a 4×1 sequence (4 features for 1 time step)
        [net, pred] = predictAndUpdateState(net, predictions(t-1, :)');
        predictions(t, :) = pred(:)';
    end

    % Prepare output struct with 24x1 vectors for each variable
    forecasts = struct();
    forecasts.load        = predictions(:, 1);
    forecasts.irradiance  = predictions(:, 2);
    forecasts.temperature = predictions(:, 3);
    forecasts.wind_speed  = predictions(:, 4);

    % Plot actual vs forecast for each variable over the 24-hour horizon
    actualIdxStart = T_train_end + 1;              % first hour of actual data not used in training
    actualIdxEnd   = T_total;                      % last hour of actual data
    hours = 1:forecastHorizon;                     % relative hour indices for plotting
    actual24 = [ ...
        load_data(actualIdxStart:actualIdxEnd), ...
        irr_data(actualIdxStart:actualIdxEnd), ...
        temp_data(actualIdxStart:actualIdxEnd), ...
        wind_data(actualIdxStart:actualIdxEnd) ];
    figure;
    titles = {"Load", "Irradiance", "Temperature", "Wind Speed"};
    for v = 1:4
        subplot(2,2,v);
        plot(hours, actual24(:, v), 'b-o', 'LineWidth', 1.5); hold on;
        plot(hours, predictions(:, v), 'r--*', 'LineWidth', 1.5);
        title(titles{v});
        xlabel('Hour');
        ylabel('Value');
        legend('Actual', 'Forecast');
        grid on;
    end
    sgtitle('24-Hour Forecast vs Actual');
end
