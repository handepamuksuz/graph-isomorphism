function build_function_gradient(A, B, n)
    R = zeros(n, n)

    B2 = Matrix(1.0B^2)
    A2 = Matrix(1.0A^2)
    BX = zeros(n, n)
    function f_acc2(x)
        X = reshape(x, n, n)
        mul!(R, X, A)
        mul!(R, B, X, -1, 1)
        return norm(R)^2
    end

    function f_acc2_check(x)
        X = reshape(x, n, n)
        mul!(R, X, A)
        mul!(R, B, X, -1, 1)
        res = norm(R)^2
        @assert res ≈ norm(X * A - B * X)^2
        return res
    end
    function grad_acc2!(storage, x)
        X = reshape(x, n, n)
        mul!(BX, B, X)
        S = reshape(storage, n, n)
        mul!(S, X, A2, 2, 0)
        mul!(S, BX, A, -4, 1)
        mul!(S, B2, X, 2, 1)
        return nothing
    end
    return f_acc2, grad_acc2!, f_acc2_check
end

function build_exp_function_gradient(A, B, n, tau)
    EA = exp(tau * Matrix(1.0A))
    EB = exp(tau * Matrix(1.0B))
    EA2 = EA^2
    EB2 = EB^2

    R = zeros(n, n)
    EBX = zeros(n, n)

    function f_exp(x)
        X = reshape(x, n, n)
        mul!(R, X, EA)
        mul!(R, EB, X, -1, 1)
        return norm(R)^2
    end

    function grad_exp!(storage, x)
        X = reshape(x, n, n)
        S = reshape(storage, n, n)
        mul!(EBX, EB, X)
        mul!(S, X, EA2, 2, 0)
        mul!(S, EBX, EA, -4, 1)
        mul!(S, EB2, X, 2, 1)
        return nothing
    end

    function f_exp_check(x)
        X = reshape(x, n, n)
        return norm(X * EA - EB * X)^2
    end

    return f_exp, grad_exp!, f_exp_check
end

