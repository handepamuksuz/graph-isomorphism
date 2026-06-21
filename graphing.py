import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# ============================================================
# 1. LOAD & AGGREGATE DATA (reusing the logic from above)
# ============================================================

df = pd.read_csv('full_1wl_results.csv')

# Drop errors / NaNs
df = df[df['status'] != 'Error']
df = df[df['total_time'].notna()]

# Aggregate repeated runs (take median time, first for constants)
df_agg = df.groupby(['instance', 'solver_name'], as_index=False).agg({
    'total_time': 'median',
    'fixed_to_zero': 'first',
    'n': 'first',
    'status': 'first',
    'iso_generate': 'first',
    'early_stop': 'first',
    'early_reason': 'first'
})

# Extract family name from instance
def get_family(name):
    if name.startswith('exact'): return 'exact'
    if name.startswith('iso_r01N'): return 'iso_r01N'
    if name.startswith('latin'): return 'latin'
    if name.startswith('Lattice'): return 'Lattice'
    if name.startswith('Triangular'): return 'Triangular'
    if name.startswith('CHH_cc'): return 'CHH_cc'
    if name.startswith('cfi'): return 'cfi'
    if name.startswith('cospectral'): return 'cospectral'
    if name.startswith('usr'): return 'usr'
    if name.startswith('sts'): return 'sts'
    if name.startswith('paley_power'): return 'paley_power'
    if name.startswith('paley_prime'): return 'paley_prime'
    return 'other'

df_agg['family'] = df_agg['instance'].apply(get_family)
df_agg['total_vars'] = df_agg['n'] ** 2
df_agg['fix_ratio'] = df_agg['fixed_to_zero'] / df_agg['total_vars']

# Split iso vs non-iso
df_iso = df_agg[df_agg['iso_generate'] == True]
df_noniso = df_agg[df_agg['iso_generate'] == False]

# Speedup calculation (only iso, paired NoWL vs 1WL)
df_nowl = df_iso[df_iso['solver_name'] == 'NoWL'][['instance', 'total_time']].rename(columns={'total_time': 'time_nowl'})
df_1wl = df_iso[df_iso['solver_name'] == '1WL'][['instance', 'total_time']].rename(columns={'total_time': 'time_1wl'})
df_speedup = pd.merge(df_nowl, df_1wl, on='instance', how='inner')
df_speedup['speedup'] = df_speedup['time_nowl'] / df_speedup['time_1wl']
# Attach family for grouping
df_speedup = df_speedup.merge(df_iso[['instance', 'family']].drop_duplicates(), on='instance')

# For the time-comparison bar chart, compute median time per (family, solver)
df_time_comp = df_iso[df_iso['solver_name'].isin(['NoWL', '1WL'])].groupby(['family', 'solver_name'], as_index=False)['total_time'].median()

# For speedup bar chart, median speedup per family
df_speedup_med = df_speedup.groupby('family', as_index=False)['speedup'].median().sort_values('speedup', ascending=True)

# For non-iso early stopping, count per family
df_noniso_count = df_noniso[df_noniso['solver_name'] == '1WL_noniso'].groupby('family', as_index=False).agg({
    'instance': 'count',
    'early_stop': lambda x: (x == True).sum()
})
df_noniso_count['not_early'] = df_noniso_count['instance'] - df_noniso_count['early_stop']

# ============================================================
# 2. PLOTTING (All 4 Charts)
# ============================================================

sns.set_style("whitegrid")
plt.rcParams['font.size'] = 11
plt.rcParams['figure.dpi'] = 120

# -----------------------------------------------------------------
# Chart 1: Time Comparison Bar Chart (NoWL vs 1WL) - log scale
# -----------------------------------------------------------------
fig1, ax1 = plt.subplots(figsize=(12, 6))
sns.barplot(
    data=df_time_comp,
    x='family',
    y='total_time',
    hue='solver_name',
    palette={'NoWL': '#d62728', '1WL': '#2ca02c'},
    ax=ax1
)
ax1.set_yscale('log')
ax1.set_ylabel('Median Solving Time (seconds, log scale)', fontsize=12)
ax1.set_xlabel('Graph Family', fontsize=12)
ax1.set_title('1-WL Preprocessing Reduces Solving Time for Families', fontsize=14)
ax1.legend(title='Solver')
ax1.grid(axis='y', linestyle='--', alpha=0.7)

