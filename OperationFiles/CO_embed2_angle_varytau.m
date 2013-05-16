function out = CO_embed2_angle_varytau(y,maxtau)
% looks at how properties in two-dimensional embedding space change as vary tau
% Ben Fulcher September 2009

taur = 1:maxtau;
ntaur = length(taur);

if size(y,2)>size(y,1); y=y'; end

stats_store = zeros(3,ntaur);

for i = 1:ntaur

	tau=taur(i);
	
	m=[y(1:end-tau) y(1+tau:end)];

	theta = diff(m(:,2))./diff(m(:,1));
	theta = atan(theta); % measured as deviation from the horizontal

	stats_store(1,i) = CO_autocorr(theta,1);
	stats_store(2,i) = CO_autocorr(theta,2);
	stats_store(3,i) = CO_autocorr(theta,3);

end

% plot(stats_store');

out.ac1_thetaac1 = CO_autocorr(stats_store(1,:),1);
out.ac1_thetaac2 = CO_autocorr(stats_store(2,:),1);
out.ac1_thetaac3 = CO_autocorr(stats_store(3,:),1);
out.mean_thetaac1 = mean(stats_store(1,:));
out.max_thetaac1 = max(stats_store(1,:));
out.min_thetaac1 = min(stats_store(1,:));
out.mean_thetaac2 = mean(stats_store(2,:));
out.max_thetaac2 = max(stats_store(2,:));
out.min_thetaac2 = min(stats_store(2,:));
out.mean_thetaac3 = mean(stats_store(3,:));
out.max_thetaac3 = max(stats_store(3,:));
out.min_thetaac3 = min(stats_store(3,:));
out.meanrat_thetaac12 = out.mean_thetaac1/out.mean_thetaac2;
out.diff_thetaac12 = sum(abs(stats_store(2,:)-stats_store(1,:)));





end