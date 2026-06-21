# ============================================================
# run_table1.jl - Run selected instances from Table 1
# ============================================================

# Load your module
#include("src/GI_benchmark.jl")
include(joinpath(@__DIR__, "GI_benchmark.jl"))
using .GI_benchmark
using DataFrames, CSV

# Time limit (start small for testing, then increase to 3600)
TIME_LIMIT = 300.0   # 5 minutes; change to 3600 for full run

# Instances to test (pick a few from each family)
instances = [
    # --- Already ran ---
    # "latin_5_25", "latin_10_100",
    # "Lattice_4_16", "Lattice_9_81",
    # "paley_power_9", "paley_power_49",
    # "Triangular_10_45",
    # "cfi-20",
    # "exact_001", "exact_024",
    # "iso_r01N_s20", "iso_r01N_s40",
    # "sts_19_57",
    # "usr_1_29_1",


    # Larger random (low symmetry) – expected: WL speeds up hugely
    "iso_r01N_s60",          # n=60, 3600 vars, WL should fix ~98%, solve in <1s
    "iso_r01N_s80",          # n=80, 6400 vars, baseline times out, WL solves in <1s

    # More CFI graphs (medium symmetry, 1‑WL fails)
    "cfi-22",                # n=22? Actually CFI-22 is ~22 vertices, 1‑WL fixes 0
    "cfi-40",                # n=40? 1‑WL fixes 0, baseline times out

    # More exact graphs (low symmetry, high fixing)
    "exact_051",             # n=51, WL should fix >90%
    "exact_061",             # n=61

    # More Latin/Lattice for symmetry (0% fixing)
    "latin_16_256",          # n=16, large Latin square, symmetric, 0% fixing
    "Lattice_15_225",        # n=15, symmetric, 0% fixing

    # Paley prime (symmetric, 0% fixing)
    "paley_prime_13",        # n=13, strongly regular, 0% fixing

    # Larger Triangular (symmetric, maybe times out)
    "Triangular_16_120",     # n=16, symmetric, could time out

    # More STS (low symmetry, often hard)
    "sts_25_100",            # n=25, WL might fix some, but not as much as random

    # More USR (low symmetry)
    "usr_2_58_1",            # n=58, could benefit from WL
]

# Solver configurations (from Table 1)
# The solver string tells Boscia which preprocessors to use
# We'll use "boscia_bpcg" as base, and add suffixes:
#   _star, _clique_star, _obbt, _wl, _star_wl, _clique_star_wl, _obbt_wl
solver_configs = [
    ("DFS", "boscia"),
    ("Star", "boscia_star"),
    ("CliqueStar", "boscia_clique_star"),
    ("Fixings", "boscia_OBBT"),
    ("DFS_WL", "boscia_wl"),
    ("Star_WL", "boscia_star_wl"),
    ("CliqueStar_WL", "boscia_clique_star_wl"),
    ("Fixings_WL", "boscia_OBBT_wl"),
]

# Results storage
results = []

for inst in instances
    for (name, solver) in solver_configs
        println("\n=== Running $inst with $name ($solver) ===")
        try
            result = GI_benchmark.bench(inst, 1; solver=solver, time_limit=TIME_LIMIT)
            found = result[1]
            total_time = result[2]
            main_dict = result[3]
            preproc = length(result) >= 4 ? result[4] : nothing
            status = get(main_dict, :status_string, "Unknown")
            # ----- FIXED LINE -----
            fixed_to_zero = 0
            if preproc !== nothing
                # Check if fixed_to_zero is a structure we can query
                ftz = preproc.fixed_to_zero
                if ftz !== nothing && hasproperty(ftz, :wl)
                    fixed_to_zero = getproperty(ftz, :wl)
                else
                    # If :wl doesn't exist, check if there's any other indicator, 
                    # or just default to 0/total fixed elements if applicable.
                    fixed_to_zero = 0 
                end
            end
            #------------------------
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

# Save to CSV
df = DataFrame(results)
CSV.write("table1_test_results.csv", df)
println("\nResults saved to table1_test_results.csv")