# Add value labels on top of bars
for container in ax1.containers:
    ax1.bar_label(container, fmt='%.1fs', fontsize=9, padding=2)

plt.tight_layout()
plt.savefig('chart1_time_comparison.png', dpi=300, bbox_inches='tight')
plt.show()

# -----------------------------------------------------------------
# Chart 2: Scatter Plot: Fix Ratio vs Time (colored by family)
# -----------------------------------------------------------------
fig2, ax2 = plt.subplots(figsize=(11, 7))

# Only include 1WL iso instances that actually fixed some variables
df_scatter = df_iso[df_iso['solver_name'] == '1WL'].copy()
# Avoid log(0) issues: filter out zero time if any
df_scatter = df_scatter[df_scatter['total_time'] > 0]

palette = sns.color_palette("tab10", n_colors=df_scatter['family'].nunique())
sns.scatterplot(
    data=df_scatter,
    x='fix_ratio',
    y='total_time',
    hue='family',
    palette=palette,
    s=80,
    alpha=0.8,
    edgecolor='black',
    linewidth=0.5,
    ax=ax2
)
ax2.set_yscale('log')
ax2.set_xlabel('Fraction of Variables Fixed by 1-WL', fontsize=12)
ax2.set_ylabel('Solving Time (seconds, log scale)', fontsize=12)
ax2.grid(True, linestyle='--', alpha=0.5)
ax2.legend(title='Family', bbox_to_anchor=(1.05, 1), loc='upper left')

plt.tight_layout()
plt.savefig('chart2_scatter_fix_vs_time.png', dpi=300, bbox_inches='tight')
plt.show()

# -----------------------------------------------------------------
# Chart 3: Speedup Factor Horizontal Bar Chart
# -----------------------------------------------------------------
fig3, ax3 = plt.subplots(figsize=(10, 6))
bars = ax3.barh(
    df_speedup_med['family'],
    df_speedup_med['speedup'],
    color=sns.color_palette("viridis", len(df_speedup_med))
)
ax3.set_xlabel('Median Speedup (NoWL time / 1WL time)', fontsize=12)
ax3.set_ylabel('Graph Family', fontsize=12)
ax3.set_title('Speedup from 1-WL Preprocessing by Family', fontsize=14)
ax3.axvline(x=1, color='red', linestyle='--', linewidth=1.5, label='No speedup (x1)')

# Add text labels on bars
for bar in bars:
    width = bar.get_width()
    ax3.text(width * 1.02, bar.get_y() + bar.get_height()/2, 
             f'{width:.1f}x', va='center', fontsize=10)

ax3.legend()
ax3.grid(axis='x', linestyle='--', alpha=0.5)

plt.tight_layout()
plt.savefig('chart3_speedup_bars.png', dpi=300, bbox_inches='tight')
plt.show()

# -----------------------------------------------------------------

# ============================================================
# 3. GENERATE TABLES (similar to Table 1 and 3)
# ============================================================

# Helper: geometric mean of (time+1) - 1 (as in paper)
def geom_mean_shifted(times, timeout=3600):
    # replace timeouts with timeout? Already in data, but ensure
    # we treat time limit as 3600 if status is timeout.
    # We'll use the actual recorded time (which may be < timeout).
    # For geometric mean, we need to include all instances, even timeouts.
    # The paper uses (time+1) geometric mean then subtract 1.
    # If an instance timed out, time is recorded as 3600? In our data, it's less, but we can cap at 3600.
    # We'll use the actual total_time, but for timeout status we might want to set to 3600.
    # However the paper's table includes timeouts with 3600s.
    # So we should set any status "Time limit reached" to 3600.0.
    times = np.array(times)
    times = np.where(times > 3600, 3600, times)  # cap
    shifted = times + 1.0
    geom_shifted = np.exp(np.mean(np.log(shifted)))
    return geom_shifted - 1.0

# For iso table: per family and solver (NoWL, 1WL)
iso_summary = df_iso[df_iso['solver_name'].isin(['NoWL', '1WL'])].copy()

# Mark solved if status is "User defined stop" (or "Optimal")? 
# In your data, solved means status is not "Time limit reached" and not "Error".
# So we define solved as status != "Time limit reached"
iso_summary['solved'] = iso_summary['status'] != 'Time limit reached'

# Pivot to get counts and times
iso_pivot = iso_summary.groupby(['family', 'solver_name']).agg(
    n_instances=('instance', 'count'),
    n_solved=('solved', 'sum'),
    times=('total_time', list)
).reset_index()

