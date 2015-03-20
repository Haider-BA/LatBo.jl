# Density at a given lattice site
density(fᵢ::Vector) = sum(fᵢ)
# Momentum at given site
momentum(fᵢ::Vector, cᵢ::Matrix) = vec(sum(cᵢ .* transpose(fᵢ), 2))
# Velocities at a given lattice site
velocity(μ::Vector, ρ::Number) = μ / ρ
velocity(fᵢ::Vector, cᵢ::Matrix, ρ::Number) = velocity(momentum(fᵢ, cᵢ), ρ)
velocity(fᵢ::Vector, cᵢ::Matrix) = velocity(fᵢ, cᵢ, density(fᵢ))

#= Computes the equilibrium particle distributions $f^{eq}$:

    momentum: Macroscopic momentum μ at current lattice site
    celerities: d by n matrix of celerities ē for the lattice, with d the dimensionality of the
        lattice and n the number of particle distributions.
    weights: Weights associated with each celerity
    ρ: Density

    $f^{eq}$ = weights .* [ρ + 3ē⋅μ + \frac{9}{2ρ} (ē⋅μ)² - \frac{3}{2ρ} μ⋅μ]$
=#
function equilibrium{T, I}(ρ::T, momentum::Vector{T}, celerities::Matrix{I}, weights::Vector{T})
    # computes momentum projected on each particle celerity first
    @assert length(momentum) == size(celerities, 1)
    @assert length(weights) == size(celerities, 2)
    μ_on_ē = celerities.'momentum
    weights .* (
        ρ
        + 3μ_on_ē
        + 9/(2ρ) * (μ_on_ē .* μ_on_ē)
        - 3/(2ρ) * dot(momentum, momentum)
    )
end
equilibrium{T, I}(lattice::Lattice{T, I}, fᵢ::Vector{T}) =
    equilibrium(density(fᵢ), momentum(fᵢ, lattice.celerities), lattice.celerities, lattice.weights)

equilibrium{T}(lattice::Lattice, ρ::T, momentum::Vector{T}) =
    equilibrium(ρ, momentum, lattice.celerities, lattice.weights)
equilibrium{T}(lattice::Symbol, ρ::T, momentum::Vector{T}) =
    equilibrium(getfield(LB, lattice), ρ, momentum)

immutable type LocalQuantities{T <: FloatingPoint, I <: Int}
    from::GridCoords{I}
    density::T
    momentum::Vector{T}
    velocity::Vector{T}
    feq::Vector{T}

    function LocalQuantities(from::GridCoords{I}, fᵢ::Vector{T}, lattice::Lattice{T, I})
        const ρ = density(fᵢ)
        const μ = momentum(fᵢ, lattice.celerities)
        const ν = velocity(μ, ρ)
        const feq = equilibrium(ρ, μ, lattice.celerities, lattice.weights)
        new(from, ρ, μ, ν, feq)
    end
end

# Convenience calls to specify types as arguments
LocalQuantities{T <: FloatingPoint, I <: Integer}(::Type{T}, ::Type{I}, args...) =
    LocalQuantities{T, I}(args...)
function LocalQuantities(types::(Type, Type), args...)
    @assert types[1] <: FloatingPoint
    @assert types[2] <: Integer
    LocalQuantities(types..., args...)
end
