function effective_field(zee::Zeeman, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4*pi*1e-7
  nxyz = sim.nxyz
  field = zee.field
  volume = sim.mesh.volume
  for i = 1:nxyz
    j = 3*(i-1)
    zee.energy[i] = -mu0*sim.Ms[i]*volume*(spin[j+1]*field[j+1] + spin[j+2]*field[j+2] + spin[j+3]*field[j+3])
  end
end

function effective_field(zee::TimeZeeman, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4*pi*1e-7
  nxyz = sim.nxyz
  field = zee.field
  b = reshape(field, 3, nxyz)
  b0 = reshape(zee.init_field, 3, nxyz)
  volume = sim.mesh.volume
  b[1, :] = b0[1, :]*zee.fun_x(t)
  b[2, :] = b0[2, :]*zee.fun_y(t)
  b[3, :] = b0[3, :]*zee.fun_z(t)
  for i = 1:nxyz
    j = 3*(i-1)
    zee.energy[i] = -mu0*sim.Ms[i]*volume*(spin[j+1]*field[j+1] + spin[j+2]*field[j+2] + spin[j+3]*field[j+3])
  end
end

function effective_field(zee::Zeeman, sim::AtomicSim, spin::Array{Float64, 1}, t::Float64)
  nxyz = sim.nxyz
  field = zee.field
  mu_s = sim.mu_s
  for i = 1:nxyz
    j = 3*(i-1)
    zee.energy[i] = -mu_s[i]*(spin[j+1]*field[j+1] + spin[j+2]*field[j+2] + spin[j+3]*field[j+3])
  end
end

function effective_field(anis::Anisotropy, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4.0*pi*1e-7
  mesh = sim.mesh
  nxyz = sim.nxyz
  field = anis.field
  energy = anis.energy
  Ms = sim.Ms
  Ku = anis.Ku
  axis = anis.axis
  for i = 1:nxyz
    if Ms[i] == 0.0
      energy[i] = 0.0
      field[3*i-2] = 0.0
      field[3*i-1] = 0.0
      field[3*i] = 0.0
      continue
    end
    k = 3*(i-1)
    sa = spin[k+1]*axis[1]+spin[k+2]*axis[2]+spin[k+3]*axis[3]
    Ms_inv = 1.0/(Ms[i]*mu0)
    field[k+1] = 2*Ku[i]*sa*axis[1]*Ms_inv
    field[k+2] = 2*Ku[i]*sa*axis[2]*Ms_inv
    field[k+3] = 2*Ku[i]*sa*axis[3]*Ms_inv
    energy[i] = Ku[i]*(1.0-sa*sa)*mesh.volume
  end

end

function effective_field(anis::Anisotropy, sim::AtomicSim, spin::Array{Float64, 1}, t::Float64)
  mesh = sim.mesh
  nxyz = sim.nxyz
  field = anis.field
  energy = anis.energy
  mu_s = sim.mu_s
  Ku = anis.Ku
  axis = anis.axis
  for i = 1:nxyz
    if mu_s[i] == 0.0
      continue
    end
    k = 3*(i-1)
    sa = spin[k+1]*axis[1]+spin[k+2]*axis[2]+spin[k+3]*axis[3]
    mu_s_inv = 1.0/mu_s[i]
    field[k+1] = 2*Ku[i]*spin[k+1]*axis[1]*mu_s_inv
    field[k+2] = 2*Ku[i]*spin[k+2]*axis[2]*mu_s_inv
    field[k+3] = 2*Ku[i]*spin[k+3]*axis[3]*mu_s_inv
    energy[i] = Ku[i]*(1.0-sa*sa)
  end

end

function effective_field(exch::Exchange, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4.0*pi*1e-7
  mesh = sim.mesh
  dx = mesh.dx
  dy = mesh.dy
  dz = mesh.dz
  ngbs = mesh.ngbs
  nxyz = sim.nxyz
  field = exch.field
  energy = exch.energy
  Ms = sim.Ms
  ax = 2.0 * exch.A / (dx * dx)
  ay = 2.0 * exch.A / (dy * dy)
  az = 2.0 * exch.A / (dz * dz)
  A = (ax, ax, ay, ay, az, az)

  Threads.@threads for index = 1:nxyz
    if Ms[index] == 0.0
      continue
    end
	i = 3*index - 2
    fx, fy, fz = 0.0, 0.0, 0.0
    for j=1:6
      id = ngbs[j,index]
      if id>0 && Ms[id]>0
        k = 3*id-2
        fx += A[j]*(spin[k]-spin[i])
        fy += A[j]*(spin[k+1]-spin[i+1])
        fz += A[j]*(spin[k+2]-spin[i+2])
      end
    end
    Ms_inv = 1.0/(Ms[index]*mu0)
    energy[index] = -0.5*(fx*spin[i] + fy*spin[i+1] + fz*spin[i+2])*mesh.volume
    field[i] = fx*Ms_inv
    field[i+1] = fy*Ms_inv
    field[i+2] = fz*Ms_inv
  end
end


function effective_field(exch::ExchangeRKKY, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4.0*pi*1e-7
  mesh = sim.mesh
  field = exch.field
  energy = exch.energy
  Ms = sim.Ms
  sigma = exch.sigma/exch.Delta
  nx, ny, nz = mesh.nx, mesh.ny, mesh.nz
  for i=1:nx, j=1:ny
      id1 = (j-1) * nx + i
      id2 = (nz-1) * nx*ny + (j-1) * nx + i
      k1 = 3*id1-2
      k2 = 3*id2-2
      mbx = spin[k1]
      mby = spin[k1+1]
      mbz = spin[k1+2]

      mtx = spin[k2]
      mty = spin[k2+1]
      mtz = spin[k2+2]

      if Ms[id1] > 0 && Ms[id2] > 0
          Ms_inv = 1.0/(Ms[id1]*mu0)
          field[k1] = sigma*Ms_inv*mtx
          field[k1+1] = sigma*Ms_inv*mty
          field[k1+2] = sigma*Ms_inv*mtz
          energy[id1] = 0.5*sigma*(1-mtx*mbx-mty*mby-mtz*mbz)

          Ms_inv = 1.0/(Ms[id2]*mu0)
          field[k2] = sigma*Ms_inv*mbx
          field[k2+1] = sigma*Ms_inv*mby
          field[k2+2] = sigma*Ms_inv*mbz
          energy[id2] = energy[id1]
      end

  end

end

function effective_field(exch::HeisenbergExchange, sim::AtomicSim, spin::Array{Float64, 1}, t::Float64)
  ngbs = sim.mesh.ngbs
  nxyz = sim.nxyz
  field = exch.field
  energy = exch.energy
  mu_s = sim.mu_s

  Threads.@threads for i = 1:nxyz
    if mu_s[i] == 0.0
      #we already set energy and  field to zero
      continue
    end
    fx, fy, fz = 0.0, 0.0, 0.0
    for j=1:6
      id = ngbs[j,i]
      if id>0 && mu_s[id]>0
        k = 3*(id-1)
        fx += exch.J*spin[k+1]
        fy += exch.J*spin[k+2]
        fz += exch.J*spin[k+3]
      end
    end
    mu_s_inv = 1.0/(mu_s[i])
    energy[i] = -0.5*(fx*spin[3*i-2] + fy*spin[3*i-1] + fz*spin[3*i])
    field[3*i-2] = fx*mu_s_inv
    field[3*i-1] = fy*mu_s_inv
    field[3*i] = fz*mu_s_inv
  end
end

function effective_field(dmi::BulkDMI, sim::AtomicSim, spin::Array{Float64, 1}, t::Float64)
  ngbs = sim.mesh.ngbs
  nxyz = sim.nxyz
  field = dmi.field
  energy = dmi.energy
  mu_s = sim.mu_s
  ax = (1.0,-1.0, 0.0, 0.0, 0.0, 0.0)
  ay = (0.0, 0.0, 1.0,-1.0, 0.0, 0.0)
  az = (0.0, 0.0, 0.0, 0.0, 1.0,-1.0)

  Threads.@threads for i = 1:nxyz
    if mu_s[i] == 0.0
      continue
    end
    fx = 0.0
    fy = 0.0
    fz = 0.0

    for j = 1:6
      id = ngbs[j,i]
      if id>0 && mu_s[id]>0
        k = 3*(id-1)+1
        fx += dmi.D*cross_x(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
        fy += dmi.D*cross_y(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
        fz += dmi.D*cross_z(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
      end
    end

    mu_s_inv = 1.0/(mu_s[i])
    energy[i] = -0.5*(fx*spin[3*i-2] + fy*spin[3*i-1] + fz*spin[3*i])
    field[3*i-2] = fx*mu_s_inv
    field[3*i-1] = fy*mu_s_inv
    field[3*i] = fz*mu_s_inv
  end
end

function effective_field(dmi::BulkDMI, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4*pi*1e-7
  mesh = sim.mesh
  dx = mesh.dx
  dy = mesh.dy
  dz = mesh.dz
  ngbs = mesh.ngbs
  nxyz = sim.nxyz
  field = dmi.field
  energy = dmi.energy
  Ms = sim.Ms
  Dx, Dy, Dz = dmi.Dx, dmi.Dy, dmi.Dz
  Ds = (Dx/dx, Dx/dx, Dy/dy, Dy/dy, Dz/dz, Dz/dz)
  ax = (1.0,-1.0, 0.0, 0.0, 0.0, 0.0)
  ay = (0.0, 0.0, 1.0,-1.0, 0.0, 0.0)
  az = (0.0, 0.0, 0.0, 0.0, 1.0,-1.0)

  Threads.@threads for i = 1:nxyz
    if Ms[i] == 0.0
      energy[i] = 0.0
      field[3*i-2] = 0.0
      field[3*i-1] = 0.0
      field[3*i] = 0.0
      continue
    end
    fx = 0.0
    fy = 0.0
    fz = 0.0

    for j = 1:6
      id = ngbs[j,i]
      if id>0 && Ms[id]>0
        k = 3*(id-1)+1
        fx += Ds[j]*cross_x(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
        fy += Ds[j]*cross_y(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
        fz += Ds[j]*cross_z(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
      end
    end

    Ms_inv = 1.0/(Ms[i]*mu0)
    energy[i] = -0.5*(fx*spin[3*i-2] + fy*spin[3*i-1] + fz*spin[3*i])*mesh.volume
    field[3*i-2] = fx*Ms_inv
    field[3*i-1] = fy*Ms_inv
    field[3*i] = fz*Ms_inv
  end
end


function effective_field(dmi::InterfacialDMI, sim::MicroSim, spin::Array{Float64, 1}, t::Float64)
  mu0 = 4*pi*1e-7
  mesh = sim.mesh
  dx = mesh.dx
  dy = mesh.dy
  dz = mesh.dz
  ngbs = mesh.ngbs
  nxyz = sim.nxyz
  field = dmi.field
  energy = dmi.energy
  Ms = sim.Ms
  D = dmi.D
  Ds = (D/dx, D/dx, D/dy, D/dy)
  ax = (0.0, 0.0, -1.0, 1.0) #Dij = D r_ij x z
  ay = (1.0,-1.0, 0.0, 0.0)
  az = (0.0, 0.0, 0.0, 0.0)

  Threads.@threads for i = 1:nxyz
    if Ms[i] == 0.0
      energy[i] = 0.0
      field[3*i-2] = 0.0
      field[3*i-1] = 0.0
      field[3*i] = 0.0
      continue
    end
    fx = 0.0
    fy = 0.0
    fz = 0.0

    for j = 1:4
      id = ngbs[j,i]
      if id>0 && Ms[id]>0
        k = 3*(id-1)+1
        fx += Ds[j]*cross_x(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
        fy += Ds[j]*cross_y(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
        fz += Ds[j]*cross_z(ax[j],ay[j],az[j],spin[k],spin[k+1],spin[k+2]);
      end
    end

    Ms_inv = 1.0/(Ms[i]*mu0)
    energy[i] = -0.5*(fx*spin[3*i-2] + fy*spin[3*i-1] + fz*spin[3*i])*mesh.volume
    field[3*i-2] = fx*Ms_inv
    field[3*i-1] = fy*Ms_inv
    field[3*i] = fz*Ms_inv
  end
end


function effective_field(sim::AbstractSim, spin::Array{Float64, 1}, t::Float64)
  fill!(sim.field, 0.0)
  fill!(sim.energy, 0.0)
  for interaction in sim.interactions
    effective_field(interaction, sim, spin, t)
    sim.field .+= interaction.field
    sim.energy .+= interaction.energy
  end
  return 0
end

function compute_system_energy(sim::AbstractSim, spin::Array{Float64, 1}, t::Float64)
  #sim.total_energy = 0
  fill!(sim.energy, 0.0)
  for interaction in sim.interactions
    effective_field(interaction, sim, spin, t)
	sim.energy .+= interaction.energy
  end
  return 0
end
