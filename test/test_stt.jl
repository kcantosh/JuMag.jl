using JuMag
using Test
using NPZ

JuMag.cuda_using_double(false)

function init_dw(i,j,k,dx,dy,dz)
  if i < 150
    return (1,0.1,0)
  elseif i<160
   return (0,1,0.1)
  else
   return (-1,0.1,0)
  end
end

function relax_system(mesh)
	sim = Sim(mesh, name="stt_relax", driver="SD")
	set_Ms(sim, 8.6e5)

	add_exch(sim, 1.3e-11)
	add_anis(sim, 1e5, axis=(1,0,0))

	init_m0(sim, init_dw)
	relax(sim, maxsteps=2000, stopping_torque=0.1, save_vtk_every = -1)
	npzwrite("stt_m0.npy", sim.spin)
end


function run_dynamics_stt(mesh; alpha=0.1, beta=0.0, u=10)
	sim = Sim(mesh, name="stt_dyn", driver="LLG_STT")
	set_Ms(sim, 8.6e5)
	sim.driver.alpha = alpha
	sim.driver.beta = beta
	sim.driver.gamma = 2.21e5
    set_ux(sim, u)   #init_scalar!(sim.driver.ux, mesh, u)

	add_exch(sim, 1.3e-11)
	add_anis(sim, 1e5, axis=(1,0,0))

	init_m0(sim, npzread("stt_m0.npy"))
	m =  reshape(sim.spin, 3, sim.nxyz)
	m_0 = sum(m[1, :])/sim.nxyz

	for i=1:10
		run_until(sim, 1e-11*i)
		println("t = ", 1e-11*i)
        #save_vtk(sim, "stt_dyn_"*string(i))
	end
	m_1 = sum(m[1, :])/sim.nxyz
	L = mesh.nx * mesh.dx
	v = 0.5*(m_1 - m_0)*L/1e-10
	v_expect = (1+alpha*beta)/(1+alpha^2)*u
	println(v, " expected v=", v_expect)
	@test (abs(v-v_expect)/v_expect)<0.006
	return nothing
end

mesh =  FDMesh(nx=500, ny=1, nz=11, dx=2e-9, dy=2e-9, dz=1e-9)
relax_system(mesh)
for (beta, u) in [(0, 10), (0.1, 3.2), (0.2, 4.7)]
  run_dynamics_stt(mesh, beta=beta, u=u)
end