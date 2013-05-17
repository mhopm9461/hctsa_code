function out = MF_compare_garch(y,preproc,pr,qr)
% Compares a bunch of GARCH(P,Q) models to each other, returns statistics on the
% best ones. This one focuses on the GARCH/variance component, and therefore
% attempts to pre-whiten and assumes a constant mean process.
% Uses MATLAB Econometrics Toolbox
% Ben Fulcher 26/2/2010


%% Inputs

if nargin<2 || isempty(preproc)
    preproc = 'ar'; % do the preprocessing that maximizes ar(2) whiteness
end

% GARCH parameters, p & q
if nargin<3 || isempty(pr)
    pr = 1:4; %GARCH(1:4,qr)
end
if nargin<4 || isempty(qr)
    qr = 1:4; % GARCH(pr,1:4);
end


%% (1) Data preprocessing
y0 = y; % the original, unprocessed time series

switch preproc
    case 'nothing'
        % do nothing.
    case 'ar'
        % apply a number of standard preprocessings and return them in the
        % structure ypp. Also chooses the best preprocessing based on the worst fit
        % of an AR2 model to the processed time series.
        % has to beat doing nothing by 5% (error)
        % No spectral methods allowed...
        [ypp best] = benpp(y,'ar',2,0.05,0);
        eval(['y = ypp.' best ';']);
        disp(['Proprocessed according to AR(2) criterion using ' best]);
end

y = benzscore(y);
N = length(y); % could be different to original (if choose a differencing, e.g.)

% Now have the preprocessed time series saved over y.
% The original, unprocessed time series is retained in y0.
% (Note that y=y0 is possible; when all preprocessings are found to be
%   worse at the given criterion).

%% (2) Data pre-estimation
% Aim is to return some statistics indicating the suitability of this class
% of modeling.
% Will use the statistics to motivate a GARCH model in the next
% section.
% Will use the statistics to compare to features of the residuals after
% modeling.

% (i) Engle's ARCH test
%       look at autoregressive lags 1:20
%       use the 10% significance level
[Engle_h_y, Engle_pValue_y, Engle_stat_y, Engle_cValue_y] = archtest(y,1:20,0.1);

% (ii) Ljung-Box Q-test
%       look at autocorrelation at lags 1:20
%       use the 10% significance level
%       departure from randomness hypothesis test
[lbq_h_y2, lbq_pValue_y2, lbq_stat_y2, lbq_cValue_y2] = lbqtest(y.^2,1:20,0.1);
% [lbq_h_y2, lbq_pValue_y2, lbq_stat_y2, lbq_cValue_y2] = lbqtest(y.^2,1:20,0.1,[]);


% (iii) Correlation in time series: autocorrelation
% autocorrs_y = CO_autocorr(y,1:20);
% autocorrs_var = CO_autocorr(y.^2,1:20);
[ACF_y,Lags_acf_y,bounds_acf_y] = autocorr(y,20,[],[]);
[ACF_var_y,Lags_acf_var_y,bounds_acf_var_y] = autocorr(y.^2,20,[],[]);

% (iv) Partial autocorrelation function: PACF
[PACF_y,Lags_pacf_y,bounds_pacf_y] = parcorr(y,20,[],[]);


%% (3) Create an appropriate GARCH model
% initialize statistics
np = length(pr);
nq = length(qr);
LLFs = zeros(np,nq); % log-likelihood
AICs = zeros(np,nq); % AIC
BICs = zeros(np,nq); % BIC
Ks = zeros(np,nq); % constant term in variance
meanarchps = zeros(np,nq); % mean over 20 lags from Engle's ARCH test on standardized innovations
maxarchps = zeros(np,nq); % maximum p-value over 20 lags from Engle's ARCH test on standardized innovations
meanlbqps = zeros(np,nq); % mean lbq p-value over 20 lags from Q-test on squared standardized innovations
maxlbqps = zeros(np,nq); % maximum p-value over 20 lags from Q-test on squared standardized innovations

