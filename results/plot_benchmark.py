import matplotlib.pyplot as plt
import numpy as np

methods = ['L1 Serial\n(1T)', 'L2 Multicore\n(8T)', 'NF 24core', 'Bash\nParallel', 'NF Scratch\n24core', 'NF 48core']
means = [20796, 4571, 1339, 1261, 1134, 843]
stds = [542, 347, 36, 52, 60, 32]
speedups = [1.0, 4.6, 15.5, 16.5, 18.3, 24.7]

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

colors = ['#d32f2f', '#f57c00', '#1976d2', '#388e3c', '#00796b', '#7b1fa2']
bars = ax1.bar(methods, means, yerr=stds, capsize=5, color=colors, alpha=0.85)
ax1.set_ylabel('Runtime (seconds)', fontsize=12)
ax1.set_title('RNA-seq Pipeline Benchmark\n(mean of 3 runs, error bars = std dev)', fontsize=12)
for bar, speedup in zip(bars, speedups):
    ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 300,
             f'{speedup}×', ha='center', va='bottom', fontsize=10, fontweight='bold')
ax1.set_ylim(0, 24000)

ax2.plot(methods, speedups, 'o-', color='#1976d2', linewidth=2, markersize=8)
ax2.fill_between(range(len(methods)), speedups, alpha=0.15, color='#1976d2')
ax2.set_ylabel('Speedup vs Baseline', fontsize=12)
ax2.set_title('Speedup Progression', fontsize=12)
ax2.set_xticks(range(len(methods)))
ax2.set_xticklabels(methods)
ax2.axhline(y=1, color='red', linestyle='--', alpha=0.5)
for i, (m, s) in enumerate(zip(methods, speedups)):
    ax2.annotate(f'{s}×', (i, s), textcoords="offset points", xytext=(0, 8), ha='center', fontsize=10)

plt.tight_layout()
plt.savefig('/scratch/e1546946/phm5004/results/benchmark_plot.png', dpi=150, bbox_inches='tight')
print("Saved!")