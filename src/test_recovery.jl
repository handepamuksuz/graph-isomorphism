# test_recovery.jl – Quick test to verify star/clique/obbt fixes
include(joinpath(@__DIR__, "GI_benchmark.jl"))
using .GI_benchmark, DataFrames, CSV

TIME_LIMIT = 60.0  # Short timeout for testing

# Just 2-3 instances to verify
test_instances = [
    "latin_5_25",      # symmetric, should finish fast
    "exact_001",       # asymmetric, should show fixing
    "iso_r01N_s20",    # random, should show fixing
]

# Test all configs (including the ones that previously failed)
test_configs = [
    ("DFS", "boscia"),
    ("Star", "boscia_star"),
    ("CliqueStar", "boscia_clique_star"),
    ("Fixings", "boscia_obbt"),
    ("DFS_WL", "boscia_wl"),
    ("Star_WL", "boscia_star_wl"),
    ("CliqueStar_WL", "boscia_clique_star_wl"),
    ("Fixings_WL", "boscia_obbt_wl"),
]

results = []
for inst in test_instances
    for (name, solver) in test_configs
        println("\n=== TEST: $inst with $name ($solver) ===")
        try
            result = GI_benchmark.bench(inst, 1; solver=solver, time_limit=TIME_LIMIT)
            total_time = result[2]
            main_dict = result[3]
            preproc = length(result) >= 4 ? result[4] : nothing
            status = get(main_dict, :status_string, "Unknown")
            fixed_to_zero = 0
            if preproc !== nothing && hasproperty(preproc, :fixed_to_zero)
                ftz = preproc.fixed_to_zero
                if hasproperty(ftz, :wl)
                    fixed_to_zero = getproperty(ftz, :wl)
                end
            end
            n = 0
            if haskey(main_dict, :raw_solution)
                n = round(Int, sqrt(length(main_dict[:raw_solution])))
            end
            push!(results, (instance=inst, solver_name=name, solver=solver,
                            status=status, total_time=total_time,
                            fixed_to_zero=fixed_to_zero, n=n))
            println("✓ Completed in $(total_time) seconds")
        catch e
            println("✗ ERROR: $e")
            push!(results, (instance=inst, solver_name=name, solver=solver,
                            status="Error", total_time=NaN,
                            fixed_to_zero=NaN, n=0))
        end
    end
end

df = DataFrame(results)
CSV.write("test_recovery_results.csv", df)
println("\nTest results saved to test_recovery_results.csv")