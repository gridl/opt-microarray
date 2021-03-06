alpha_range = -2:1:2;
beta_range = -2:1:2;
%alpha_range = -2:0.25:2;
%beta_range = -2:0.25:4;

mad_A = zeros(length(alpha_range), length(beta_range));
outliers_A = zeros(length(alpha_range), length(beta_range));
mad_B = zeros(length(alpha_range), length(beta_range));
outliers_B = zeros(length(alpha_range), length(beta_range));
mad_C = zeros(length(alpha_range), length(beta_range));
outliers_C = zeros(length(alpha_range), length(beta_range));
concentration_dists = zeros(length(alpha_range), length(beta_range));
goodness_of_fit_fro = zeros(length(alpha_range), length(beta_range));
goodness_of_fit_geman = zeros(length(alpha_range), length(beta_range));
goodness_of_fit_huber = zeros(length(alpha_range), length(beta_range));
overfitting_native = zeros(length(alpha_range), length(beta_range));
overfitting_fro = zeros(length(alpha_range), length(beta_range));
overfitting_huber = zeros(length(alpha_range), length(beta_range));
converged_cnt_full = zeros(length(alpha_range), length(beta_range));
converged_cnt_fixedA = zeros(length(alpha_range), length(beta_range));
divergence_value = zeros(length(alpha_range), length(beta_range));
zero_influence = zeros(length(alpha_range), length(beta_range));
outliers_influence = zeros(length(alpha_range), length(beta_range));
zero_influence_ratio = zeros(length(alpha_range), length(beta_range));
outliers_influence_ratio = zeros(length(alpha_range), length(beta_range));
norm_problems_cnt = zeros(length(alpha_range), length(beta_range));
corr_B = zeros(length(alpha_range), length(beta_range));

%inten = inten_full;
%inten_sliced = inten_full_sliced;

inten = inten_full(:, [1:100 1001:1002]);
inten_sliced = inten_full_sliced;
for i = 1:length(inten_sliced)
    inten_sliced{i} = inten_sliced{i}(:, 1:100);
end

inten_test = inten_full(:, 901:end);
inten_test_sliced = inten_full_sliced;
for i = 1:length(inten_test_sliced)
    inten_test_sliced{i} = inten_test_sliced{i}(:, 901:end);
end

fprintf('Generating partitions...');
[partition_arrays, partition_probes, partition_probes_compl, partition_probes_sliced, partition_probes_sliced_compl] = ...
   generate_partitions(inten, inten_sliced, inten_full_idx);
fprintf(' Done\n');
%load('alpha_beta_partition.mat');

maxIterCnt = 500;

