# Residual inter-stimulus activity across propofol doses (manuscript Fig 5a,c and Fig H in S1
# Appendix).
#
#     julia --project=analysis analysis/figure5.jl [P1 P2 ...]
#
# run from the `propofol_standalone_model` folder. The optional arguments are the dose factors to
# simulate (default 1.0 1.5 2.5: awake, sub-anesthetic and anesthetic). Writes
# analysis/output/figure5.png, the posterior MUA traces to analysis/output/figure5_mua.csv and the
# residual activity to analysis/output/figure5_residual.csv.
#
# Residual activity (Methods, Residual activity): the mean posterior MUA in the 50 ms before each
# of tones 2-5 of an LRGR trial (AAAAA), averaged over the four windows. Net residual activity is
# its difference from the awake value (dose factor 1).
#
# Doses other than 1 and 2.5 are obtained by interpolating the awake and anesthetized parameter
# values, which is exact because every dose-dependent parameter is linear in the dose (see
# `parameters_at_dose` in common.jl). Above 2.5 the ascending drive of the reticular nuclei,
# 3 (2.5 - P), becomes negative.
#
# The model files hold one realization of the circuit's random connectivity, so each dose gives
# one value; the manuscript shows the distribution over 25 realizations.

include(joinpath(@__DIR__, "common.jl"))
using CairoMakie

const TRIAL = :LRGR
const WINDOW = 50.0   # ms before each tone
doses = isempty(ARGS) ? [1.0, 1.5, 2.5] : parse.(Float64, ARGS)
1.0 in doses || pushfirst!(doses, 1.0)   # the awake value is the reference
sort!(unique!(doses))

"Mean of `x` over the `WINDOW` ms before each of tones 2-5, averaged over the four windows."
residual(t, x) = mean(mean(x[(t .>= t0 - WINDOW) .& (t .< t0)]) for t0 in TONE_STARTS[2:end])

runs = map(doses) do P
    @info "simulating $TRIAL at dose factor $P"
    @time simulate(parameters_at_dose(TRIAL, P); regions = (:posterior,))
end
t = runs[1].t
res = [residual(t, r.mua.posterior) for r in runs]
net = res .- res[findfirst(==(1.0), doses)]

fig = Figure(size = (1000, 420))
colors = cgrad([:lightblue, :darkblue], max(length(doses), 2); categorical = true)
ax1 = Axis(fig[1, 1]; title = "a  Posterior cortex, LRGR trial", titlealign = :left,
           xlabel = "Time (ms)", ylabel = "Simulated MUA")
vspan!(ax1, collect(TONE_STARTS), collect(TONE_STARTS) .+ TONE_WIDTH; color = (:pink, 0.5))
vspan!(ax1, collect(TONE_STARTS[2:end]) .- WINDOW, collect(TONE_STARTS[2:end]); color = (:gray, 0.2))
for (k, (P, r)) in enumerate(zip(doses, runs))
    lines!(ax1, t, r.mua.posterior; color = colors[k], label = "P = $P")
end
axislegend(ax1; position = :rt, framevisible = false)
ax2 = Axis(fig[1, 2]; title = "c  Net residual activity", titlealign = :left,
           xlabel = "Propofol dose factor P", ylabel = "Residual − awake residual",
           xticks = doses)
hlines!(ax2, [0.0]; color = :gray, linestyle = :dash)
scatterlines!(ax2, doses, net; color = :darkblue, markercolor = [colors[k] for k in eachindex(doses)],
              markersize = 14)
colsize!(fig.layout, 2, Relative(0.35))

outdir = joinpath(@__DIR__, "output")
mkpath(outdir)
save(joinpath(outdir, "figure5.png"), fig; px_per_unit = 2)
write_csv(joinpath(outdir, "figure5_mua.csv"), ["t_ms"; ["posterior_P$(P)" for P in doses]],
          [[t]; [r.mua.posterior for r in runs]])
write_csv(joinpath(outdir, "figure5_residual.csv"), ["dose_factor", "residual", "net_residual"],
          [doses, res, net])
println("wrote ", joinpath(outdir, "figure5.png"))
for (P, r, n) in zip(doses, res, net)
    println("  P = $P: residual = $(round(r; sigdigits=4)), net = $(round(n; sigdigits=4))")
end