function build_truncated_exp_function_gradient(A, B, n, tau, K)
    function truncated_matrix_exp(M, tau, K)
        n = size(M, 1)
        T = Matrix{Float64}(I, n, n)
        Mk = Matrix{Float64}(I, n, n)
        coeff = 1.0
        Mf = Matrix(1.0 * M)

        for k in 1:K
            Mk = Mk * Mf
            coeff *= tau / k
            T .+= coeff .* Mk
        end

        return T
    end

    EA = truncated_matrix_exp(A, tau, K)
    EB = truncated_matrix_exp(B, tau, K)

    R = zeros(n, n)
    T1 = zeros(n, n)
    T2 = zeros(n, n)

    function f_exp_trunc(x)
        X = reshape(x, n, n)
        mul!(R, X, EA)
        mul!(R, EB, X, -1, 1)
        return sum(abs2, R)
    end

    function grad_exp_trunc!(storage, x)
        X = reshape(x, n, n)
        S = reshape(storage, n, n)

        mul!(R, X, EA)
        mul!(R, EB, X, -1, 1)
        mul!(T1, R, EA')
        mul!(T2, EB', R)
        @. S = 2.0 * (T1 - T2)
        return nothing
    end

    function f_exp_trunc_check(x)
        X = reshape(x, n, n)
        return norm(X * EA - EB * X)^2
    end

    return f_exp_trunc, grad_exp_trunc!, f_exp_trunc_check
end

function build_unitary_exp_function_gradient(A, B, n, times)
    # Allow both scalar t and vector times
    ts = times isa Number ? [times] : collect(times)

    Af = Matrix(1.0A)
    Bf = Matrix(1.0B)

    EAs = [exp((-im * t) * Af) for t in ts]
    EBs = [exp((-im * t) * Bf) for t in ts]

    R = zeros(ComplexF64, n, n)
    T1 = zeros(ComplexF64, n, n)
    T2 = zeros(ComplexF64, n, n)

    function f_unitary_exp(x)
        X = reshape(x, n, n)

        val = 0.0

        for k in eachindex(ts)
            EA = EAs[k]
            EB = EBs[k]

            # R = X * EA - EB * X
            mul!(R, X, EA)
            mul!(R, EB, X, -1, 1)

            val += real(sum(abs2, R))
        end

        return val
    end

    function grad_unitary_exp!(storage, x)
        X = reshape(x, n, n)
        S = reshape(storage, n, n)

        fill!(S, 0.0)

        for k in eachindex(ts)
            EA = EAs[k]
            EB = EBs[k]

            # R = X * EA - EB * X
            mul!(R, X, EA)
            mul!(R, EB, X, -1, 1)

            # T1 = R * EA'
            mul!(T1, R, EA')

            # T2 = EB' * R
            mul!(T2, EB', R)

            # Accumulate:
            # ∇f_k(X) = 2 Re(R * EA' - EB' * R)
            @. S += 2.0 * real(T1 - T2)
        end

        return nothing
    end

    function f_unitary_exp_check(x)
        X = reshape(x, n, n)

        val = 0.0

        for k in eachindex(ts)
            EA = EAs[k]
            EB = EBs[k]

            val += real(norm(X * EA - EB * X)^2)
        end

        return val
    end

    return f_unitary_exp, grad_unitary_exp!, f_unitary_exp_check
end

function build_function_gradient_with_degree_diag(A, B, n; alpha=1.0)
    R = zeros(n, n)

    Af = Matrix(1.0A)
    Bf = Matrix(1.0B)

    A2 = Af^2
    B2 = Bf^2

    # Degree vectors
    # Convention: objective is ||X*A - B*X||,
    # so column j of X corresponds to vertex j in A,
    # row i of X corresponds to vertex i in B.
    dA = vec(sum(Af, dims=2))
    dB = vec(sum(Bf, dims=2))

    # Precompute squared degree mismatch matrix:
    # W[i,j] = (dA[j] - dB[i])^2
    W = zeros(n, n)
    @inbounds for j in 1:n
        for i in 1:n
            W[i, j] = (dA[j] - dB[i])^2
        end
    end

    BX = zeros(n, n)

    function f_acc2_degdiag(x)
        X = reshape(x, n, n)

        # R = X*A - B*X
        mul!(R, X, Af)
        mul!(R, Bf, X, -1, 1)

        # ||X*D_A - D_B*X||_F^2
        # = sum_{i,j} X[i,j]^2 * (dA[j] - dB[i])^2
        degdiag_val = 0.0
        @inbounds for j in 1:n
            for i in 1:n
                degdiag_val += W[i, j] * X[i, j]^2
            end
        end

        return norm(R)^2 + alpha * degdiag_val
    end

    function f_acc2_degdiag_check(x)
        X = reshape(x, n, n)

        DA = Diagonal(dA)
        DB = Diagonal(dB)

        res =
            norm(X * Af - Bf * X)^2 +
            alpha * norm(X * DA - DB * X)^2

        return res
    end

    function grad_acc2_degdiag!(storage, x)
        X = reshape(x, n, n)
        S = reshape(storage, n, n)

        # Gradient of ||X*A - B*X||_F^2
        #
        # For symmetric A, B:
        # ∇ = 2X*A^2 - 4B*X*A + 2B^2*X
        mul!(BX, Bf, X)

        mul!(S, X, A2, 2, 0)
        mul!(S, BX, Af, -4, 1)
        mul!(S, B2, X, 2, 1)

        # Gradient of alpha * ||X*D_A - D_B*X||_F^2
        #
        # Entrywise:
        # ∇[i,j] += 2 alpha X[i,j] (dA[j] - dB[i])^2
        @inbounds for j in 1:n
            for i in 1:n
                S[i, j] += 2.0 * alpha * W[i, j] * X[i, j]
            end
        end

        return nothing
    end

    return f_acc2_degdiag, grad_acc2_degdiag!, f_acc2_degdiag_check
end

function build_heat_laplacian_function_gradient(A, B, n, times)
    # Allow both scalar t and vector times
    ts = times isa Number ? [times] : collect(times)

    Af = Matrix(1.0A)
    Bf = Matrix(1.0B)

    # Degree matrices: row sums
    dA = vec(sum(Af, dims=2))
    dB = vec(sum(Bf, dims=2))

    LA = Diagonal(dA) - Af
    LB = Diagonal(dB) - Bf

    # Heat kernels
    HAs = [exp(-t * Matrix(LA)) for t in ts]
    HBs = [exp(-t * Matrix(LB)) for t in ts]

    R = zeros(n, n)
    T1 = zeros(n, n)
    T2 = zeros(n, n)

    function f_heat_lap(x)
        X = reshape(x, n, n)

        val = 0.0

        for k in eachindex(ts)
            HA = HAs[k]
            HB = HBs[k]

            # R = X * HA - HB * X
            mul!(R, X, HA)
            mul!(R, HB, X, -1, 1)

            val += sum(abs2, R)
        end

        return val
    end

    function grad_heat_lap!(storage, x)
        X = reshape(x, n, n)
        S = reshape(storage, n, n)

        fill!(S, 0.0)

        for k in eachindex(ts)
            HA = HAs[k]
            HB = HBs[k]

            # R = X * HA - HB * X
            mul!(R, X, HA)
            mul!(R, HB, X, -1, 1)

            # General gradient:
            # ∇ = 2 * (R * HA' - HB' * R)
            mul!(T1, R, HA')
            mul!(T2, HB', R)

            @. S += 2.0 * (T1 - T2)
        end

        return nothing
    end

    function f_heat_lap_check(x)
        X = reshape(x, n, n)

        val = 0.0

        for k in eachindex(ts)
            HA = HAs[k]
            HB = HBs[k]
            val += norm(X * HA - HB * X)^2
        end

        return val
    end

    return f_heat_lap, grad_heat_lap!, f_heat_lap_check
end