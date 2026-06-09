# src/color_refinement.jl
# 1-Weisfeiler-Lehman (1-WL) color refinement preprocessing for Graph Isomorphism.
# Fixes X[i,j] = 0 whenever vertex i in G1 and vertex j in G2 have different stable colors.

"""
    color_refinement(adj::Matrix) -> Vector

Run 1-WL color refinement on a graph given by adjacency matrix `adj`.
Returns a vector of stable color labels (one per vertex).
Colors are initialized by degree, then refined until stable.
"""
function color_refinement(adj::Matrix)
    n = size(adj, 1)
    # Initialize: color each vertex by its degree
    colors = vec(sum(adj, dims=2))

    while true
        new_colors = Vector{UInt64}(undef, n)
        for v in 1:n
            neighbors = findall(adj[v, :] .> 0)
            neighbor_colors = sort(colors[neighbors])
            # Hash current color + sorted neighbor multiset for stability
            new_colors[v] = hash((colors[v], neighbor_colors))
        end
        if new_colors == colors
            break
        end
        colors = new_colors
    end
    return colors
end

"""
    wl_fix_variables(A::Matrix, B::Matrix) -> Matrix{Bool}

Given adjacency matrices A (for G1) and B (for G2), run 1-WL on both graphs
and return a Boolean matrix `fixed` where fixed[i,j] = true means
X[i,j] must be 0 (vertex i in G1 cannot map to vertex j in G2).
"""
function wl_fix_variables(A::Matrix, B::Matrix)
    colors_A = color_refinement(A)
    colors_B = color_refinement(B)
    n = size(A, 1)
    fixed = falses(n, n)
    for i in 1:n, j in 1:n
        if colors_A[i] != colors_B[j]
            fixed[i, j] = true
        end
    end
    return fixed
end