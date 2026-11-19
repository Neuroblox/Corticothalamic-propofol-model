# Propofol corticothalamic circuit — standalone model

This folder contains the corticothalamic circuit model used to simulate auditory responses in the
awake state and under propofol, as plain Julia code. Each model file holds the full system of
ordinary differential equations (as generated code), its initial state, its parameter values, and
the timed stimulus events. Running it requires only Julia and three registered packages.

The files were generated from the original model with the standalone export of
[Neuroblox.jl](https://github.com/Neuroblox) (`write_standalone`), and checked against it: the
right-hand sides agree to rounding error, and the stimulus currents are reproduced exactly.

## Requirements

| | |
|---|---|
| Julia | 1.12 (tested with 1.12.6), from [julialang.org](https://julialang.org/downloads/) or `juliaup` |
| Packages | `SciMLBase`, `SymbolicIndexingInterface`, `OrdinaryDiffEqVerner` (pinned in `Manifest.toml`) |
| Memory | about 4 GB of RAM per running model |
| Disk | about 40 MB for the model files, plus the installed packages |
| Time | about 1–2 min per 1-second trial on a desktop CPU, most of it compiling the model on first use |

The model is deterministic: it has no noise, and its random connectivity is fixed in the files.

## Quick start

From this folder, install the exact package versions once:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Then simulate one trial (here the LRGR trial under propofol):

```bash
julia --project=. run.jl LRGR anesthetized
```

which prints

```
LRGR_anesthetized: Success, 2762 states, 15920 parameters, t = 0.0–1000.0 ms
```

## Contents

```
Project.toml, Manifest.toml   the packages the model needs, at their tested versions
run.jl                        loads one model and solves it
models/<trial>_<condition>.jl one Julia module per trial type and condition
```

There are three trial types (`LOGO`, `LOGR`, `LRGR`), each in two conditions (`awake`,
`anesthetized`). The six files contain the same equations and initial state, and differ only in
their parameter values (`p0`).

## The trials

Times are in ms. Every trial runs from 0 to 1000 ms and starts from the same state, reached by
simulating the awake circuit without stimulation for 2000 ms.

The circuit has two auditory modules, A and B, each with a core and a matrix thalamic nucleus, a
reticular nucleus and cortical layers 2/3, 4, 5 and 6. Both project to a shared layer 2/3
population (`Layer_2_3_ac`). Each trial presents five 50 ms tones as current pulses into the core
thalamus, starting at 100, 250, 400, 550 and 700 ms:

- tones 1–4 go to module A (`InfC_A`), amplitude 2.0;
- tone 5 goes to module A (`InfC_A_5`) or module B (`InfC_B`), depending on the trial type.

| Trial type | Tone 5 into module A | Tone 5 into module B |
|---|---|---|
| `LOGO` | 0.0 | 3.5 |
| `LOGR` | 0.0 | 3.0 |
| `LRGR` | 2.0 | 0.0 |

In the `anesthetized` condition, propofol is modelled by a dose factor of 2.5:

- every GABA-A synapse has 2.5× its conductance and 2.5× its decay time constant;
- the tonic inhibition of the thalamus by the globus pallidus (`GPi_src`) is 2.5× stronger;
- the ascending drive of the reticular nuclei (`ASC2 => Nrt_A`, `ASC2 => Nrt_B`) is switched off.

## Using a model

Load one model from Julia (or the REPL), and solve it with any solver of the
[DifferentialEquations.jl](https://docs.sciml.ai/DiffEqDocs/stable/) ecosystem:

```julia
using OrdinaryDiffEqVerner
include("models/LRGR_awake.jl")

prob = LRGR_awake.problem()                  # ODEProblem over (0, 1000) ms
sol = solve(prob, Vern7(); saveat = 0.1)
```

States, parameters and observed quantities keep the names of the original model. Names are
hierarchical, with `₊` separating levels, e.g. `g₊Layer_2_3_A₊wta1₊exci1₊V` is the membrane
potential of excitatory neuron 1 of winner-take-all unit 1 of layer 2/3 in module A. Index a
solution or a problem by these names:

```julia
V = sol[:g₊Layer_2_3_A₊wta1₊exci1₊V]          # a state along the solution
I = sol[:g₊InfC_A₊I]                           # the tone current into module A

using SymbolicIndexingInterface: getp, setp
getp(prob, :g₊InfC_A₊pulse_amp)(prob)          # read a parameter
setp(prob, :g₊InfC_A₊pulse_amp)(prob, 1.5)     # change it, then solve again
```

Each module defines:

| Name | |
|---|---|
| `problem(tspan = tspan; u0 = u0, p = p0, kwargs...)` | the `ODEProblem`, with the stimulus events attached |
| `rhs!(du, u, p, t)` | the right-hand side of the ODE |
| `u0`, `p0` | the initial state and the parameter values |
| `state_names`, `param_names`, `observed_names` | the names of the entries of `u0`, of `p0`, and of the observed quantities |
| `tspan`, `tstops` | the time span of a trial, and the times of the tone onsets and offsets |

Use `tstops` (which `problem` passes on by default) when solving with a different setup, so that
the solver steps exactly onto the tone onsets and offsets.

The circuit consists of spiking neurons and is chaotic. Different solvers, tolerances, Julia
versions or CPUs therefore give spike trains that agree for the first few milliseconds and then
diverge. Population measures such as firing rates and multi-unit activity are what is reproducible.
