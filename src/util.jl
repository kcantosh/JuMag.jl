@inline function cross_x(x1::T, x2::T, x3::T, y1::T, y2::T, y3::T) where {T<:AbstractFloat}
    return -x3*y2 + x2*y3
end

@inline function cross_y(x1::T, x2::T, x3::T, y1::T, y2::T, y3::T) where {T<:AbstractFloat}
    return x3*y1 - x1*y3
end

@inline function cross_z(x1::T, x2::T, x3::T, y1::T, y2::T, y3::T) where {T<:AbstractFloat}
    return -x2*y1 + x1*y2
end

@inline function cross_product(x1::T, x2::T, x3::T, y1::T, y2::T, y3::T) where {T<:AbstractFloat}
    return (-x3*y2 + x2*y3, x3*y1 - x1*y3, -x2*y1 + x1*y2)
end

@inline function cross_product(x::Tuple{Number, Number, Number}, y::Tuple{Number, Number, Number})
    return (-x[3]*y[2] + x[2]*y[3], x[3]*y[1] - x[1]*y[3], -x[2]*y[1] + x[1]*y[2])
end

#compute a.(bxc) = b.(cxa) = c.(axb)
@inline function volume(Sx::T, Sy::T, Sz::T, Six::T, Siy::T, Siz::T, Sjx::T, Sjy::T, Sjz::T) where {T<:AbstractFloat}
    tx = Sx * (-Siz * Sjy + Siy * Sjz);
    ty = Sy * (Siz * Sjx - Six * Sjz);
    tz = Sz * (-Siy * Sjx + Six * Sjy);
    return tx + ty + tz;
end

#compute the angle defined in equation (1) in paper [PRB 93, 174403 (2016)] or equation (3) in [New J. Phys. 20 (2018) 103014]
@inline function Berg_Omega(ux::T, uy::T, uz::T, vx::T, vy::T, vz::T, wx::T, wy::T, wz::T) where {T<:AbstractFloat}
    b = volume(ux, uy, uz, vx, vy, vz, wx, wy, wz)
    a = 1.0 + (ux*vx + uy*vy + uz*vz) + (ux*wx + uy*wy + uz*wz) + (vx*wx + vy*wy + vz*wz)
    return 2*atan(b, a)
end

function abs!(a::Array{T,1}, b::Array{T,1})  where {T<:AbstractFloat}
    a .= abs.(b)
    return nothing
end

function abs!(a::Array{T,1})  where {T<:AbstractFloat}
    for i in 1:length(a)
        if a[i] < 0
            @inbounds a[i] = -a[i]
        end
    end
    return nothing
end

#The frequency of discrete FFT
#f = [0, 1, ...,   N/2-1,     -N/2, ..., -1] / (d*N)   if n is even
#f = [0, 1, ..., (N-1)/2, -(N-1)/2, ..., -1] / (d*N)   if n is odd
#where d is the data interval.
function fftfreq(N; d=1)
    f = zeros(Float64, N)
    n = ceil(Int, N/2)
    for i = 1:n
        f[i] = (i-1)/(d*N)
    end
    for i = n+1:N
        f[i] = (i-1-N)/(d*N)
    end
    return f
end
