%   -*- coding: utf-8 -*-
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
%   Fit and apply TensorReg for
%   classifying SPHARM coefficients 
%
%   SPDX-FileCopyrightText: 2022 Medical Physics Unit, McGill University, Montreal, CAN
%   SPDX-FileCopyrightText: 2022 Thierry Lefebvre
%   SPDX-FileCopyrightText: 2022 Peter Savadjiev
%   SPDX-License-Identifier: MIT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



function [predict_list, TensorReg_matrix] = fun_TensorReg(path)

% Uses https://hua-zhou.github.io/TensorReg/ package and
% https://github.com/andrewssobral/tensor_toolbox

    
%% Load all SPHARM matrices into a Tensor
% Get list of all subfolders.
SPHARMmatrices = dir([path '/*.mat']);

y = [];
    
for k=1:length(SPHARMmatrices)
    % Load SPHARM matrix
    itFile = open([path '/' SPHARMmatrices(k).name]);
    itCoeff = itFile.flmr_in;
    itCoeff = squeeze((vecnorm(itCoeff,2,2))); % L-2 norm along the M dimension

    y = [y; itFile.label];
        
    if k == 1
        coeffList = itCoeff;
    else
        coeffList = cat(3,coeffList,itCoeff);
    end
        
end


%% Fit TensorReg classifier on tensors of SPHARM coefficients
M = tensor(coeffList);
p0 = 1;
b0 =  2.756; % Random

n = size(coeffList,3);  % sample size
X = ones(n,p0);   % n-by-p regular design matrix

maxlambda = 100; % Max regularization
gridpts = 100;
lambdas = zeros(1,gridpts);
gs = 2/(1+sqrt(5));
B = cell(1,gridpts);
AIC = zeros(1,gridpts);
BIC = zeros(1,gridpts);

for i=1:gridpts
    if (i==1)
        B0 = [];
    else
        B0 = B{i-1};
    end
    lambda = maxlambda*gs^(i-1);
    lambdas(i) = lambda;
    y = double(y);
    [beta0,B{i},stats] = matrix_sparsereg(X,M,y,lambda,'binomial','B0',B0);
    AIC(i) = stats.AIC;
    BIC(i) = stats.BIC;
end


BIC(BIC==min(BIC)) = Inf; % Take the second lambda minimizing BIC
[~, minIdx] = min(BIC);

% TensorReg matrix fitted on all training dataset
TensorReg_matrix=double(B{gridpts-minIdx}); 

%% Assess probabilities in dataset

predict_list = []; % Risk vector
for alpha= 1 :n
    
    testM = double(M(:,:,alpha));
    BX = sum(testM(:).*TensorReg_matrix(:));    
    linear_predictor = beta0+BX;
    probability_of_being_a_1 = exp(linear_predictor) / (1 + exp(linear_predictor));
    predict_list = [predict_list probability_of_being_a_1];
end


end