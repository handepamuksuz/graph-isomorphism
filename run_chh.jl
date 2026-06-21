# run_chh_sensible.jl – Run all CHH instances with 1-WL and 2-WL (1 hour limit)
include("src/GI_benchmark.jl")
using .GI_benchmark, DataFrames, CSV

function run_chh_sensible()
    TIME_LIMIT = 3600.0   # 1 hour per run
    OUTPUT_CSV = "chh_results.csv"

    # Load already completed runs to skip duplicates
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
            println("Starting fresh.")
        end
    end

    # All CHH instances (from smallest to largest)
    chh_instances = [
        "CHH_cc_1_1_22_1",
        "CHH_cc_2_1_44_1",
        "CHH_cc_2_2_88_1",
        "CHH_cc_3_2_132_1",
        "CHH_cc_3_3_198_1",
        "CHH_cc_4_3_264_1",
        "CHH_cc_4_4_352_1",
        "CHH_cc_5_4_440_1",
    ]

    # Configs: 1-WL and 2-WL
    configs = [
        ("1WL", "boscia_wl", true),
        ("2WL", "boscia_wl2", true),
    ]

    # Helper to safely extract fixed_to_zero (handle missing wl field)
    function get_fixed_to_zero(preproc)
        preproc === nothing && return 0
        ftz = preproc.fixed_to_zero
        # Try wl first, fallback to star/clique/obbt if needed (but for CHH we expect wl)
        if hasproperty(ftz, :wl)
            return getproperty(ftz, :wl)
        end
        return 0
    end

    # Create CSV if needed
    if !isfile(OUTPUT_CSV)
        df_empty = DataFrame(instance=String[], solver_name=String[], solver=String[],
                             seed=Int[], status=String[], total_time=Float64[],
                             fixed_to_zero=Float64[], n=Int[],
                             iso_generate=Bool[], early_stop=Bool[], early_reason=String[])
        CSV.write(OUTPUT_CSV, df_empty)
    end

    total_runs = 0
    for inst in chh_instances
        for (name, solver, is_iso) in configs
            seed = 1
            key = (inst, name, seed)
            if key in completed
                println("Skipping $inst with $name (already done)")
                continue
            end
            println("\n[$total_runs+1] --- $inst with $name ($solver, 1 hour) ---")
            try
                result = GI_benchmark.bench(inst, seed; solver=solver, iso_generate=is_iso, time_limit=TIME_LIMIT)
                total_time = result[2]
                main_dict = length(result) >= 3 ? result[3] : nothing
                preproc = length(result) >= 4 ? result[4] : nothing

                # Safely extract status and n from main_dict
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
                println("✓ Completed")
            catch e
                println("✗ ERROR: $e")
                row = (instance=inst, solver_name=name, solver=solver, seed=seed,
                       status="Error", total_time=NaN, fixed_to_zero=NaN, n=0,
                       iso_generate=is_iso, early_stop=false, early_reason="")
                DataFrame([row]) |> df -> CSV.write(OUTPUT_CSV, df; append=true)
            end
        end
    end

    println("\n✅ CHH SENSIBLE RUN COMPLETE! Total new runs: $total_runs")
    println("Results saved to $OUTPUT_CSV")
end

run_chh_sensible()
