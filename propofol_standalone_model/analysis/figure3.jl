# Simulated MUA of posterior and anterior cortex for the oddball trial types, awake and under
# propofol (manuscript Fig 3e-h).
#
#     julia --project=analysis analysis/figure3.jl
#
# run from the `propofol_standalone_model` folder. Writes analysis/output/figure3.png and the
# traces to analysis/output/figure3_mua.csv.
#
# The model files hold one realization of the circuit's random connectivity, so the traces are
# those of that realization; the manuscript figure averages over realizations.
#
# The LRGO trial type (AAAAA presented as the rare sequence of an AAAAB block) is not among the
# exported trials: in the model its input is that of LRGR.

include(joinpath(@__DIR__, "common.jl"))
using CairoMakie

const COLORS = (LOGO = :purple, LOGR = :red, LRGR = :black)
const CONDITIONS = (awake = 1.0, anesthetized = P_ANESTHETIC)

results = Dict()
for trial in TRIALS, (condition, P) in pairs(CONDITIONS)
    @info "simulating $trial, $condition"
    @time results[(trial, condition)] = simulate(parameters_at_dose(trial, P))
end
t = results[(:LRGR, :awake)].t

fig = Figure(size = (900, 650))
panels = [(:posterior, :awake, "e  Posterior cortex, awake"),
          (:posterior, :anesthetized, "f  Posterior cortex, propofol"),
          (:anterior, :awake, "g  Anterior cortex, awake"),
          (:anterior, :anesthetized, "h  Anterior cortex, propofol")]
for (k, (region, condition, title)) in enumerate(panels)
    ax = Axis(fig[fldmod1(k, 2)...]; title, titlealign = :left,
              xlabel = "Time (ms)", ylabel = "Simulated MUA")
    vspan!(ax, collect(TONE_STARTS), collect(TONE_STARTS) .+ TONE_WIDTH; color = (:pink, 0.5))
    for trial in TRIALS
        lines!(ax, t, results[(trial, condition)].mua[region]; color = COLORS[trial], label = String(trial))
    end
    k == 1 && axislegend(ax; position = :rt, framevisible = false)
end
# Same vertical scale for the awake and propofol panels of each region.
for row in 1:2
    linkyaxes!(contents(fig[row, 1])[1], contents(fig[row, 2])[1])
end

outdir = joinpath(@__DIR__, "output")
mkpath(outdir)
save(joinpath(outdir, "figure3.png"), fig; px_per_unit = 2)
header = ["t_ms"; ["$(r)_$(c)_$(tr)" for r in (:posterior, :anterior) for c in keys(CONDITIONS) for tr in TRIALS]]
columns = [[t]; [results[(tr, c)].mua[r] for r in (:posterior, :anterior) for c in keys(CONDITIONS) for tr in TRIALS]]
write_csv(joinpath(outdir, "figure3_mua.csv"), header, columns)
println("wrote ", joinpath(outdir, "figure3.png"))
