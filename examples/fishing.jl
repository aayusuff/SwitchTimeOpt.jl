using SwitchTimeOpt

# # Plotting settings
# using PyPlot, PyCall
# close("all")
# # Import seaborn for nice plots
# @pyimport seaborn as sns
# sns.set_palette("hls", 8)
# sns.set_context("paper", font_scale=1.5)
# sns.set_style("whitegrid")
# # Use Latex Labels in Plots

# plt[:rc]("text", usetex=true)
# plt[:rc]("font", family="serif")

maxiter = 20
using Ipopt
solver = IpoptSolver(
  print_level=0,
  max_iter=maxiter)


### Define system parameters
# Time vector
t0 = 0.0
tf = 12.0

# Size of the system
nx = 4

# Integer input
uvec = [repeat([0.0; 1.0], 4, 1); 0.0]


# Number of switching times
# N = size(uvec,2) - 1

N = size(uvec,1) - 1


# Cost funcction matrix
C = [1.0 0.0 -1.0 0.0;
     0.0 1.0 0.0  -1.0]
Q = C'*C

# Define initial state
x0 = [0.5; 0.7; 1; 1]


### Define system dynamics
function nldyn(x::Array{Float64,1}, u::Array{Float64,1})
  n = length(x)
  f = zeros(n)
  f[1] = x[1] - x[1]*x[2] - 0.4*x[1]*u[1]
  f[2] = -x[2] + x[1]*x[2] - 0.2*x[2]*u[1]
  return f

end

function nldyn_deriv(x::Array{Float64,1}, u::Array{Float64,1})
  df = [1.0-x[2]-0.4*u[1]       -x[1]                   0    0;
        x[2]                     -1+x[1]-0.2*u[1]       0    0;
        0                        0                      0    0;
        0                        0                      0    0]
end


### Generate and solve problems with different grid points
ngrid = [100; 150; 200; 250]

# idx200 = (find(ngrid .== 200))[1]
idx200 = findall((k)-> k== 200, ngrid)[1]


# Preallocate vectors for results
objode45 = Array{Float64}(undef,length(ngrid))
objlin = Array{Float64}(undef, length(ngrid))
objiterates = Array{Float64}(undef, maxiter+1, length(ngrid))
cputime = Array{Float64}(undef, length(ngrid))
nobjeval = Array{Int}(undef, length(ngrid))
ngradeval = Array{Int}(undef, length(ngrid))
nhesseval = Array{Int}(undef, length(ngrid))
tauopt = Array{Float64}(undef, N, length(ngrid))
xsim = Array{Float64}(undef, 4, 10^4, length(ngrid))
xlinsim = Array{Float64}(undef, 4, 10^4, length(ngrid))
usim = Array{Float64}(undef,1, 10^4, length(ngrid))

# Initialize the problem first
m = stoproblem(x0, nldyn, nldyn_deriv, uvec)

for i = 1:length(ngrid)  # Iterate over all grid points numbers
    
  m = stoproblem(
    x0,                 # Initial state
    nldyn,              # Nonlinear dynamics
    nldyn_deriv,        # Nonlinear dynamics derivative
    uvec,               # Vector of integer inputs
    ngrid = ngrid[i],   # Number of grid points
    t0 = t0,            # Initial time
    tf = tf,            # Final time
    Q = Q,              # Cost matrix
    solver = solver)

  # Solve optimization
  solve!(m)

  # Obtain values
  tauopt[:, i] = gettau(m)
  objlin[i]    = getobjval(m)
  cputime[i]   = getsoltime(m)
  nobjeval[i]  = getnobjeval(m)
  ngradeval[i] = getngradeval(m)
  nhesseval[i] = getnhesseval(m)

  # Simulate system
  # Nonlinear simulation
  xsim[:, :, i], xpts, objode45[i], t = simulate(m, tauopt[:, i])

  usim[:, :, i], _ = simulateinput(m, t)

  ## Linearized simulation
  xlinsim[:, :, i], _, Jlinsim, _ = simulatelinearized(m, tauopt[:, i], t)
    
  ## Save objective function iterates
  objiterates[:, i] = m.STOev.obj[2:end]

  # push!(objiterates[:, i], m.STOev.obj[2:end])
    
end


###  Print results
@printf("RESULTS\n")
@printf("-------\n\n")

@printf("+==================================================================================+\n")
@printf("|  ngrid   |   objode45  |   objlin    | deltaobj [%%] |  nobjeval  |  cputime [s]  |\n")
@printf("+==================================================================================+\n")


for i = 1:length(ngrid)
  @printf("|  %7.i | %9.4f   | %9.4f   |   %6.3f     | %9.i  | %12.4f  | \n", ngrid[i], objode45[i], objlin[i], 100*norm(objode45[i]- objlin[i])/objode45[i], nobjeval[i], cputime[i])
  @printf("+----------------------------------------------------------------------------------+\n")
end



@printf("\nOptimal Switching Times for ngrid = 200\n")
@printf("--------------------------------------\n")
@printf("tauopt = "); show(round.(tauopt[:, idx200],3)); @printf("\n")


# Generate plots for ngrid = 25
t = range(t0, stop = tf, length = 10000)

figure()
subplot(3,1,1)
plot(t, xlinsim[1,:, idx200], sns.xkcd_rgb["grass green"], linestyle = "dashdot")
plot(t, xsim[1,:, idx200], sns.xkcd_rgb["denim blue"])
ylim(0, 1.75)
yticks([0; 1; ])
ylabel(L"x_1")

subplot(3,1,2)
plot(t, xlinsim[2,:, idx200], sns.xkcd_rgb["grass green"], linestyle = "dashdot")
plot(t, xsim[2, :, idx200], sns.xkcd_rgb["denim blue"])
ylabel(L"x_2")
ylim(0, 1.75)
yticks([0; 1; ])

subplot(3,1,3)
plot(t, usim[1,:, idx200], sns.xkcd_rgb["denim blue"])
ylim(-0.2, 1.2)
yticks([0; 1])
ylabel(L"u")
xlabel(L"$\mathrm{Time}\; [s]$")

# Save figure
# tight_layout()
# savefig("fishing_problem.pdf")




# Do not return anything
nothing
