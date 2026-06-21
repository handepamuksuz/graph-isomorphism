# run_missing.jl – runs only the missing 62 instances (NoWL + 1WL)
include("src/GI_benchmark.jl")
using .GI_benchmark, DataFrames, CSV

function run_missing()
    TIME_LIMIT = 300.0
    OUTPUT_CSV = "full_1wl_results.csv"   # Append to your existing results

    # -----------------------------------------------------------------
    # 1. Load already completed runs from the CSV (to skip)
    # -----------------------------------------------------------------
    completed = Set()
    if isfile(OUTPUT_CSV)
        try
            df_existing = CSV.read(OUTPUT_CSV, DataFrame)
            for row in eachrow(df_existing)
                seed = hasproperty(row, :seed) ? row.seed : 1
                push!(completed, (row.instance, row.solver_name, seed))
            end
            println("Loaded $(length(completed)) already completed runs.")
        catch e
            println("Could not read existing CSV; starting fresh? Error: $e")
        end
    else
        println("No existing CSV found; will create new one.")
        # Create empty CSV with headers
        df_empty = DataFrame(instance=String[], solver_name=String[], solver=String[],
                             seed=Int[], status=String[], total_time=Float64[],
                             fixed_to_zero=Float64[], n=Int[],
                             iso_generate=Bool[], early_stop=Bool[], early_reason=String[])
        CSV.write(OUTPUT_CSV, df_empty)
    end

    # -----------------------------------------------------------------
    # 2. Define the missing instances (all 62)
    # -----------------------------------------------------------------
    missing_instances = [
                # USR
        "usr_1_29_1", "usr_1_29_2", "usr_2_58_1", "usr_2_58_2",
        "usr_3_87_1", "usr_3_87_2", "usr_4_116_1", "usr_4_116_2",
        "usr_7_203_1", "usr_7_203_2", "usr_14_406_1", "usr_14_406_2", 
        "sts_73_876", "sts_79_1027",
        # TNN
        "tnn_1_26_1", "tnn_1_26_2", "tnn_2_52_1", "tnn_2_52_2",
        "tnn_3_78_1", "tnn_3_78_2", "tnn_4_104_1", "tnn_4_104_2",
        "tnn_7_182_1", "tnn_7_182_2", "tnn_11_286_1", "tnn_11_286_2",
        "tnn_16_416_1", "tnn_16_416_2"

            ]

    # -----------------------------------------------------------------
    # 3. Configurations (only NoWL and 1WL, no non-iso)
    # -----------------------------------------------------------------
    configs = [
        ("NoWL", "boscia", true),
        ("1WL", "boscia_wl", true),
    ]

    # -----------------------------------------------------------------
    # 4. Helper: extract fixed_to_zero
    # -----------------------------------------------------------------
    function get_fixed_to_zero(preproc)
        preproc === nothing && return 0
        ftz = preproc.fixed_to_zero
        for field in [:wl, :star, :clique, :obbt]
            hasproperty(ftz, field) && return getproperty(ftz, field)
        end
        return 0
    end

    # -----------------------------------------------------------------
    # 5. Main loop
    # -----------------------------------------------------------------
    total_runs = 0
    for inst in missing_instances
        for (name, solver, is_iso) in configs
            seed = 1
            key = (inst, name, seed)
            if key in completed
                println("Skipping $inst with $name (already done)")
                continue
            end
            println("\n[$total_runs+1] --- $inst with $name ($solver) ---")
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

    println("\n✅ MISSING RUN COMPLETE! Total new runs: $total_runs")
    println("Results appended to $OUTPUT_CSV")
end

run_missing()