# Compute % solved and geom mean time
iso_pivot['pct_solved'] = iso_pivot['n_solved'] / iso_pivot['n_instances'] * 100
iso_pivot['geom_time'] = iso_pivot['times'].apply(lambda t: geom_mean_shifted(t, timeout=3600))

# Now pivot to wide format: one row per family
iso_wide = iso_pivot.pivot(index='family', columns='solver_name', values=['n_instances', 'pct_solved', 'geom_time'])
# Flatten multiindex
iso_wide.columns = [f'{col[0]}_{col[1]}' for col in iso_wide.columns]
iso_wide = iso_wide.reset_index()

# Also get speedup (median) per family from df_speedup
speedup_med = df_speedup.groupby('family')['speedup'].median().reset_index(name='speedup_median')
iso_wide = iso_wide.merge(speedup_med, on='family', how='left')

# Reorder columns
iso_wide = iso_wide[['family', 'n_instances_NoWL', 'pct_solved_NoWL', 'geom_time_NoWL',
                     'pct_solved_1WL', 'geom_time_1WL', 'speedup_median']]
# Rename for clarity
iso_wide.columns = ['Family', '# Instances', '% Solved (NoWL)', 'Time (NoWL)',
                    '% Solved (1WL)', 'Time (1WL)', 'Speedup (median)']

# Print as table (you can also export to CSV)
print("\n===== Table 1: Performance on Isomorphic Graphs =====")
print(iso_wide.to_string(index=False, float_format='%.1f'))

# Optionally save to CSV
iso_wide.to_csv('table1_isomorphic_performance.csv', index=False)

# ============================================================
# Table for Non-Isomorphic Graphs
# ============================================================

noniso_summary = df_noniso[df_noniso['solver_name'].isin(['NoWL', '1WL_noniso'])].copy()
noniso_summary['solved'] = noniso_summary['status'] != 'Time limit reached'
# For 1WL_noniso, "solved" could be defined as early_stop == True (which proves non-isomorphism)
# But we can also count as solved if not timeout.

# ---- Non-iso pivot ----
noniso_pivot = noniso_summary.groupby(['family', 'solver_name']).agg(
    n_instances=('instance', 'count'),
    n_solved=('solved', 'sum'),
    times=('total_time', list)
).reset_index()

noniso_pivot['pct_solved'] = noniso_pivot['n_solved'] / noniso_pivot['n_instances'] * 100
noniso_pivot['geom_time'] = noniso_pivot['times'].apply(lambda t: geom_mean_shifted(t, timeout=3600))

# Pivot
noniso_wide = noniso_pivot.pivot(index='family', columns='solver_name', 
                                 values=['n_instances', 'pct_solved', 'geom_time'])
noniso_wide.columns = [f'{col[0]}_{col[1]}' for col in noniso_wide.columns]
noniso_wide = noniso_wide.reset_index()

# Add early_stop_pct
early_stop_pct = df_noniso[df_noniso['solver_name'] == '1WL_noniso'].groupby('family').apply(
    lambda g: (g['early_stop'] == True).mean() * 100
).reset_index(name='early_stop_pct')
noniso_wide = noniso_wide.merge(early_stop_pct, on='family', how='left')

# Now we may have missing columns if a solver didn't appear for a family.
# We'll fill missing with NaN, but ensure the columns we want exist.
for solver in ['NoWL', '1WL_noniso']:
    for metric in ['n_instances', 'pct_solved', 'geom_time']:
        col = f'{metric}_{solver}'
        if col not in noniso_wide.columns:
            noniso_wide[col] = np.nan

# Select and order
noniso_wide = noniso_wide[['family', 'n_instances_NoWL', 'pct_solved_NoWL', 'geom_time_NoWL',
                           'n_instances_1WL_noniso', 'pct_solved_1WL_noniso', 'geom_time_1WL_noniso',
                           'early_stop_pct']]
noniso_wide.columns = ['Family', '# Instances (NoWL)', '% Solved (NoWL)', 'Time (NoWL)',
                       '# Instances (1WL)', '% Solved (1WL)', 'Time (1WL)', '% Early Stopped']

# Replace NaN with '-' for display
noniso_wide = noniso_wide.fillna('-')

print("\n===== Table 2: Performance on Non-Isomorphic Graphs =====")
print(noniso_wide.to_string(index=False, float_format='%.1f'))