for i=1:np
    p = pr(i); % garch order
    for j=1:nq
       q = qr(j); % arch order
       
       % (i) specify a zero-mean, Gaussian innovation GARCH(P,Q) model.
       spec = garchset('P',p,'Q',q,'C',NaN);
       
       % (ii) fit the model
       [coeff,errors,LLF,innovations,sigmas,summary] = garchfit(spec,y);
       
       % (iii) store derived statistics on the fitted model
       LLFs(i,j) = LLF;
       nparams = garchcount(coeff); % number of parameters
       [AIC, BIC] = aicbic(LLF,nparams,N); % aic and bic of fit
       AICs(i,j) = AIC;
       BICs(i,j) = BIC;
       Ks(i,j) = coeff.K;
       
       % (iv) store summaries of standardized errors
       %    (less need to compare to original because now we're only
       %    comparing *between* models, which should all have the same
       %    baseline...?) It's just that the absolute values of these
       %    summaries are less meaningful; should be with respect to the
       %    original time series
       stde = innovations./sigmas; % standardized residuals
       stde2 = stde.^2;
       
       % (i) Engle's ARCH test
       %       look at autoregressive lags 1:20
       [Engle_h_stde, Engle_pValue_stde, Engle_stat_stde, Engle_cValue_stde] = archtest(stde,1:20,0.1);
       
       meanarchps(i,j) = mean(Engle_pValue_stde);
       maxarchps(i,j) = max(Engle_pValue_stde);
       
       % (ii) Ljung-Box Q-test
       %       look at autocorrelation at lags 1:20
       %       use the 10% significance level
       %       departure from randomness hypothesis test
       [lbq_h_stde2, lbq_pValue_stde2, lbq_stat_stde2, lbq_cValue_stde2] = lbqtest(stde2,1:20,0.1,[]);
       
       meanlbqps(i,j) = mean(lbq_pValue_stde2);
       maxlbqps(i,j) = max(lbq_pValue_stde2);
       
       
       % Difficult to take parameter values since their number if
       % changing...
    end
end


%% Statistics on retrieved model summaries
% 'whole things'
out.minLLF = min(LLFs(:));
out.maxLLF = max(LLFs(:));
out.meanLLF = mean(LLFs(:));
out.minBIC = min(BICs(:));
out.maxBIC = max(BICs(:));
out.meanBIC = mean(BICs(:));
out.minAIC = min(AICs(:));
out.maxAIC = max(AICs(:));
out.meanAIC = mean(AICs(:));
out.minK = min(Ks(:));
out.maxK = max(Ks(:));
out.meanK = mean(Ks(:));
out.min_meanarchps = min(meanarchps(:));
out.max_meanarchps = max(meanarchps(:));
out.mean_meanarchps = mean(meanarchps(:));
out.min_maxarchps = min(maxarchps(:));
out.max_maxarchps = max(maxarchps(:));
out.mean_maxarchps = mean(maxarchps(:));
out.min_meanlbqps = min(meanlbqps(:));
out.max_meanlbqps = max(meanlbqps(:));
out.mean_meanlbqps = mean(meanlbqps(:));
out.min_maxlbqps = min(maxlbqps(:));
out.max_maxlbqps = max(maxlbqps(:));
out.mean_maxlbqps = mean(maxlbqps(:));


% 'bests' (orders)
[a b] = find(LLFs == min(LLFs(:)),1,'first');
out.bestpLLF = pr(a);
out.bestqLLF = qr(b);

[a b] = find(AICs == min(AICs(:)),1,'first');
out.bestpAIC = pr(a);
out.bestqAIC = qr(b);

[a b] = find(BICs == min(BICs(:)),1,'first');
out.bestpAIC = pr(a);
out.bestqAIC = qr(b);

% 'trends' in each direction -- i.e., how much effect on the statistics
% does changing the order (either p or q) have. Sometimes changing q will
% have negligible effect -- we want to quantify this.

out.Ks_vary_p = mean(std(Ks)); % mean variation along p direction
out.Ks_vary_q = mean(std(Ks')); % mean variation along q direction


end