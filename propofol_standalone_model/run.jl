# Solve one exported trial of the propofol circuit:  julia --project=. run.jl [trial] [condition]
# with trial ∈ LOGO, LOGR, LRGR and condition ∈ awake, anesthetized.
using OrdinaryDiffEqVerner

trial = get(ARGS, 1, "LRGR")
condition = get(ARGS, 2, "awake")
name = "$(trial)_$(condition)"
include(joinpath(@__DIR__, "models", name * ".jl"))
model = getfield(Main, Symbol(name))

prob = model.problem()
sol = solve(prob, Vern7(); saveat = 0.1)
println(name, ": ", sol.retcode, ", ", length(model.state_names), " states, ",
        length(model.param_names), " parameters, t = ", sol.t[1], "–", sol.t[end], " ms")
