#= 
https://switchtimeoptjl.readthedocs.io/en/latest/quick_example.html

This example is just a twick of the orignal in order to make it compatible with julia 1.3.1

=#

using LinearAlgebra
using SwitchTimeOpt
using Ipopt


# Time Interval
t0 = 0.0; tf = 1.0

# Initial State
x0 = [1.0; 1.0]

# Dynamics
A = Array{Float64}(undef, 2, 2, 2)
A[:, :, 1] = randn(2, 2)  # A_0 matrix
A[:, :, 2] = randn(2, 2)  # A_1 matrix

# Create Problem
m = stoproblem(x0, A, t0=t0, tf=tf)

# Solve Problem
solve!(m)

# Get optimal Solution
tauopt = gettau(m)

# Get optimum value
objval = getobjval(m)
