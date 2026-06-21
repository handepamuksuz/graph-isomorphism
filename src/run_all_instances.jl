# run_all_instances.jl – full run over all instances in test_instances folder
include(joinpath(@__DIR__, "GI_benchmark.jl"))
using .GI_benchmark, DataFrames, CSV, Glob

function run_all()
    TIME_LIMIT = 300.0
    OUTPUT_CSV = "full_1wl_results.csv"

    # -------------------------------------------------------------
    # 1. SCAN test_instances folder for graph files
    # -------------------------------------------------------------
    # Use path relative to this script's location
    test_folder = joinpath(@__DIR__, "..", "test_instances")
    if !isdir(test_folder)
        # fallback: try current directory
        test_folder = "test_instances"
        if !isdir(test_folder)
            error("Could not find test_instances folder. Please provide the correct path.")
        end
    end
    println("Looking for graph files in: $test_folder")
    graph_files = glob("*.dimacs", test_folder)
    append!(graph_files, glob("*.mat", test_folder))
    println("Found $(length(graph_files)) graph files.")

    # Extract instance names (without extension)
    instance_names = String[]
    for f in graph_files
        name = splitext(basename(f))[1]
        push!(instance_names, name)
    end
    unique!(instance_names)
    println("Unique instance names: $(length(instance_names))")

    # -------------------------------------------------------------
    # 2. LOAD already completed runs (to skip)
    # -------------------------------------------------------------
    completed = Set()
    if isfile(OUTPUT_CSV)
        try
            df_existing = CSV.read(OUTPUT_CSV, DataFrame)
            for row in eachrow(df_existing)
                seed = hasproperty(row, :seed) ? row.seed : 1
                push!(completed, (row.instance, row.solver_name, seed))
            end
            println("Loaded $(length(completed)) already completed runs.")
        catch
            println("Could not read existing CSV; starting fresh.")
        end
    end

    # -------------------------------------------------------------
    # 3. CONFIGURATIONS
    # -------------------------------------------------------------
    # Main configs: NoWL and 1WL for all instances
    configs = [
        ("NoWL", "boscia", true),
        ("1WL", "boscia_wl", true),
    ]

    # -------------------------------------------------------------
    # 4. CURATED NON‑ISO INSTANCES (25 instances, all families)
    # -------------------------------------------------------------
    noniso_instances = [
        "latin_5_25", "latin_10_100", "Lattice_4_16", "Lattice_9_81",
        "paley_power_9", "paley_power_49", "Triangular_10_45", "Triangular_16_120",
        "cfi-20", "cfi-40",
        "iso_r01N_s20", "iso_r01N_s80", "exact_001", "exact_024",
        "sts_19_57", "sts_25_100", "usr_1_29_1", "usr_2_58_1",
        "CHH_cc_1_1_22_1", "CHH_cc_2_2_88_1",
        "tnn_1_26_1", "tnn_2_52_2",
        "paley_prime_13", "paley_prime_29",
        "Lattice_15_225", "iso_r01N_s100",
    ]

    for inst in noniso_instances
        if inst in instance_names
            push!(configs, ("1WL_noniso", "boscia_wl", false))
        else
            println("Warning: $inst not found in test_instances; skipping non-iso.")
        end
    end

    # -------------------------------------------------------------
    # 5. HELPER: extract fixed_to_zero
    # -------------------------------------------------------------
    function get_fixed_to_zero(preproc)
        preproc === nothing && return 0
        ftz = preproc.fixed_to_zero
        for field in [:wl, :star, :clique, :obbt]
            hasproperty(ftz, field) && return getproperty(ftz, field)
        end
        return 0
    end

    # -------------------------------------------------------------
    # 6. CREATE EMPTY CSV if needed
    # -------------------------------------------------------------
    if !isfile(OUTPUT_CSV)
        df_empty = DataFrame(instance=String[], solver_name=String[], solver=String[],
                             seed=Int[], status=String[], total_time=Float64[],
                             fixed_to_zero=Float64[], n=Int[],
                             iso_generate=Bool[], early_stop=Bool[], early_reason=String[])
        CSV.write(OUTPUT_CSV, df_empty)
    end

    # -------------------------------------------------------------
    # 7. MAIN LOOP
    # -------------------------------------------------------------
    total_runs = 0
    for inst in instance_names
        for (name, solver, is_iso) in configs
            # For non‑iso, only run if the instance is in curated list
            if !is_iso && !(inst in noniso_instances)
                continue
            end
            seed = 1
            key = (inst, name, seed)
            if key in completed
                println("Skipping $inst with $name (already done)")
                continue
            end
            println("\n[$total_runs+1] --- $inst with $name ($solver, iso=$is_iso) ---")
            try
                result = GI_benchmark.bench(inst, seed; solver=solver, iso_generate=is_iso, time_limit=TIME_LIMIT)
                total_time = result[2]
                main_dict = length(result) >= 3 ? result[3] : nothing
                preproc = length(result) >= 4 ? result[4] : nothing

                status = "Unknown"
                n = 0
                if main_dict !== nothing
                    status = get(main_dict, :status_string, "Unknown")
                    if haskey(main_dict, :raw_solution)
                        n = round(Int, sqrt(length(main_dict[:raw_solution])))
                    end
                end

                fixed_to_zero = get_fixed_to_zero(preproc)
                early_stop = preproc !== nothing && hasproperty(preproc, :early_stop) && preproc.early_stop
                early_reason = (preproc !== nothing && hasproperty(preproc, :early_reason) && preproc.early_reason !== nothing) ? string(preproc.early_reason) : ""

                row = (instance=inst, solver_name=name, solver=solver, seed=seed,
                       status=status, total_time=total_time,
                       fixed_to_zero=fixed_to_zero, n=n,
                       iso_generate=is_iso, early_stop=early_stop, early_reason=early_reason)
                DataFrame([row]) |> df -> CSV.write(OUTPUT_CSV, df; append=true)
                total_runs += 1
                println("✓ Completed (total runs so far: $total_runs)")
            catch e
                println("✗ ERROR: $e")
                row = (instance=inst, solver_name=name, solver=solver, seed=seed,
                       status="Error", total_time=NaN, fixed_to_zero=NaN, n=0,
                       iso_generate=is_iso, early_stop=false, early_reason="")
                DataFrame([row]) |> df -> CSV.write(OUTPUT_CSV, df; append=true)
            end
        end
    end

    println("\n✅ FULL RUN COMPLETE! Total new runs: $total_runs")
    println("Results saved to $OUTPUT_CSV")
end

run_all()