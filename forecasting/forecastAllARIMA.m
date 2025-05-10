function forecasts = forecastAllARIMA(history)
%forecastAllARIMA_final 24h ARIMA forecasts for load, irradiance, temp, wind
%   history: struct with fields load, irradiance, temperature, wind_speed
%   Using optimized models based on AIC/BIC comparison and residual analysis
    
    series = {'load','irradiance','temperature','wind_speed'};
    forecasts = struct(); 
    numForecasts = 24; % Forecast horizon (24 hours)
    
    for s = series
        seriesName = s{1};
        y = history.(seriesName); % Access the time series data for each variable
        
        % Check if the series is stationary using ADF test
        [h, pValue, stat, criticalValues] = adftest(y);
        
        % Report stationarity results
        if h == 0
            disp([seriesName ' is non-stationary, differencing applied']);
        else
            disp([seriesName ' is stationary']);
        end
        
        % Create optimal model for each variable based on model selection results
        switch seriesName
            case 'load'
                % Best model from selection: ARIMA(3,1,2)
                model = arima('Constant', 0, 'D', 1, ...
                              'ARLags', [1,2,3], 'MALags', [1,2]);
                disp('Using ARIMA(3,1,2) for load');
                
            case 'irradiance'
                % Best model from selection: ARIMA(3,1,1)
                model = arima('Constant', 0, 'D', 1, ...
                              'ARLags', [1,2,3], 'MALags', 1);
                disp('Using ARIMA(3,1,1) for irradiance');
                
            case 'temperature'
                % Best model from testing: ARIMA(0,1,1)
                model = arima('Constant', 0, 'D', 1, 'MALags', 1);
                disp('Using ARIMA(0,1,1) for temperature');
                
            case 'wind_speed'
                % Consider a slightly more complex model since residuals were not white noise
                model = arima('Constant', 0, 'D', 1, 'MALags', [1,2]);
                disp('Using ARIMA(0,1,2) for wind_speed');
        end
        
        % Fit model, generate forecasts, and perform diagnostics
        try
            % Estimate the model parameters
            modelFit = estimate(model, y);
            
            % Report AIC and BIC
            summary = summarize(modelFit);
            aic = summary.AIC;
            bic = summary.BIC;
            disp(['AIC: ', num2str(aic)]);
            disp(['BIC: ', num2str(bic)]);
            
            % Forecast 24 steps ahead
            [yf, yMSE] = forecast(modelFit, numForecasts, 'Y0', y);
            
            % Calculate confidence intervals (95%)
            conf_int = 1.96*sqrt(yMSE);
            lower_bound = yf - conf_int;
            upper_bound = yf + conf_int;
            
            % Store the forecasted values and confidence intervals
            forecasts.(seriesName) = yf;
            forecasts.([seriesName '_lower']) = lower_bound;
            forecasts.([seriesName '_upper']) = upper_bound;
            
            % Analyze residuals
            [residuals,~,logL] = infer(modelFit, y);
            
            % Create comprehensive diagnostic plots
            figure;
            subplot(2,2,1);
            autocorr(residuals);
            title([seriesName ' - Residual ACF']);
            
            subplot(2,2,2);
            parcorr(residuals);
            title([seriesName ' - Residual PACF']);
            
            subplot(2,2,3);
            histogram(residuals, 'Normalization', 'pdf');
            hold on;
            x = linspace(min(residuals), max(residuals), 100);
            mu = mean(residuals);
            sigma = std(residuals);
            y_norm = normpdf(x, mu, sigma);
            plot(x, y_norm, 'r-', 'LineWidth', 2);
            title('Residual Distribution vs. Normal');
            
            subplot(2,2,4);
            qqplot(residuals);
            title('Q-Q Plot of Residuals');
            
            % Perform comprehensive residual tests
            [h_lb, p_lb] = lbqtest(residuals, 'Lags', [10, 15, 20]);
            [h_jb, p_jb] = jbtest(residuals);  % Test for normality
            
            disp(['Ljung-Box p-values at lags 10,15,20: ', num2str(p_lb)]);
            if h_jb == 0
                disp('Residuals are normally distributed (Jarque-Bera test)');
            else
                disp(['Residuals are not normally distributed, p-value: ', num2str(p_jb)]);
            end
            
            % Plot forecasts with confidence intervals
            figure;
            t = (1:length(y))';
            t_forecast = (length(y)+1:length(y)+numForecasts)';
            
            plot(t, y, 'b-', 'LineWidth', 1.5);
            hold on;
            plot(t_forecast, yf, 'r-', 'LineWidth', 1.5);
            plot(t_forecast, lower_bound, 'r--', 'LineWidth', 1);
            plot(t_forecast, upper_bound, 'r--', 'LineWidth', 1);
            legend('Historical Data', 'Forecast', '95% Confidence Interval');
            title([seriesName ' - 24-Hour Forecast']);
            xlabel('Time Step');
            ylabel('Value');
            grid on;
            
        catch ME
            % If model estimation fails, inform user and try simpler model
            warning(['Model estimation failed for ' seriesName ': ' ME.message]);
            disp(['Trying fallback model for ' seriesName]);
            
            % Use simplest possible model as fallback
            fallbackModel = arima('Constant', 0, 'D', 1);
            modelFit = estimate(fallbackModel, y);
            
            % Generate forecasts with fallback model
            [yf, ~] = forecast(modelFit, numForecasts, 'Y0', y);
            forecasts.(seriesName) = yf;
            
            disp('Fallback model used for forecasting');
        end
    end
    
    % Optional: create comparative plot of all forecasts
    figure;
    t = 1:numForecasts;
    
    % Normalize each forecast to its maximum for comparison
    for s = series
        name = s{1};
        if isfield(forecasts, name)
            fcast = forecasts.(name);
            norm_fcast = (fcast - min(fcast)) / (max(fcast) - min(fcast) + eps);
            plot(t, norm_fcast, 'LineWidth', 2);
            hold on;
        end
    end
    
    legend(series, 'Location', 'best');
    title('Normalized 24-Hour Forecasts for All Variables');
    xlabel('Hours Ahead');
    ylabel('Normalized Value');
    grid on;
end