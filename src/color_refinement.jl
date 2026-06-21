export color_refinement_2wl, wl2_fix_variables

function color_refinement(adj::AbstractMatrix)
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
        unique_sigs = sort(unique(signatures))
        sig_to_label = Dict(sig => i for (i, sig) in enumerate(unique_sigs))
        new_colors = Int[sig_to_label[signatures[v]] for v in 1:n]

        if new_colors == colors
            break
        end
        colors = new_colors
    end
    return colors
end

function wl_fix_variables(A::AbstractMatrix, B::AbstractMatrix)
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


# ============================================================
# 2‑WL Color Refinement (colors ordered pairs of vertices)
# ============================================================
function color_refinement_2wl(adj::AbstractMatrix)
    n = size(adj, 1)

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

    for iter in 1:(n*n)   # 2-WL can need more rounds than 1-WL
        signatures = Matrix{Vector{Tuple{Int, Int}}}(undef, n, n)
        for i in 1:n, j in 1:n
            sig = Tuple{Int, Int}[]
            for k in 1:n
                push!(sig, (colors[i, k], colors[k, j]))
            end
            sort!(sig)
            signatures[i, j] = sig
        end

        flat_sigs = sort(unique(vec(signatures)))   # sort for cross-graph consistency, same fix as 1-WL
        sig_to_id = Dict(s => idx for (idx, s) in enumerate(flat_sigs))

        new_colors = zeros(Int, n, n)
        for i in 1:n, j in 1:n
            new_colors[i, j] = sig_to_id[signatures[i, j]]
        end

        if new_colors == colors
            break
        end
        colors = new_colors
    end

    # Vertex color = multiset of this vertex's row of pair-colors (sorted for permutation invariance)
    return [sort(colors[i, :]) for i in 1:n]
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