struct IntentTree{T<:Intent}
    data::T
    parent::Union{Nothing,IntentTree{T}}
    children::Vector{IntentTree{T}}

    IntentTree{T}(data, ::Nothing, v::AbstractVector{IntentTree{T}}) where T = new{T}(data, nothing, v)
    function IntentTree{T}(d::T, p::IntentTree{T}, c::AbstractVector{IntentTree{T}}) where T
        ret = new{T}(d, p, c)
        push!(p.children , ret)
        ret
    end
end
src(it::IntentTree) = src(it.data)
dst(it::IntentTree) = dst(it.data)
constraints(it::IntentTree) = constraints(it.data)
compilation(it::IntentTree) = compilation(it.data)
setcompilation!(it::IntentTree, ic::T) where {T<:Union{IntentCompilation, Missing}} = setcompilation!(it.data, ic)
state(it::IntentTree) = state(it.data)
setstate!(it::IntentTree, is::IntentState) = setstate!(it.data, is)

IntentTree(d::T, p=nothing, c=IntentTree{T}[]) where T = IntentTree{T}(d, p, c)

function addchild!(parent::IntentTree{T}, data::T) where {T}
  IntentTree(data, parent)
end
#
# specialize function as instructed in AbstractTrees examples docu
#
Base.show(io::IO, t::IntentTree{T}) where T = print(io, "IntentTree{$(T)}(", t.data, ')')
AbstractTrees.printnode(io::IO, node::IntentTree) = print(io, node.data)
AbstractTrees.children(node::IntentTree) = node.children
AbstractTrees.parent(node::IntentTree) = node.parent
AbstractTrees.isroot(node::IntentTree) = parent(node) === nothing

isleaf(node::IntentTree) = length(node.children) == 0 

AbstractTrees.parentlinks(::Type{IntentTree{T}}) where T = AbstractTrees.StoredParents()
AbstractTrees.siblinglinks(::Type{IntentTree{T}}) where T = AbstractTrees.StoredSiblings()

Base.parent(root::IntentTree, node::IntentTree) = isdefined(node, :parent) ? node.parent : nothing
## Implement iteration
Base.IteratorSize(::Type{IntentTree{T}}) where T = Base.SizeUnknown()
Base.eltype(::Type{<:TreeIterator{IntentTree{T}}}) where T = IntentTree{T}
Base.IteratorEltype(::Type{<:TreeIterator{IntentTree{T}}}) where T = Base.HasEltype()

struct TrackIterator{T}
    tree::T
end

function Base.iterate(node::IntentTree)
    !isleaf(node) ? (node.children[1], 1) : nothing
end

function Base.iterate(node::IntentTree, state::Int)
    state += 1
    state <= length(node.children) ? (node.children[state], state) : nothing
end

