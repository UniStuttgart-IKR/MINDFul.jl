abstract type Intent end
abstract type IntentConstraint end
abstract type IntentCompilation end
abstract type IntentCondition end

@enum IntentState installed uninstalled compiled uncompiled
@enum IntentTransition doinstall douninstall docompile douncompile

struct InheritIntentCompilation <: IntentCompilation end

struct IntentTree{T<:Intent}
    data::T
    parent::Union{Nothing,IntentTree}
    children::Vector{IntentTree}

    IntentTree{T}(data::T, ::Nothing, v::AbstractVector{IntentTree}) where T = new{T}(data, nothing, v)
    function IntentTree{T}(d::T, p::IntentTree, c::AbstractVector{IntentTree}) where T
        ret = new{T}(d, p, c)
        push!(p.children , ret)
        ret
    end
end
getsrc(it::IntentTree) = getsrc(it.data)
getdst(it::IntentTree) = getdst(it.data)
getconstraints(it::IntentTree) = getconstraints(it.data)
getcompilation(it::IntentTree) = getcompilation(it.data)
setcompilation!(it::IntentTree, ic::T) where {T<:Union{IntentCompilation, Missing}} = setcompilation!(it.data, ic)
getconditions(it::IntentTree) = getconditions(it.data)
getstate(it::IntentTree) = getstate(it.data)
setstate!(it::IntentTree, is::IntentState) = setstate!(it.data, is)

IntentTree(d::T, p=nothing, c=IntentTree[]) where {T<:Intent} = IntentTree{T}(d, p, c)

function addchild!(parent::IntentTree{T}, data::R) where {T <: Intent, R <: Intent}
  child = IntentTree(data, parent)
  setcompilation!(parent, InheritIntentCompilation())
  child
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

