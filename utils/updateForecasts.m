function data = updateForecasts(data, history, method, nForecast)
% UPDATEFORECASTS Updates data with forecasts using specified method
% 
% Inputs:
%   data - struct containing the original data
%   history - struct containing historical data series
%   method - string, either "arima" or "lstm"
%   nForecast - number of hours to forecast (default: 24)
%
% Output:
%   data - updated data struct with forecasts appended

if nargin < 4
    nForecast = 24;
end

% Get forecasts based on specified method
if strcmpi(method, "arima")
    forecast = forecastAllARIMA(history);
elseif strcmpi(method, "lstm")
    forecast = forecastAllLSTM(history);
else
    error('Invalid forecast method. Use "arima" or "lstm"');
end

% Update data with forecasts (ensuring values are valid)
data.load        = [history.load;        max(forecast.load, 0)];
data.irradiance  = [history.irradiance;  max(forecast.irradiance, 0)];
data.temperature = [history.temperature; forecast.temperature];
data.wind_speed  = [history.wind_speed;  max(forecast.wind_speed, 0)];

end