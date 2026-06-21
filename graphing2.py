import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# ------------------------------------------------------------
# 1. Load your CSV file (adjust path if needed)
# ------------------------------------------------------------
df = pd.read_csv("full_1wl_results.csv")

# ------------------------------------------------------------
# 2. Filter: only 1WL_noniso runs that proved non-iso
# ------------------------------------------------------------
df_noniso = df[
    (df["solver_name"] == "1WL_noniso") &
    (df["early_stop"] == True) &
    (df["early_reason"] == "wl") &
    (df["total_time"].notna())
].copy()

# ------------------------------------------------------------
# 3. Add a 'family' column based on instance name
# ------------------------------------------------------------
def get_family(inst):
    if inst.startswith("cfi"):
        return "CFI"
    elif inst.startswith("CHH"):
        return "CHH"
    elif inst.startswith("exact"):
        return "Exact"
    elif inst.startswith("latin"):
        return "Latin"
    elif inst.startswith("Lattice"):
        return "Lattice"
    elif inst.startswith("paley_power") or inst.startswith("paley_prime"):
        return "Paley"
    elif inst.startswith("Triangular"):
        return "Triangular"
    else:
        return "Other"

df_noniso["family"] = df_noniso["instance"].apply(get_family)

# ------------------------------------------------------------
# 4. Summary statistics per family
# ------------------------------------------------------------
summary = df_noniso.groupby("family")["total_time"].agg(["mean", "median", "max", "count"]).reset_index()
summary.columns = ["Family", "mean_time", "median_time", "max_time", "n_instances"]
summary = summary.sort_values("mean_time")

print("Non-iso certification summary:")
print(summary)

# ------------------------------------------------------------
# 5. Plot 1: Bar chart of mean certification time per family
# ------------------------------------------------------------
plt.figure(figsize=(10, 6))
bars = plt.bar(summary["Family"], summary["mean_time"], color="red")
plt.xlabel("Graph Family")
plt.ylabel("Mean non-iso certification time (seconds)")
plt.title("1‑WL - Non‑Isomorphism")
plt.xticks(rotation=45)
plt.ylim(0, summary["mean_time"].max() * 1.2)

# Add value labels on top of bars
for bar in bars:
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height + 0.001,
             f'{height:.4f}s', ha='center', va='bottom', fontsize=9)

plt.tight_layout()
plt.show()

# ------------------------------------------------------------
# 6. Plot 2: Scatter plot of all individual certification times
# ------------------------------------------------------------
plt.figure(figsize=(12, 6))
sns.stripplot(data=df_noniso, x="family", y="total_time", jitter=True, color="coral", size=6)
plt.yscale("log")
plt.xlabel("Graph Family")
plt.ylabel("Certification time (seconds, log scale)")
plt.title("All 1‑WL Non‑Iso Certifications (all <0.5s)")
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

