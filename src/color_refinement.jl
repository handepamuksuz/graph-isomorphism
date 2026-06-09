function color_refinement(adj::Matrix)
    n = size(adj, 1)
    # Initialize: color each vertex by its degree
    colors = Int[round(Int, sum(adj[v, :])) for v in 1:n]

    for _ in 1:n
        # Build new color signatures
        signatures = Vector{Tuple}(undef, n)
        for v in 1:n
            neighbors = findall(adj[v, :] .> 0)
            neighbor_colors = sort(colors[neighbors])
            signatures[v] = (colors[v], neighbor_colors)
        end

        # Map signatures to integer labels (same signature = same label)
        unique_sigs = unique(signatures)
        sig_to_label = Dict(sig => i for (i, sig) in enumerate(unique_sigs))
        new_colors = Int[sig_to_label[signatures[v]] for v in 1:n]

        if new_colors == colors
            break
        end
        colors = new_colors
    end
    return colors
end

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