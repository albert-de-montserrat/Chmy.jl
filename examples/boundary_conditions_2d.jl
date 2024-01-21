using Chmy, Chmy.Grids, Chmy.Fields, Chmy.BoundaryConditions, Chmy.GridOperators
using KernelAbstractions
using GLMakie

@kernel inbounds = true function compute_q!(q, C, χ, g::StructuredGrid)
    I = @index(Global, NTuple)
    q.x[I...] = -χ * ∂x(C, g, I...)
    q.y[I...] = -χ * ∂y(C, g, I...)
end

@kernel inbounds = true function update_C!(C, q, Δt, g::StructuredGrid)
    I = @index(Global, NTuple)
    C[I...] -= Δt * divg(q, g, I...)
end

@views function main()
    # geometry
    grid = UniformGrid(; origin=(0, 0), extent=(1, 1), dims=(510, 510))
    # physics
    χ = 1.0
    # numerics
    Δt = minimum(spacing(grid, Center(), 1, 1))^2 / χ / ndims(grid) / 2.1
    # allocate fields
    C = Field(CPU(), grid, Center())
    q = VectorField(CPU(), grid)
    # initial conditions
    set!(C, grid, (_, _) -> rand())
    bc!(grid, C => Neumann())
    # boundary conditions
    bc = (q.x => (x=Dirichlet(),),
          q.y => (y=Dirichlet(),))

    # visualisation
    fig = Figure(; size=(400, 350))
    ax  = Axis(fig[1, 1][1, 1]; aspect=DataAspect(), xlabel="x", ylabel="y", title="it = 0")
    plt = heatmap!(ax, coords(grid, Center())..., interior(C); colormap=:turbo)
    Colorbar(fig[1, 1][1, 2], plt)
    display(fig)
    # action
    @time begin
        for it in 1:1000
            compute_q!(CPU(), 256, size(grid, Vertex()))(q, C, χ, grid)
            bc!(grid, bc...)
            update_C!(CPU(), 256, size(grid, Center()))(C, q, Δt, grid)
            # bc!(grid, C => Neumann())
        end
    end
    plt[3] = interior(C)
    # ax.title = "it = $it"
    yield()
    return
end

main()
