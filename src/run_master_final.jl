# run_master_final.jl – fully robust (handles nothing in main_dict)
include(joinpath(@__DIR__, "GI_benchmark.jl"))
using .GI_benchmark, DataFrames, CSV

function run_all()
    TIME_LIMIT = 300.0
    OUTPUT_CSV = "master_results.csv"

    # Load existing results to skip completed runs
    completed = Set()
    for f in readdir(".")
        if endswith(f, ".csv")
            try
                df = CSV.read(f, DataFrame)
                for row in eachrow(df)
                    seed = hasproperty(row, :seed) ? row.seed : 1
                    push!(completed, (row.instance, row.solver_name, seed))
                end
            catch
                # ignore files that don't match format
            end
        end
    end
    println("Loaded $(length(completed)) already completed runs.")

    all_instances = [
        # High symmetry
        "latin_5_25", "latin_10_100", "latin_16_256",
        "Lattice_4_16", "Lattice_9_81", "Lattice_15_225",
        "paley_power_9", "paley_power_49",
        "paley_prime_13",
        "Triangular_10_45", "Triangular_16_120",
        # CFI
        "cfi-20", "cfi-40",
        # Low symmetry
        "iso_r01N_s20", "iso_r01N_s40", "iso_r01N_s60", "iso_r01N_s80",
        "exact_001", "exact_024", "exact_051",
        # STS / USR
        "sts_19_57", "sts_25_100",
        "usr_1_29_1", "usr_2_58_1",
        # Large scaling (optional)
        "iso_r01N_s100",
        "latin_22_484",
        "Lattice_20_400",
        "Triangular_29_406",
    ]

    configs = [
        ("NoWL", "boscia", true),
        ("1WL", "boscia_wl", true),
        ("2WL", "boscia_wl2", true),
        ("1WL_noniso", "boscia_wl", false),
        ("2WL_noniso", "boscia_wl2", false),
    ]

    noniso_instances = ["iso_r01N_s20", "iso_r01N_s80", "exact_001", "cfi-20", "latin_5_25"]

    function get_fixed_to_zero(preproc)
        if preproc === nothing
            return 0
        end
        ftz = preproc.fixed_to_zero
        for field in [:wl, :star, :clique, :obbt]
            if hasproperty(ftz, field)
                return getproperty(ftz, field)
            end
        end
        return 0
    end

    if !isfile(OUTPUT_CSV)
        df_empty = DataFrame(instance=String[], solver_name=String[], solver=String[],
                             seed=Int[], status=String[], total_time=Float64[],
                             fixed_to_zero=Float64[], n=Int[],
                             iso_generate=Bool[], early_stop=Bool[], early_reason=String[])
        CSV.write(OUTPUT_CSV, df_empty)
    end

    total_runs = 0
    for inst in all_instances
        for (name, solver, is_iso) in configs
            if !is_iso && !(inst in noniso_instances)
                continue
            end
            seed = 1
            key = (inst, name, seed)
            if key in completed
                continue
            end
            println("\n--- $inst with $name ($solver, iso=$is_iso) ---")
            try
                result = GI_benchmark.bench(inst, seed; solver=solver, iso_generate=is_iso, time_limit=TIME_LIMIT)
                total_time = result[2]
                main_dict = length(result) >= 3 ? result[3] : nothing
                preproc = length(result) >= 4 ? result[4] : nothing

                # Safe extraction from main_dict
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
                if preproc !== nothing && hasproperty(preproc, :early_reason) && preproc.early_reason !== nothing
                    early_reason = string(preproc.early_reason)
                else
                    early_reason = ""
                end

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

    println("\n✅ MASTER RUN COMPLETE! Total new runs: $total_runs")
    println("Results saved to $OUTPUT_CSV")
end

run_all()