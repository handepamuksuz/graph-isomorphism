# plot_final_results.jl – final, fully working
using DataFrames, CSV, Plots, Statistics

# Column names (no header in CSV)
col_names = [
    "instance",
    "solver_name",
    "solver",
    "seed",
    "status",
    "total_time",
    "fixed_to_zero",
    "n",
    "iso_generate",
    "early_stop",
    "early_reason"
]

df = CSV.read("master_results.csv", DataFrame; header=0)
rename!(df, [Symbol(c) for c in col_names])

# Filter errors and keep NoWL, 1WL, 2WL
df_good = filter(row -> row.status != "Error", df)
df_wl = filter(row -> row.solver_name in ["NoWL", "1WL", "2WL"], df_good)

# Derived columns
df_wl[!, :vars] = df_wl.n .^ 2
df_wl[!, :percent_fixed] = 100 .* df_wl.fixed_to_zero ./ df_wl.vars

# Manual pivot
df_nowl = filter(row -> row.solver_name == "NoWL", df_wl)
df_nowl = df_nowl[!, [:instance, :n, :total_time]]
rename!(df_nowl, :total_time => :time_no_wl)

df_1wl = filter(row -> row.solver_name == "1WL", df_wl)
df_1wl = df_1wl[!, [:instance, :total_time, :percent_fixed]]
rename!(df_1wl, :total_time => :time_1wl, :percent_fixed => :pct_fixed_1wl)

df_2wl = filter(row -> row.solver_name == "2WL", df_wl)
df_2wl = df_2wl[!, [:instance, :total_time, :percent_fixed]]
rename!(df_2wl, :total_time => :time_2wl, :percent_fixed => :pct_fixed_2wl)

df_wide = innerjoin(df_nowl, df_1wl, on=:instance)
df_wide = innerjoin(df_wide, df_2wl, on=:instance)

# Remove missing
df_wide = filter(row -> !ismissing(row.time_no_wl) && !ismissing(row.time_1wl) && row.time_1wl > 0, df_wide)
df_wide[!, :speedup_1wl] = df_wide.time_no_wl ./ df_wide.time_1wl
df_wide[!, :speedup_2wl] = df_wide.time_no_wl ./ df_wide.time_2wl
df_wide[!, :speedup_1wl_capped] = min.(df_wide.speedup_1wl, 1000)
df_wide[!, :speedup_2wl_capped] = min.(df_wide.speedup_2wl, 1000)

println("Data loaded. Rows: ", nrow(df_wide))

# Figure 1: Scatter 1WL
p1 = scatter(df_wide.pct_fixed_1wl, df_wide.speedup_1wl_capped,
    xlabel = "Variables fixed by 1‑WL (%)",
    ylabel = "Speed-up (NoWL / 1WL)",
    title = "1‑WL: More fixing = Faster solving",
    legend = false, yscale = :log10, markersize = 8,
    xlims = (-5,105), ylims=(0.8,1100), color=:blue)
for row in eachrow(df_wide)
    annotate!(row.pct_fixed_1wl+1, row.speedup_1wl_capped*1.2, text(row.instance,6,:left))
end
savefig(p1, "scatter_fixing_vs_speedup_1wl.png")
println("✅ Figure 1")

# Figure 2: CFI upgrade
df_cfi = filter(row -> startswith(row.instance, "cfi"), df_wide)
p2 = scatter(df_wide.pct_fixed_1wl, df_wide.speedup_1wl_capped,
    xlabel="Variables fixed (%)", ylabel="Speed-up", title="2‑WL fixes CFI",
    legend=:bottomright, yscale=:log10, markersize=8,
    xlims=(-5,105), ylims=(0.8,1100), color=:lightgray, label="Other")
scatter!(p2, df_wide.pct_fixed_2wl, df_wide.speedup_2wl_capped,
    color=:blue, markershape=:square, label="2‑WL")
scatter!(p2, df_cfi.pct_fixed_1wl, df_cfi.speedup_1wl_capped,
    color=:red, markershape=:diamond, markersize=10, label="CFI (1WL)")
scatter!(p2, df_cfi.pct_fixed_2wl, df_cfi.speedup_2wl_capped,
    color=:green, markershape=:star5, markersize=12, label="CFI (2WL)")
for row in eachrow(df_cfi)
    annotate!(p2, row.pct_fixed_2wl+2, row.speedup_2wl_capped*1.2, text(row.instance,7,:left))
end
savefig(p2, "scatter_2wl_upgrade.png")
println("✅ Figure 2")

# Figure 3: Bar chart (fixed duplicates)
show_instances = ["iso_r01N_s100", "iso_r01N_s80", "exact_051", "exact_001", "cfi-20", "latin_5_25"]
df_wide_unique = unique(df_wide, :instance)
sel_df = DataFrame(instance = show_instances)
df_show = innerjoin(sel_df, df_wide_unique, on=:instance)

times = [df_show.time_no_wl df_show.time_1wl df_show.time_2wl]
p3 = bar(1:length(show_instances), times,
    yscale=:log10, bar_width=0.8,
    label=["NoWL" "1WL" "2WL"],
    xlabel="Instance", ylabel="Time (s, log)",
    title="Solve Time: NoWL vs 1WL vs 2WL",
    legend=:topright,
    xticks=(1:length(show_instances), show_instances),
    rotation=45, size=(900,500))
savefig(p3, "bar_time_comparison.png")
println("✅ Figure 3")

# Summary table
df_table = df_wide[!, [:instance, :n, :pct_fixed_1wl, :time_no_wl, :time_1wl, :time_2wl, :speedup_1wl, :speedup_2wl]]
sort!(df_table, :pct_fixed_1wl, rev=true)
CSV.write("summary_table.csv", df_table)
println("✅ Summary table saved")

println("\nAll plots saved successfully!")