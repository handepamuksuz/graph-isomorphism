# run_final_benchmark.jl – Complete redo with fixed preprocessing
# Run this from the root directory: C:\Users\ASUS\graph-isomorphism

include(joinpath(@__DIR__, "GI_benchmark.jl"))
using .GI_benchmark, DataFrames, CSV

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------
TIME_LIMIT = 300.0   # 5 minutes per run. Increase to 600 if you want baselines to really burn out.
OUTPUT_CSV = "corrections_of_overnight.csv"
# wl kaydetmedi diye, sadece mid/low sym icin 

# ------------------------------------------------------------
# 24 INSTANCES (Covers ALL critical cases)
# ------------------------------------------------------------


"""
    # --- HIGH SYMMETRY (0% fixing, WL does nothing) ---
    "latin_5_25",      # Small Latin square
    "latin_10_100",    # Medium Latin
    "latin_16_256",    # Large Latin
    "Lattice_4_16",    # Small grid
    "Lattice_9_81",    # Medium grid
    "Lattice_15_225",  # Large grid
    "paley_power_9",   # Small Paley
    "paley_power_49",  # Medium Paley
    "paley_prime_13",  # Paley prime
    "Triangular_10_45",# Small triangular
    "Triangular_16_120",# Large triangular
"""

all_instances = [
    # --- CFI (1-WL fails, 2-WL should win) ---
    "cfi-20",
    "cfi-40",

    # --- LOW SYMMETRY (massive fixing, huge speed-ups) ---
    "iso_r01N_s20",
    "iso_r01N_s40",
    "iso_r01N_s60",
    "iso_r01N_s80",
    "exact_001",
    "exact_024",
    "exact_051",
    "sts_19_57",
    "sts_25_100",
    "usr_1_29_1",
    "usr_2_58_1",
]

# ------------------------------------------------------------
# 9 CONFIGURATIONS (Paper's methods + your 1WL/2WL upgrades)
# ------------------------------------------------------------

"""
    # 1. Paper's baselines (no WL)
    ("DFS", "boscia"),
    ("Star", "boscia_star"),
    ("CliqueStar", "boscia_clique_star"),
    ("Fixings", "boscia_obbt"),
"""
all_configs = [
   
    # 2. Your 1-WL versions (main contribution)
    ("DFS_WL", "boscia_wl"),
    ("Star_WL", "boscia_star_wl"),    # Now correctly preserves WL fixings!
    ("CliqueStar_WL", "boscia_clique_star_wl"),
    ("Fixings_WL", "boscia_obbt_wl"),

    # 3. Your 2-WL upgrade (the cherry on top)
    ("DFS_WL2", "boscia_wl2"),
]

# ------------------------------------------------------------
# SAFE EXTRACTION (handles missing fields gracefully)
# ------------------------------------------------------------

function get_fixed_to_zero(preproc)
    if preproc === nothing
        return 0
    end
    
    ftz = preproc.fixed_to_zero
    
    # 1. Check if Weisfeiler-Lehman (WL) fixed any variables
    if hasproperty(ftz, :wl) && ftz.wl > 0
        return ftz.wl
        
    # 2. Check if Optimization-Based Bound Tightening (OBBT/Fixings) fixed any variables
    elseif hasproperty(ftz, :obbt) && ftz.obbt > 0
        return ftz.obbt
        
    # 3. Check if Clique/Star configurations fixed any variables
    elseif hasproperty(ftz, :clique) && ftz.clique > 0
        return ftz.clique
    elseif hasproperty(ftz, :star) && ftz.star > 0
        return ftz.star
    end
    
    return 0
end

# ------------------------------------------------------------
# START FRESH (overwrite old CSV)
# ------------------------------------------------------------
df_empty = DataFrame(instance=String[], solver_name=String[], solver=String[],
                     status=String[], total_time=Float64[],
                     fixed_to_zero=Float64[], n=Int[])
CSV.write(OUTPUT_CSV, df_empty)

total_runs = length(all_instances) * length(all_configs)
run_count = 0

println("\n🚀 STARTING FINAL BENCHMARK")
println("Instances: $(length(all_instances))")
println("Configs: $(length(all_configs))")
println("Total runs: $total_runs")
println("Time limit per run: $TIME_LIMIT seconds")
println("Results will be saved to: $OUTPUT_CSV")
println("\n" * "="^60)

# ------------------------------------------------------------
# MAIN LOOP
# ------------------------------------------------------------
for inst in all_instances
    for (name, solver) in all_configs
        global run_count += 1
        println("\n[$(run_count)/$(total_runs)] --- $inst with $name ($solver) ---")
        
        try
            result = GI_benchmark.bench(inst, 1; solver=solver, time_limit=TIME_LIMIT)
            total_time = result[2]
            main_dict = result[3]
            preproc = length(result) >= 4 ? result[4] : nothing
            
            status = get(main_dict, :status_string, "Unknown")
            fixed_to_zero = get_fixed_to_zero(preproc)
            
            n = 0
            if haskey(main_dict, :raw_solution)
                n = round(Int, sqrt(length(main_dict[:raw_solution])))
            end
            
            row = (instance=inst, solver_name=name, solver=solver,
                   status=status, total_time=total_time,
                   fixed_to_zero=fixed_to_zero, n=n)
            
            DataFrame([row]) |> df -> CSV.write(OUTPUT_CSV, df; append=true)
            println("✓ Completed in $(total_time) seconds")
            
        catch e
            println("✗ ERROR: $e")
            row = (instance=inst, solver_name=name, solver=solver,
                   status="Error", total_time=NaN, fixed_to_zero=NaN, n=0)
            DataFrame([row]) |> df -> CSV.write(OUTPUT_CSV, df; append=true)
        end
    end
end

println("\n" * "="^60)
println("✅ FINAL BENCHMARK COMPLETE!")
println("All results saved to $OUTPUT_CSV")
println("Total runs: $total_runs")