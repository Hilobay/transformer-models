function [A, present] = attention(X, past, weights, hyperParameters)
% attention   Full Multi-head Attention
%
%   [A, present] = attention(X, past, weights, hyperParameters) computes a
%   multi-head attention block on X as outlined in Section 3.2.2 and Figure
%   2 in [1]. See below for details of inputs and outputs.
%
%   Inputs:
%       X               - A (numFeatures*numHeads)-by-numInputSubwords
%                         input array.
%       past            - A numFeatures-by-numPastSubwords-by-numHeads-by-2
%                         array. This contains the 'keys' and 'values' for
%                         past subwords. These are needed to predict future
%                         outputs in an autoregressive manner. 'keys' are
%                         stored in past(:,:,:,1) and 'values' are stored
%                         in past(:,:,:,2).
%       weights         - The weights for the full multi-head attention
%                         block stored in a struct. This includes:
%                           - attn_c_attn_w_0: A weight matrix for the
%                             first fully connected layer.
%                           - attn_c_attn_b_0: A bias vector for the first
%                             fully connected layer.
%                           - attn_c_proj_w_0: A weight matrix for the
%                             final fully connected layer.
%                           - attn_c_proj_b_0: A bias vector for the final
%                             fully connected layer.
%       numHeads        - The number of attention heads. This is a
%                         hyper-parameter.
%
%   Outputs:
%       Z               - A (numFeatures*numHeads)-by-numInputSubwords
%                         output array.
%       present         - A numFeatures-by-numAllSubwords-by-numHeads-by-2
%                         array. This contains the 'keys' and 'values' that
%                         are created from inputs. These need to passed
%                         back in as the 'past' input if we want to predict
%                         future outputs in an autoregressive manner. 'keys'
%                         are stored in present(:,:,:,1) and 'values' are
%                         stored in present(:,:,:,2).
%
%   References:
%
%   [1] Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszkoreit, Llion
%       Jones, Aidan N. Gomez, Lukasz Kaiser, Illia Polosukhin, "Attention
%       Is All You Need", https://arxiv.org/abs/1706.03762

% Use a fully connected layer to generate queries, keys and values from the
% input.
C = transformer.layer.convolution1d( X, ...
    weights.attn_c_attn_w_0, ...
    weights.attn_c_attn_b_0 );

% Split the results into Q (Query), K (Keys) and V (Values).
splitSize = size(C,1)/3;
Q = C(1:splitSize,:);
K = C((splitSize+1):(2*splitSize),:);
V = C((2*splitSize+1):(3*splitSize),:);

% Split heads
Q = iSplitHeads(Q, splitSize, hyperParameters.NumHeads);
K = iSplitHeads(K, splitSize, hyperParameters.NumHeads);
V = iSplitHeads(V, splitSize, hyperParameters.NumHeads);

% Use the past
if ~isempty(past)
    PK = past(:,:,:,1);
    PV = past(:,:,:,2);
    K = cat(2,PK,K);
    V = cat(2,PV,V);
end

% Set present. Note that this is done differently from the original
% implementation which sets the value of present before the previous if
% statement.
present = cat(4,K,V);

A = transformer.layer.multiheadAttention(Q,K,V);

A = iMergeHeads(A);

A = transformer.layer.convolution1d( A, ...
    weights.attn_c_proj_w_0, ...
    weights.attn_c_proj_b_0 );

end

function Z = iSplitHeads(X, splitSize, numHeads)
% We permute the data to put the dimension for the heads last, so that we
% can use batched matrix multiplication to compute attention for all of the
% heads at once.
%
% X     - A (numFeatures*numHeads)-by-numSubwords array.
% Z     - A numFeatures-by-numSubwords-by-numHeads array.
X = reshape(X, splitSize/numHeads, numHeads, []);
Z = permute(X,[1 3 2]);
end

function Z = iMergeHeads(X)
% X     - A numFeatures-by-numSubwords-by-numHeads array.
% Z     - A (numFeatures*numHeads)-by-numSubwords array.
X = permute(X, [1 3 2]);
Z = reshape(X, size(X,1)*size(X,2), []);
end