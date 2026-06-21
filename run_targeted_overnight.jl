# run_targeted_overnight.jl – CFI gets 1 hour, others get 10 minutes
include("src/GI_benchmark.jl")
using .GI_benchmark, DataFrames, CSV

function run_targeted()
    OUTPUT_CSV = "targeted_overnight.csv"

    # Load completed runs from this specific output file (to avoid re-runs within this batch)
    completed = Set()
    if isfile(OUTPUT_CSV)
        try
            df_existing = CSV.read(OUTPUT_CSV, DataFrame)
            for row in eachrow(df_existing)
                seed = hasproperty(row, :seed) ? row.seed : 1
                push!(completed, (row.instance, row.solver_name, seed))
            end
            println("Loaded $(length(completed)) already completed runs from $OUTPUT_CSV")
        catch
            println("Starting fresh.")
        end
    end

    # -------------------------------------------------------------
    # 1. CFI: 1 hour (3600s) per run – to see if 2WL finally solves them
    # -------------------------------------------------------------
    cfi_instances = ["cfi-20", "cfi-22", "cfi-40", "cfi-50"]
    cfi_configs = [
        ("2WL_1h", "boscia_wl2", true),
        ("1WL_noniso", "boscia_wl", false),
        ("2WL_noniso", "boscia_wl2", false),
    ]
    CFI_TIME = 10800.0

    # -------------------------------------------------------------
    # 2. CHH: 2-WL, 10 minutes (600s) – to see if 2WL fixes more and solves
    # -------------------------------------------------------------
    chh_instances = [
        "CHH_cc_1_1_22_1", "CHH_cc_2_1_44_1", "CHH_cc_2_2_88_1",
        "CHH_cc_3_2_132_1", "CHH_cc_3_3_198_1", "CHH_cc_4_3_264_1",
        "CHH_cc_4_4_352_1", "CHH_cc_5_4_440_1"
    ]
    chh_configs = [
        ("WL_10min", "boscia_wl2", true),
    ]
    CHH_TIME = 1800.0

    # -------------------------------------------------------------
    # 3. Other "interesting" instances (10 minutes each)
    #    - exact_092: 1WL fixed 99.8% but timed out at 328s. Run 1WL again at 600s.
    #    - Large Paley: 1WL fixed 0%, but maybe 2WL fixes something.
    #    - STS/USR: 1WL fixed 0%, test 2WL.
    # -------------------------------------------------------------
    other_instances = [
         "usr_7_203_1"
    ]
    other_configs = [
        ("1WL_10min", "boscia_wl", true),  # for exact_092 specifically
        ("2WL_10min", "boscia_wl2", true), # for Paley, STS, USR
    ]
    OTHER_TIME = 600.0

    # -------------------------------------------------------------
    # Helper
    # -------------------------------------------------------------
    function get_fixed_to_zero(preproc)
        preproc === nothing && return 0
        ftz = preproc.fixed_to_zero
        for field in [:wl, :star, :clique, :obbt]
            hasproperty(ftz, field) && return getproperty(ftz, field)
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



    # --- Run Other (10 min) ---
    println("\n🚀 OTHER GROUP (10 min limit)")
    for inst in other_instances
        for (name, solver, is_iso) in other_configs
            # Only run 1WL on exact_092, and 2WL on the others
            if name == "1WL_10min" && inst != "exact_092"
                continue
            end
            if name == "2WL_10min" && inst == "exact_092"
                continue
            end
            seed = 1
            key = (inst, name, seed)
            key in completed && continue
            println("\n[$total_runs+1] --- $inst with $name ($solver, iso=$is_iso, 600s) ---")
            try
                result = GI_benchmark.bench(inst, seed; solver=solver, iso_generate=is_iso, time_limit=OTHER_TIME)
                total_time = result[2]
                main_dict = length(result) >= 3 ? result[3] : nothing
                preproc = length(result) >= 4 ? result[4] : nothing
                status = "Unknown"; n = 0
                if main_dict !== nothing
                    status = get(main_dict, :status_string, "Unknown")
                    n = haskey(main_dict, :raw_solution) ? round(Int, sqrt(length(main_dict[:raw_solution]))) : 0
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

    println("\n✅ TARGETED OVERNIGHT RUN COMPLETE! Total new runs: $total_runs")
    println("Results saved to $OUTPUT_CSV")
end

run_targeted()