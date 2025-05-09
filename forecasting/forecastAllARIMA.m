function forecasts = forecastAllARIMA(history)
%forecastAllARIMA 24h ARIMA forecasts for load, irradiance, temp, wind
%   history: struct with fields load, irradiance, temperature, wind
    series = {'load','irradiance','temperature','wind_speed'};
    forecasts = struct(); 
    h = 24; % Forecast horizon (24 hours)
    
    for s = series
        y = history.(s{1}); % Access the time series data for each variable
        
        % Check if the series is stationary using ADF test
        [h, pValue, stat, criticalValues] = adftest(y);
        
        % If non-stationary, apply differencing (d=1)
        if h == 0
            disp([s{1} ' is non-stationary, differencing applied']);
            y = diff(y); % Apply first differencing
        else
            disp([s{1} ' is stationary']);
        end
        
        % Identify AR(p) and MA(q) orders using ACF and PACF
        figure;
        subplot(2,1,1);
        autocorr(y);
        title([s{1} ' - ACF']);
        
        subplot(2,1,2);
        parcorr(y);
        title([s{1} ' - PACF']);
        
        % Based on ACF and PACF, choose p=1 and q=1 (as seen from the plots)
        p = 1;  % AR(1) component based on PACF
        q = 1;  % MA(1) component based on ACF
        
        % Fit ARIMA model
        model = arima('Constant', 0, 'D', 1, 'ARLags', p, 'MALags', q);
        
        % Estimate the model parameters
        modelFit = estimate(model, y);
        
        % Get model summary (including AIC and BIC)
        summary = summarize(modelFit);
        aic = summary.AIC;
        bic = summary.BIC;
        disp(['AIC: ', num2str(aic)]);
        disp(['BIC: ', num2str(bic)]);
        
        % Forecast 24 steps ahead
        numForecasts = 24; % Forecast horizon set as a numeric value
        [yf, ~] = forecast(modelFit, numForecasts, 'Y0', y);
        
        % Store the forecasted values
        forecasts.(s{1}) = yf;
        
        % Check residuals
        [residuals,~,logL] = infer(modelFit, y);
        
        % Plot residuals to check for white noise
        figure;
        subplot(2,1,1);
        autocorr(residuals);
        title([s{1} ' - Residual ACF']);
        
        subplot(2,1,2);
        parcorr(residuals);
        title([s{1} ' - Residual PACF']);
        
        % Perform Ljung-Box test on residuals
        [h, pValue] = lbqtest(residuals, 'Lags', 10);
        if h == 0
            disp([s{1} ' residuals are white noise']);
        else
            disp([s{1} ' residuals are not white noise']);
        end
        
        % Additional adjustments for irradiance (Seasonal ARIMA)
        if strcmp(s{1}, 'irradiance')
            disp('Applying Seasonal ARIMA for irradiance');
            % Seasonal ARIMA model (SARIMA) for irradiance
            % Set 'Seasonality' to 24 for hourly data with daily seasonality
            seasonalModel = arima('Constant', 0, 'D', 1, 'Seasonality', 24, 'SARLags', 1, 'SMALags', 1, 'ARLags', 1, 'MALags', 1);
            
            % Estimate the seasonal model
            seasonalModelFit = estimate(seasonalModel, y);
            
            % Forecast 24 steps ahead
            [seasonalForecast, ~] = forecast(seasonalModelFit, numForecasts, 'Y0', y);
            forecasts.irradiance = seasonalForecast;
        end
    end
end
