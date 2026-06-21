function color_refinement_2wl(adj::AbstractMatrix)
    n = size(adj, 1)
    
    # 1. Initialize colors for all pairs (i, j)
    # 1: self-loop, 2: edge, 3: non-edge
    colors = zeros(Int, n, n)
    for i in 1:n, j in 1:n
        if i == j
            colors[i, j] = 1
        elseif adj[i, j] > 0
            colors[i, j] = 2
        else
            colors[i, j] = 3
        end
    end

    # 2. Refine pairs iteratively
    for iter in 1:n
        signatures = Matrix{Vector{Tuple{Int, Int}}}(undef, n, n)
        
        for i in 1:n, j in 1:n
            # Signature tracks the multiset of color tuples for all split nodes k
            sig = Tuple{Int, Int}[]
            for k in 1:n
                push!(sig, (colors[i, k], colors[k, j]))
            end
            sort!(sig) # Essential to treat as a multiset
            signatures[i, j] = sig
        end

        # Map signatures back to distinct integer color IDs
        flat_sigs = vec(signatures)
        unique_sigs = unique(flat_sigs)
        sig_to_id = Dict(s => idx for (idx, s) in enumerate(unique_sigs))
        
        new_colors = zeros(Int, n, n)
        for i in 1:n, j in 1:n
            new_colors[i, j] = sig_to_id[signatures[i, j]]
        end

        if new_colors == colors
            break
        end
        colors = new_colors
    end
    
    # Extract the diagonal colors to identify individual vertex properties
    return [colors[i, i] for i in 1:n]
end

# The tracking coordinator for 2-WL
function wl2_fix_variables(A::AbstractMatrix, B::AbstractMatrix)
    colors_A = color_refinement_2wl(A)
    colors_B = color_refinement_2wl(B)
    n = size(A, 1)
    fixed = falses(n, n)
    for i in 1:n, j in 1:n
        if colors_A[i] != colors_B[j]
            fixed[i, j] = true
        end
    end
    return fixed
end