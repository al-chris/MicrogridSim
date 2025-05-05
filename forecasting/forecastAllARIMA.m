function forecasts = forecastAllARIMA(history)
%forecastAllARIMA 24h ARIMA forecasts for load, irradiance, temp, wind
%   history: struct with fields load, irradiance, temperature, wind
    series = {'load','irradiance','temperature','wind_speed'};
    forecasts = struct(); h=24; 
    for s=series
        y = history.(s{1});
        %model = arima(y,'D',0); % auto-select orders
        %[yf,~] = forecast(model,h,'Y0',y);
        
        % Manually specify ARIMA orders (e.g., ARIMA(1,1,1))
        model = arima(1, 1, 1);  % AR(1), I(1), MA(1) model
        
        % Estimate the model parameters
        modelFit = estimate(model, y);

        % Forecast 24 steps ahead
        [yf, ~] = forecast(modelFit, h, 'Y0', y);
        forecasts.(s{1}) = yf;
    end
end