%for i = 1:length(alpha_range)
%    for j = 1:length(beta_range)
i = 1;
j = 3;
        alpha = alpha_range(i);
        beta = beta_range(j);
        fprintf('Alpha = %f, Beta = %f\n', alpha, beta);

        fprintf('Factorizing partitions of I...');
        [mad_A(i, j), outliers_A(i, j), mad_B(i, j), outliers_B(i, j), mad_C(i, j), outliers_C(i, j), ...
            arrays_factors, probes_factors] = ...
            get_quality_cv_nonlinear(inten, inten_sliced, inten_full_idx, ...
            @(I) nonlinear_alpha_beta(I, alpha, beta, maxIterCnt, 1e-6, 0, 0, 1), partition_arrays, partition_probes, partition_probes_compl, ...
            partition_probes_sliced, partition_probes_sliced_compl);
        fprintf(' Done\n');
        
        conc_gene_dist = zeros(size(probes_factors{3}, 1), 1);
        for k = 1:length(conc_gene_dist)
            conc_gene_dist(k) = Cdist(probes_factors{3}(k, :), probes_factors{10}(k, :));
        end
        concentration_dists(i, j) = mad(conc_gene_dist);
        
        fprintf('Factorizing I...');
        [A, B, C, Avect, Bvect, A_sliced, B_sliced, converged_cnt_full(i, j), norm_problems_cnt(i, j)] = nonlinear_calibrate_model(inten, inten_sliced, ...
            inten_full_idx, @(I) nonlinear_alpha_beta(I, alpha, beta, maxIterCnt, 1e-6, 0, 0, 1), false);
        fprintf(' Done\n');
        
        fprintf('Factorizing I_test with fixed A...');
        [C_test converged_cnt_fixedA(i, j)] = nonlinear_find_concentrations(inten_test_sliced, A_sliced, B_sliced, ...
            @(I_arg, A_arg, B_arg) nonlinear_alpha_beta_fixedAB(I_arg, A_arg, B_arg, alpha, beta, maxIterCnt, 1e-6, 0, 1));
        fprintf(' Done\n');
        
        corr_B(i, j) = corr(Bvect, quantile(inten(:, 1:end-2)', 0.9)', 'type', 'Spearman');
        
        R = inten(:, 1:end-2) - langmuir_func(A, B, C);
        goodness_of_fit_fro(i, j) = norm(R, 'fro');
        goodness_of_fit_geman(i, j) = 0.5 * sum(sum((R .^ 2) ./ (1 + R .^ 2)));
        goodness_of_fit_huber(i, j) = sum(sum(huber_func(R)));
        
        Qtrain = langmuir_func(A, B, C);
        Qtest = langmuir_func(A, B, C_test);
        overfitting_native(i, j) = nmf_alpha_beta_divergence(inten_test(:, 1:end-2), Qtest, alpha, beta) / (size(inten_test, 2) - 2) - ...
            nmf_alpha_beta_divergence(inten(:, 1:end-2), Qtrain, alpha, beta) / (size(inten, 2) - 2);
        overfitting_fro(i, j) = norm(inten_test(:, 1:end-2) - Qtest, 'fro') / (size(inten_test, 2) - 2) - ...
            norm(inten(:, 1:end-2) - Qtrain, 'fro') / (size(inten, 2) - 2);
        overfitting_huber(i, j) = sum(sum(huber_func(inten_test(:, 1:end-2) - Qtest) - ...
            huber_func(inten(:, 1:end-2) - Qtrain)));
        
        divergence_value(i, j) = nmf_alpha_beta_divergence(inten(:, 1:end-2), A * C, alpha, beta);
        
        inten_nonzero = inten(:, 1:end-2);
        Q_nonzero = Qtrain;
        Q_nonzero = Q_nonzero(inten_nonzero > 0);
        inten_nonzero = inten_nonzero(inten_nonzero > 0);
        zero_influence(i, j) = nmf_alpha_beta_divergence(inten(:, 1:end-2), Qtrain, alpha, beta) - ...
            nmf_alpha_beta_divergence(inten_nonzero, Q_nonzero, alpha, beta);
        zero_influence_ratio(i, j) = nmf_alpha_beta_divergence(inten(:, 1:end-2), Qtrain, alpha, beta) / ...
            nmf_alpha_beta_divergence(inten_nonzero, Q_nonzero, alpha, beta);
        
        outliers_influence(i, j) = nmf_alpha_beta_divergence(inten(:, 1:end-2), Qtrain, alpha, beta) - ...
            nmf_alpha_beta_divergence_robust(inten(:, 1:end-2), Qtrain, alpha, beta);
        outliers_influence_ratio(i, j) = nmf_alpha_beta_divergence(inten(:, 1:end-2), Qtrain, alpha, beta) / ...
            nmf_alpha_beta_divergence_robust(inten(:, 1:end-2), Qtrain, alpha, beta);

        fprintf('Mad(A1 - A2): %f\nMad(C1 - C2): %e\nMad(dist(C1, C2)): %e\nGoodness of fit (fro): %e\nGoodness of fit (Geman): %e\nOverfitting (alpha-beta): %e\nOverfitting (L2): %e\nDivergence: %e\nZeros influence: %e\nOutliers influence: %e\nZeros influence ratio: %e\nOutliers influence ratio: %e\nNorm problems: %d\nCorr: %f\n\n', ...
            mad_A(i, j), mad_C(i, j), concentration_dists(i, j), goodness_of_fit_fro(i, j), ...
            goodness_of_fit_geman(i, j), overfitting_native(i, j), overfitting_fro(i, j), divergence_value(i, j), ...
            zero_influence(i, j), outliers_influence(i, j), zero_influence_ratio(i, j), outliers_influence_ratio(i, j), norm_problems_cnt(i, j), ...
            corr_B(i, j));

        save(['alpha_beta_cv_nonlinear_' num2str(alpha - min(alpha_range)) '_' num2str(beta - min(beta_range)) '.mat'], 'goodness_of_fit_fro', ...
            'overfitting_native', 'overfitting_fro', 'concentration_dists', ...
            'mad_A', 'mad_B', 'mad_C', 'outliers_A', 'outliers_B', 'outliers_C', ...
            'converged_cnt_full', 'converged_cnt_fixedA', 'divergence_value', ...
            'zero_influence', 'outliers_influence', 'zero_influence_ratio', 'outliers_influence_ratio', 'norm_problems_cnt', 'goodness_of_fit_geman', ...
            'corr_B', 'goodness_of_fit_huber', 'overfitting_huber');%, ...
            %'arrays_factors_smart', 'probes_factors_smart');
%    end
%end