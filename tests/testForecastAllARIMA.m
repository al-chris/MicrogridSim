% filepath: tests/testForecastAllARIMA.m

addpath('c:\Users\CHRISTOPHER\Documents\MATLAB\MicrogridSim\forecasting')

function tests = test_ForecastAllARIMA
    tests = functiontests(localfunctions);
end

function testForecastOutput(testCase)
    % Create dummy historical data
    history.load = rand(48,1)*100 + 50;         % kW
    history.irradiance = rand(48,1)*800;        % W/m^2
    history.temperature = rand(48,1)*15 + 15;   % deg C
    history.wind_speed = rand(48,1)*10;         % m/s

    % Call the forecast function
    forecast = forecastAllARIMA(history);

    % Check that output fields exist
    verifyTrue(testCase, isfield(forecast, 'load'));
    verifyTrue(testCase, isfield(forecast, 'irradiance'));
    verifyTrue(testCase, isfield(forecast, 'temperature'));
    verifyTrue(testCase, isfield(forecast, 'wind_speed'));

    % Check that outputs are column vectors of length 24
    verifyEqual(testCase, size(forecast.load,1), 24);
    verifyEqual(testCase, size(forecast.irradiance,1), 24);
    verifyEqual(testCase, size(forecast.temperature,1), 24);
    verifyEqual(testCase, size(forecast.wind_speed,1), 24);

    % Check that outputs are numeric
    verifyClass(testCase, forecast.load, 'double');
    verifyClass(testCase, forecast.irradiance, 'double');
    verifyClass(testCase, forecast.temperature, 'double');
    verifyClass(testCase, forecast.wind_speed, 'double');
end