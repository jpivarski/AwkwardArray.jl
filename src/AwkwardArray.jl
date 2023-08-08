module AwkwardArray

abstract type Content <: AbstractArray{undef,1} end

function Base.iterate(x::Content)
    start = firstindex(x)
    stop = lastindex(x)
    if stop >= start
        x[start], start + 1
    else
        nothing
    end
end

function Base.iterate(x::Content, state)
    stop = lastindex(x)
    if stop >= state
        x[state], state + 1
    else
        nothing
    end
end

function Base.size(x::Content)
    (length(x),)
end

### PrimitiveArray #######################################################

struct PrimitiveArray{T} <: Content
    data::AbstractArray{T,1}
end

function is_valid(x::PrimitiveArray)
    true
end

function Base.length(x::PrimitiveArray)
    length(x.data)
end

function Base.firstindex(x::PrimitiveArray)
    firstindex(x.data)
end

function Base.lastindex(x::PrimitiveArray)
    lastindex(x.data)
end

function Base.getindex(x::PrimitiveArray, i::Int)
    x.data[i]
end

function Base.getindex(x::PrimitiveArray, r::UnitRange{Int})
    PrimitiveArray(x.data[r])
end

function Base.:(==)(x::PrimitiveArray, y::PrimitiveArray)
    x.data == y.data
end

### ListOffsetArray ######################################################

struct ListOffsetArray{T<:Union{Int32,UInt32,Int64}} <: Content
    offsets::AbstractArray{T,1}
    content::Content
end

function is_valid(x::ListOffsetArray)
    if length(x.offsets) < 1
        return false
    end
    if x.offsets[end] + firstindex(x.content) - 1 > lastindex(x.content)
        return false
    end
    for i in eachindex(x)
        if x.offsets[i] < 0 || x.offsets[i+1] < x.offsets[i]
            return false
        end
    end
    return true
end

function Base.length(x::ListOffsetArray)
    length(x.offsets) - 1
end

function Base.firstindex(x::ListOffsetArray)
    firstindex(x.offsets)
end

function Base.lastindex(x::ListOffsetArray)
    lastindex(x.offsets) - 1
end

function Base.getindex(x::ListOffsetArray, i::Int)
    start = x.offsets[i] + firstindex(x.content)
    stop = x.offsets[i+1] + firstindex(x.content) - 1
    x.content[start:stop]
end

function Base.getindex(x::ListOffsetArray, r::UnitRange{Int})
    ListOffsetArray(x.offsets[(r.start):(r.stop+1)], x.content)
end

function Base.:(==)(x::ListOffsetArray, y::ListOffsetArray)
    if length(x) != length(y)
        return false
    else
        for (xi, yi) in zip(x, y)
            if xi != yi
                return false
            end
        end
        return true
    end
end

end
