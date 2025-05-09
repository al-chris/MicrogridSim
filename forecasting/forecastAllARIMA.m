function forecasts = forecastAllARIMA(history)
%forecastAllARIMA 24h ARIMA forecasts for load, irradiance, temp, wind
%   history: struct with fields load, irradiance, temperature, wind_speed
    series = {'load','irradiance','temperature','wind_speed'};
    forecasts = struct(); 
    numForecasts = 24; % Forecast horizon (24 hours)
    
    for s = series
        seriesName = s{1};
        y = history.(seriesName); % Access the time series data for each variable
        
        % Check if the series is stationary using ADF test
        [h, pValue, stat, criticalValues] = adftest(y);
        
        % If non-stationary, apply differencing (d=1)
        if h == 0
            disp([seriesName ' is non-stationary, differencing applied']);
            y_diff = diff(y); % Apply first differencing
            d = 1;
        else
            disp([seriesName ' is stationary']);
            y_diff = y;
            d = 0;
        end
        
        % Identify AR(p) and MA(q) orders using ACF and PACF
        figure;
        subplot(2,1,1);
        autocorr(y_diff);
        title([seriesName ' - ACF']);
        
        subplot(2,1,2);
        parcorr(y_diff);
        title([seriesName ' - PACF']);
        
        % Use optimized model parameters for each series
        switch seriesName
            case 'load'
                % Based on results, simplify the load model 
                % Try ARIMA(2,1,2) instead of the seasonal model which had estimation issues
                model = arima('Constant', 0, 'D', 1, 'ARLags', [1,2], 'MALags', [1,2]);
                disp('Using ARIMA(2,1,2) for load');
                
            case 'irradiance'
                % Seasonal model for irradiance with daily pattern
                % Use proper MATLAB syntax for seasonal differencing with 'Seasonality' and 'D'
                model = arima('Constant', 0, 'D', 1, 'ARLags', 1, 'MALags', 1, ...
                             'Seasonality', 24, 'SARLags', 1, 'SMALags', 1);
                disp('Using SARIMA(1,1,1)(1,0,1)_24 for irradiance');
                
                % Try a different more complex seasonal model if requested
                % Uncomment below to try an alternative model with higher order components
                % model = arima('Constant', 0, 'D', 1, 'ARLags', [1,2], 'MALags', 1, ...
                %              'Seasonality', 24, 'SARLags', [1,24], 'SMALags', [1,24]);
                % disp('Using complex SARIMA for irradiance');
                
            case 'temperature'
                % Simpler model for temperature as AR(1) and MA(1) were not significant
                model = arima('Constant', 0, 'D', 1, 'MALags', 1);
                disp('Using ARIMA(0,1,1) for temperature');
                
            case 'wind_speed'
                % Simpler model for wind as neither AR nor MA was significant
                model = arima('Constant', 0, 'D', 1);
                disp('Using ARIMA(0,1,0) for wind_speed');
        end
        
        % Estimate the model parameters
        try
            modelFit = estimate(model, y);
            
            % Get model summary (including AIC and BIC)
            summary = summarize(modelFit);
            aic = summary.AIC;
            bic = summary.BIC;
            disp(['AIC: ', num2str(aic)]);
            disp(['BIC: ', num2str(bic)]);
            
            % Forecast 24 steps ahead
            [yf, ~] = forecast(modelFit, numForecasts, 'Y0', y);
            
            % Store the forecasted values
            forecasts.(seriesName) = yf;
            
            % Check residuals
            [residuals,~,logL] = infer(modelFit, y);
            
            % Plot residuals to check for white noise
            figure;
            subplot(2,2,1);
            autocorr(residuals);
            title([seriesName ' - Residual ACF']);
            
            subplot(2,2,2);
            parcorr(residuals);
            title([seriesName ' - Residual PACF']);
            
            % Add histograms and Q-Q plots for residuals
            subplot(2,2,3);
            histogram(residuals);
            title('Histogram of Residuals');
            
            subplot(2,2,4);
            qqplot(residuals);
            title('Q-Q Plot of Residuals');
            
            % Perform Ljung-Box test on residuals
            [h, pValue] = lbqtest(residuals, 'Lags', [10, 15, 20]);
            if all(h == 0)
                disp([seriesName ' residuals are white noise']);
            else
                disp([seriesName ' residuals are not white noise']);
                disp(['p-values at lags 10,15,20: ', num2str(pValue)]);
            end
            
        catch ME
            % If the model estimation fails, try a simpler model
            warning(['Model estimation failed for ' seriesName ': ' ME.message]);
            disp(['Trying simpler model for ' seriesName]);
            
            % Fallback to simpler model
            fallbackModel = arima('Constant', 0, 'D', 1);
            modelFit = estimate(fallbackModel, y);
            
            % Forecast with simpler model
            [yf, ~] = forecast(modelFit, numForecasts, 'Y0', y);
            forecasts.(seriesName) = yf;
        end
        
        % Compare forecast with actual values (if available)
        if length(y) > numForecasts*2
            % Use last numForecasts points for validation
            y_train = y(1:end-numForecasts);
            y_test = y(end-numForecasts+1:end);
            
            % Estimate the model on training data
            test_model = estimate(model, y_train);
            [y_pred, ~] = forecast(test_model, numForecasts, 'Y0', y_train);
            
            % Calculate error metrics
            mse = mean((y_pred - y_test).^2);
            mae = mean(abs(y_pred - y_test));
            
            % Avoid division by zero in MAPE calculation
            nonZeroIdx = y_test ~= 0;
            if any(nonZeroIdx)
                mape = mean(abs((y_pred(nonZeroIdx) - y_test(nonZeroIdx))./y_test(nonZeroIdx))) * 100;
                disp(['MAPE: ', num2str(mape), '%']);
            else
                disp('MAPE calculation skipped due to zero values in test data');
            end
            
            disp(['MSE: ', num2str(mse)]);
            disp(['MAE: ', num2str(mae)]);
            
            % Plot forecasts vs actual values
            figure;
            plot(1:numForecasts, y_test, 'b-', 1:numForecasts, y_pred, 'r--');
            legend('Actual', 'Forecast');
            title([seriesName ' - Forecast vs Actual']);
            
            % Add a second evaluation with additional metrics
            % Try a model selection approach for the best ARIMA model
            if strcmp(seriesName, 'load') || strcmp(seriesName, 'irradiance')
                disp(['Performing model selection for ' seriesName]);
                best_aic = Inf;
                best_model = [];
                
                % Define a grid of models to try
                p_values = 0:3;
                q_values = 0:3;
                
                for p = p_values
                    for q = q_values
                        if p == 0 && q == 0
                            continue; % Skip ARIMA(0,1,0) as it's our fallback
                        end
                        
                        try
                            % Create and estimate model
                            if p > 0 && q > 0
                                test_arima = arima('Constant', 0, 'D', 1, 'ARLags', 1:p, 'MALags', 1:q);
                            elseif p > 0
                                test_arima = arima('Constant', 0, 'D', 1, 'ARLags', 1:p);
                            elseif q > 0
                                test_arima = arima('Constant', 0, 'D', 1, 'MALags', 1:q);
                            end
                            
                            test_fit = estimate(test_arima, y_train);
                            test_summary = summarize(test_fit);
                            
                            if test_summary.AIC < best_aic
                                best_aic = test_summary.AIC;
                                best_model = test_fit;
                                disp(['New best model: ARIMA(' num2str(p) ',1,' num2str(q) ') with AIC: ' num2str(best_aic)]);
                            end
                        catch
                            % Skip if estimation fails
                            disp(['Model estimation failed for ARIMA(' num2str(p) ',1,' num2str(q) ')']);
                        end
                    end
                end
                
                if ~isempty(best_model)
                    % Re-forecast with best model
                    [best_pred, ~] = forecast(best_model, numForecasts, 'Y0', y_train);
                    best_mse = mean((best_pred - y_test).^2);
                    
                    disp(['Best model MSE: ', num2str(best_mse)]);
                    if best_mse < mse
                        disp('Best model outperforms the predefined model!');
                        
                        % Plot comparison
                        figure;
                        plot(1:numForecasts, y_test, 'b-', 1:numForecasts, y_pred, 'r--', 1:numForecasts, best_pred, 'g-.');
                        legend('Actual', 'Predefined Model', 'Best AIC Model');
                        title([seriesName ' - Model Comparison']);
                    end
                end
            end
        end
    end
end