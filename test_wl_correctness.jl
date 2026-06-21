# test_wl_correctness.jl
#
# Hand-verified ground truth test for 1-WL and 2-WL color refinement.
# RUN THIS FIRST before trusting any 2WL numbers in the results CSV.
#
# Usage:
#   julia --project=. test_wl_correctness.jl
#
# Ground truth derivation (see chat notes):
#   G1 = G2 = 4-cycle + one chord: edges {(1,2),(2,3),(3,4),(4,1),(1,3)}
#   This graph has a known automorphism: 1<->3, 2<->4 (90-deg rotation symmetry
#   plus the diagonal). Degrees: deg(1)=deg(3)=3, deg(2)=deg(4)=2.
#
#   Because {1,3} are structurally interchangeable and {2,4} are structurally
#   interchangeable under a REAL automorphism, NO correct WL method may ever
#   fix X[1,3], X[3,1], X[2,4], or X[4,2] to zero. If it does, the
#   implementation is wrong -- this is not a borderline case, it's a
#   mathematical certainty derived from an explicit automorphism.
#
#   Everything else (e.g. X[1,2], a degree-3 vs degree-2 vertex pair) MUST
#   be fixed to zero by 1-WL alone, since degree mismatch is checked in
#   round 0 of color refinement.

include("src/color_refinement.jl")  # adjust path if needed

using SparseArrays

function build_test_graph()
    n = 4
    edges = [(1,2), (2,3), (3,4), (4,1), (1,3)]
    A = zeros(Int, n, n)
    for (u, v) in edges
        A[u, v] = 1
        A[v, u] = 1
    end
    return sparse(A)
end

function check_must_be_free(fixed, pairs, label)
    ok = true
    for (i, j) in pairs
        if fixed[i, j]
            println("  FAIL  [$label] X[$i,$j] was fixed to zero, but $i and $j are")
            println("        related by a real automorphism (1<->3, 2<->4).")
            println("        This is a CORRECTNESS BUG, not a borderline case.")
            ok = false
        end
    end
    if ok
        println("  PASS  [$label] All automorphism-related pairs correctly left free.")
    end
    return ok
end

function check_must_be_fixed(fixed, pairs, label)
    ok = true
    for (i, j) in pairs
        if !fixed[i, j]
            println("  FAIL  [$label] X[$i,$j] was NOT fixed, but vertices $i and $j")
            println("        have different degrees and can never correspond.")
            ok = false
        end
    end
    if ok
        println("  PASS  [$label] All degree-mismatched pairs correctly fixed to zero.")
    end
    return ok
end

function run_tests()
    A = build_test_graph()
    B = build_test_graph()  # self-isomorphic, see derivation above

    n = 4
    must_stay_free = [(1,3), (3,1), (2,4), (4,2)]          # real automorphism
    must_be_fixed  = [(1,2), (2,1), (1,4), (4,1), (3,2), (2,3), (3,4), (4,3)]  # degree mismatch (3 vs 2)
    # note: (1,4) and (4,1) — wait, check degree: deg(1)=3, deg(4)=2 -> mismatch, must fix.
    # (3,4): deg(3)=3, deg(4)=2 -> mismatch, must fix.
    # diagonal (1,1) etc are not meaningful permutation entries to test here.

    println("="^70)
    println("TEST 1: 1-WL correctness")
    println("="^70)
    fixed_1wl = wl_fix_variables(A, B)
    r1a = check_must_be_free(fixed_1wl, must_stay_free, "1-WL")
    r1b = check_must_be_fixed(fixed_1wl, must_be_fixed, "1-WL")
    println()

    println("="^70)
    println("TEST 2: 2-WL correctness")
    println("="^70)
    fixed_2wl = wl2_fix_variables(A, B)
    r2a = check_must_be_free(fixed_2wl, must_stay_free, "2-WL")
    r2b = check_must_be_fixed(fixed_2wl, must_be_fixed, "2-WL")
    println()

    println("="^70)
    println("TEST 3: 2-WL must be at least as powerful as 1-WL")
    println("="^70)
    # Anything 1-WL fixes, 2-WL must also fix (2-WL is strictly more powerful).
    r3 = true
    for i in 1:n, j in 1:n
        if fixed_1wl[i,j] && !fixed_2wl[i,j]
            println("  FAIL  1-WL fixed X[$i,$j] but 2-WL did not.")
            println("        2-WL must dominate 1-WL -- this indicates the 2-WL")
            println("        implementation is LOSING information, not gaining it.")
            r3 = false
        end
    end
    if r3
        println("  PASS  2-WL fixes a superset of what 1-WL fixes.")
    end
    println()

    println("="^70)
    println("TEST 4: CFI sanity check (informational, not a hard requirement here)")
    println("="^70)
    println("  This small graph is NOT a CFI graph, so this test does not apply.")
    println("  Reminder: on real CFI instances, BOTH 1-WL and 2-WL MUST fix 0%")
    println("  of variables. If 2-WL fixes >0% on a CFI graph, that is proof")
    println("  of a bug, regardless of any other test results here.")
    println()

    println("="^70)
    all_pass = r1a && r1b && r2a && r2b && r3
    if all_pass
        println("ALL TESTS PASSED. 2-WL implementation is verified correct")
        println("on this hand-checked example. Safe to proceed to full benchmark.")
    else
        println("TESTS FAILED. Do NOT trust 2-WL results until these pass.")
        println("Do not add 2-WL numbers to the report or results CSV yet.")
    end
    println("="^70)

    return all_pass
end

run_tests()