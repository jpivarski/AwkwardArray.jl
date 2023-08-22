# using JSON

module AwkwardArray

### Index ################################################################

const Index8 = AbstractVector{Int8}
const IndexU8 = AbstractVector{UInt8}
const Index32 = AbstractVector{Int32}
const IndexU32 = AbstractVector{UInt32}
const Index64 = AbstractVector{Int64}
const IndexBig = Union{Index32,IndexU32,Index64}

### Parameters ###########################################################

default = :default
char = :char
byte = :byte
string = :string
bytestring = :bytestring
categorical = :categorical
sorted_map = :sorted_map

struct Parameters
    string_valued::Base.ImmutableDict{String,String}
    any_valued::Base.ImmutableDict{String,Any}
end

Parameters() =
    Parameters(Base.ImmutableDict{String,String}(), Base.ImmutableDict{String,Any}())

function Parameters(pairs::Vararg{Pair{String,<:Any}})
    out = Parameters()
    for pair in pairs
        out = with_parameter(out, pair)
    end
    out
end

with_parameter(parameters::Parameters, pair::Pair{String,String}) =
    Parameters(Base.ImmutableDict(parameters.string_valued, pair), parameters.any_valued)

with_parameter(parameters::Parameters, pair::Pair{String,<:Any}) =
    Parameters(parameters.string_valued, Base.ImmutableDict(parameters.any_valued, pair))

has_parameter(parameters::Parameters, key::String) =
    if haskey(parameters.string_valued, key)
        true
    elseif haskey(parameters.any_valued, key)
        true
    else
        false
    end

get_parameter(parameters::Parameters, key::String) =
    if haskey(parameters.string_valued, key)
        parameters.string_valued[key]
    elseif haskey(parameters.any_valued, key)
        parameters.any_valued[key]
    else
        nothing
    end

function compatible(parameters1::Parameters, parameters2::Parameters)
    if get(parameters1.string_valued, "__array__", "") !=
       get(parameters2.string_valued, "__array__", "")
        return false
    end
    if get(parameters1.string_valued, "__list__", "") !=
       get(parameters2.string_valued, "__list__", "")
        return false
    end
    if get(parameters1.string_valued, "__record__", "") !=
       get(parameters2.string_valued, "__record__", "")
        return false
    end
    return true
end

Base.length(parameters::Parameters) =
    length(parameters.string_valued) + length(parameters.any_valued)

Base.keys(parameters::Parameters) =
    union(keys(parameters.any_valued), keys(parameters.string_valued))

Base.show(io::IO, parameters::Parameters) = print(
    io,
    "Parameters(" *
    join(
        [
            "$(repr(pair[1])) => $(repr(pair[2]))" for
            pair in merge(parameters.any_valued, parameters.string_valued)
        ],
        ", ",
    ) *
    ")",
)

### Content ##############################################################

struct Unset end

abstract type Content{BEHAVIOR} <: AbstractVector{ITEM where ITEM} end

has_parameter(content::CONTENT, key::String) where {CONTENT<:Content} =
    has_parameter(content.parameters, key)

get_parameter(content::CONTENT, key::String) where {CONTENT<:Content} =
    get_parameter(content.parameters, key)

function Base.iterate(layout::Content)
    start = firstindex(layout)
    stop = lastindex(layout)
    if stop >= start
        layout[start], start + 1
    else
        nothing
    end
end

function Base.iterate(layout::Content, state)
    stop = lastindex(layout)
    if stop >= state
        layout[state], state + 1
    else
        nothing
    end
end

Base.size(layout::Content) = (length(layout),)

### PrimitiveArray #######################################################

struct PrimitiveArray{ITEM,BUFFER<:AbstractVector{ITEM},BEHAVIOR} <: Content{BEHAVIOR}
    data::BUFFER
    parameters::Parameters
    PrimitiveArray(
        data::BUFFER;
        parameters::Parameters = Parameters(),
        behavior::Symbol = :default,
    ) where {ITEM,BUFFER<:AbstractVector{ITEM}} =
        new{ITEM,BUFFER,behavior}(data, parameters)
end

PrimitiveArray{ITEM}(;
    parameters::Parameters = Parameters(),
    behavior::Symbol = :default,
) where {ITEM} =
    PrimitiveArray(Vector{ITEM}([]), parameters = parameters, behavior = behavior)

function copy(
    layout::PrimitiveArray{ITEM,BUFFER,BEHAVIOR};
    data::Union{Unset,BUFFER} = Unset(),
    parameters::Union{Unset,Parameters} = Unset(),
    behavior::Union{Unset,Symbol} = Unset(),
) where {ITEM,BUFFER<:AbstractVector{ITEM},BEHAVIOR}
    if isa(data, Unset)
        data = layout.data
    end
    if isa(parameters, Unset)
        parameters = layout.parameters
    end
    if isa(behavior, Unset)
        behavior = typeof(layout).parameters[end]
    end
    PrimitiveArray(data, parameters = parameters, behavior = behavior)
end

is_valid(layout::PrimitiveArray) = true
Base.length(layout::PrimitiveArray) = length(layout.data)
Base.firstindex(layout::PrimitiveArray) = firstindex(layout.data)
Base.lastindex(layout::PrimitiveArray) = lastindex(layout.data)

Base.getindex(layout::PrimitiveArray, i::Int) = layout.data[i]

Base.getindex(layout::PrimitiveArray, r::UnitRange{Int}) = PrimitiveArray(
    layout.data[r],
    parameters = layout.parameters,
    behavior = typeof(layout).parameters[end],
)

function Base.:(==)(layout1::PrimitiveArray, layout2::PrimitiveArray)
    if !compatible(layout1.parameters, layout2.parameters)
        return false
    end
    layout1.data == layout2.data
end

function push!(layout::PrimitiveArray{ITEM}, x::ITEM) where {ITEM}
    Base.push!(layout.data, x)
    layout
end

### ListOffsetArray ######################################################

abstract type ListType{BEHAVIOR} <: Content{BEHAVIOR} end

struct ListOffsetArray{INDEX<:IndexBig,CONTENT<:Content,BEHAVIOR} <: ListType{BEHAVIOR}
    offsets::INDEX
    content::CONTENT
    parameters::Parameters
    ListOffsetArray(
        offsets::INDEX,
        content::CONTENT;
        parameters::Parameters = Parameters(),
        behavior::Symbol = :default,
    ) where {INDEX<:IndexBig,CONTENT<:Content} =
        new{INDEX,CONTENT,behavior}(offsets, content, parameters)
end

ListOffsetArray{INDEX,CONTENT}(;
    parameters::Parameters = Parameters(),
    behavior::Symbol = :default,
) where {INDEX<:IndexBig} where {CONTENT<:Content} =
    ListOffsetArray(INDEX([0]), CONTENT(), parameters = parameters, behavior = behavior)

function copy(
    layout::ListOffsetArray{INDEX,CONTENT,BEHAVIOR};
    offsets::Union{Unset,INDEX} = Unset(),
    content::Union{Unset,CONTENT} = Unset(),
    parameters::Union{Unset,Parameters} = Unset(),
    behavior::Union{Unset,Symbol} = Unset(),
) where {INDEX<:IndexBig,CONTENT<:Content,BEHAVIOR}
    if isa(offsets, Unset)
        offsets = layout.offsets
    end
    if isa(content, Unset)
        content = layout.content
    end
    if isa(parameters, Unset)
        parameters = layout.parameters
    end
    if isa(behavior, Unset)
        behavior = typeof(layout).parameters[end]
    end
    ListOffsetArray(offsets, content, parameters = parameters, behavior = behavior)
end

function is_valid(layout::ListOffsetArray)
    if length(layout.offsets) < 1
        return false
    end
    if layout.offsets[end] + firstindex(layout.content) - 1 > lastindex(layout.content)
        return false
    end
    for i in eachindex(layout)
        if layout.offsets[i] < 0 || layout.offsets[i+1] < layout.offsets[i]
            return false
        end
    end
    return is_valid(layout.content)
end

Base.length(layout::ListOffsetArray) = length(layout.offsets) - 1
Base.firstindex(layout::ListOffsetArray) = firstindex(layout.offsets)
Base.lastindex(layout::ListOffsetArray) = lastindex(layout.offsets) - 1

function Base.getindex(layout::ListOffsetArray, i::Int)
    start = layout.offsets[i] + firstindex(layout.content)
    stop = layout.offsets[i+1] + firstindex(layout.content) - 1
    layout.content[start:stop]
end

Base.getindex(layout::ListOffsetArray, r::UnitRange{Int}) = ListOffsetArray(
    layout.offsets[(r.start):(r.stop+1)],
    layout.content,
    parameters = layout.parameters,
    behavior = typeof(layout).parameters[end],
)

Base.getindex(layout::ListOffsetArray, f::Symbol) = ListOffsetArray(
    layout.offsets,
    layout.content[f],
    parameters = layout.parameters,
    behavior = typeof(layout).parameters[end],
)

function Base.:(==)(layout1::ListType, layout2::ListType)
    if length(layout1) != length(layout2)
        return false
    end
    if !compatible(layout1.parameters, layout2.parameters)
        return false
    end
    for (x, y) in zip(layout1, layout2)
        if x != y
            return false
        end
    end
    return true
end

function end_list!(layout::ListOffsetArray)
    Base.push!(layout.offsets, length(layout.content))
    layout
end

### ListArray ############################################################

struct ListArray{INDEX<:IndexBig,CONTENT<:Content,BEHAVIOR} <: ListType{BEHAVIOR}
    starts::INDEX
    stops::INDEX
    content::CONTENT
    parameters::Parameters
    ListArray(
        starts::INDEX,
        stops::INDEX,
        content::CONTENT;
        parameters::Parameters = Parameters(),
        behavior::Symbol = :default,
    ) where {INDEX<:IndexBig,CONTENT<:Content} =
        new{INDEX,CONTENT,behavior}(starts, stops, content, parameters)
end

ListArray{INDEX,CONTENT}(;
    parameters::Parameters = Parameters(),
    behavior::Symbol = :default,
) where {INDEX<:IndexBig} where {CONTENT<:Content} =
    ListArray(INDEX([]), INDEX([]), CONTENT(), parameters = parameters, behavior = behavior)

function copy(
    layout::ListArray{INDEX,CONTENT,BEHAVIOR};
    starts::Union{Unset,INDEX} = Unset(),
    stops::Union{Unset,INDEX} = Unset(),
    content::Union{Unset,CONTENT} = Unset(),
    parameters::Union{Unset,Parameters} = Unset(),
    behavior::Union{Unset,Symbol} = Unset(),
) where {INDEX<:IndexBig,CONTENT<:Content,BEHAVIOR}
    if isa(starts, Unset)
        starts = layout.starts
    end
    if isa(stops, Unset)
        stops = layout.starts
    end
    if isa(content, Unset)
        content = layout.content
    end
    if isa(parameters, Unset)
        parameters = layout.parameters
    end
    if isa(behavior, Unset)
        behavior = typeof(layout).parameters[end]
    end
    ListArray(starts, stops, content, parameters = parameters, behavior = behavior)
end

function is_valid(layout::ListArray)
    if length(layout.starts) < length(layout.stops)
        return false
    end
    for i in eachindex(layout)
        start = layout.starts[i]
        stop = layout.stops[i]
        if start != stop
            if start < 0 || start > stop || stop > length(layout.content)
                return false
            end
        end
    end
    return is_valid(layout.content)
end

Base.length(layout::ListArray) = length(layout.starts)
Base.firstindex(layout::ListArray) = firstindex(layout.starts)
Base.lastindex(layout::ListArray) = lastindex(layout.starts)

function Base.getindex(layout::ListArray, i::Int)
    adjustment = firstindex(layout.starts) - firstindex(layout.stops)
    start = layout.starts[i] + firstindex(layout.content)
    stop = layout.stops[i-adjustment] - layout.starts[i] + start - 1
    layout.content[start:stop]
end

function Base.getindex(layout::ListArray, r::UnitRange{Int})
    adjustment = firstindex(layout.starts) - firstindex(layout.stops)
    ListArray(
        layout.starts[r.start:r.stop],
        layout.stops[(r.start-adjustment):(r.stop-adjustment)],
        layout.content,
        parameters = layout.parameters,
        behavior = typeof(layout).parameters[end],
    )
end

Base.getindex(layout::ListArray, f::Symbol) = ListArray(
    layout.starts,
    layout.stops,
    layout.content[f],
    parameters = layout.parameters,
    behavior = typeof(layout).parameters[end],
)

function end_list!(layout::ListArray)
    if isempty(layout.stops)
        Base.push!(layout.starts, 0)
    else
        Base.push!(layout.starts, layout.stops[end])
    end
    Base.push!(layout.stops, length(layout.content))
end

### ListType with behavior = :string #####################################

function Base.getindex(
    layout::ListOffsetArray{INDEX,PrimitiveArray{UInt8,BUFFER,:char},:string},
    i::Int,
) where {INDEX<:IndexBig,BUFFER<:AbstractVector{UInt8}}
    String(
        getindex(
            ListOffsetArray(layout.offsets, PrimitiveArray(layout.content.data)),
            i,
        ).data,
    )
end

function Base.getindex(
    layout::ListArray{INDEX,PrimitiveArray{UInt8,BUFFER,:char},:string},
    i::Int,
) where {INDEX<:IndexBig,BUFFER<:AbstractVector{UInt8}}
    String(
        getindex(
            ListArray(layout.starts, layout.stops, PrimitiveArray(layout.content.data)),
            i,
        ).data,
    )
end

### ListType with behavior = :bytestring #################################

function Base.getindex(
    layout::ListOffsetArray{INDEX,PrimitiveArray{UInt8,BUFFER,:byte},:bytestring},
    i::Int,
) where {INDEX<:IndexBig,BUFFER<:AbstractVector{UInt8}}
    getindex(ListOffsetArray(layout.offsets, PrimitiveArray(layout.content.data)), i).data
end

function Base.getindex(
    layout::ListArray{INDEX,PrimitiveArray{UInt8,BUFFER,:byte},:bytestring},
    i::Int,
) where {INDEX<:IndexBig,BUFFER<:AbstractVector{UInt8}}
    getindex(
        ListArray(layout.starts, layout.stops, PrimitiveArray(layout.content.data)),
        i,
    ).data
end

### RecordArray ##########################################################

mutable struct RecordArray{CONTENTS<:NamedTuple,BEHAVIOR} <: Content{BEHAVIOR}
    const contents::CONTENTS
    length::Int64
    const parameters::Parameters
    RecordArray(
        contents::CONTENTS,
        length::Int64;
        parameters::Parameters = Parameters(),
        behavior::Symbol = :default,
    ) where {CONTENTS<:NamedTuple} = new{CONTENTS,behavior}(contents, length, parameters)
end

RecordArray(
    contents::CONTENTS;
    parameters::Parameters = Parameters(),
    behavior::Symbol = :default,
) where {CONTENTS<:NamedTuple} = RecordArray(
    contents,
    minimum(if length(contents) == 0
        0
    else
        [length(x) for x in contents]
    end),
    parameters = parameters,
    behavior = behavior,
)

struct Record{ARRAY<:RecordArray}
    array::ARRAY
    at::Int64
end

function copy(
    layout::RecordArray{CONTENTS,BEHAVIOR};
    contents::Union{Unset,CONTENTS} = Unset(),
    length::Union{Unset,Int64} = Unset(),
    parameters::Union{Unset,Parameters} = Unset(),
    behavior::Union{Unset,Symbol} = Unset(),
) where {CONTENTS<:NamedTuple,BEHAVIOR}
    if isa(contents, Unset)
        contents = layout.contents
    end
    if isa(length, Unset)
        length = layout.length
    end
    if isa(parameters, Unset)
        parameters = layout.parameters
    end
    if isa(behavior, Unset)
        behavior = typeof(layout).parameters[end]
    end
    RecordArray(contents, length, parameters = parameters, behavior = behavior)
end

function is_valid(layout::RecordArray)
    for x in values(layout.contents)
        if length(x) < layout.length
            return false
        end
        if !is_valid(x)
            return false
        end
    end
    return true
end

Base.length(layout::RecordArray) = layout.length
Base.firstindex(layout::RecordArray) = 1
Base.lastindex(layout::RecordArray) = layout.length

Base.getindex(layout::RecordArray, i::Int) = Record(layout, i)

Base.getindex(layout::RecordArray, r::UnitRange{Int}) =
    RecordArray{typeof(layout).parameters[end]}(
        NamedTuple{keys(layout.contents)}(
            Pair(k, v[r]) for (k, v) in pairs(layout.contents)
        ),
        min(r.stop, layout.length) - max(r.start, 1) + 1,   # unnecessary min/max
        layout.parameters,
    )

function Base.getindex(layout::RecordArray, f::Symbol)
    content = layout.contents[f]
    content[firstindex(content):firstindex(content)+length(layout)-1]
end

Base.getindex(layout::Record, f::Symbol) = layout.array.contents[f][layout.at]

function Base.:(==)(
    layout1::RecordArray{CONTENTS},
    layout2::RecordArray{CONTENTS},
) where {CONTENTS<:NamedTuple}
    if length(layout1) != length(layout2)
        return false
    end
    if !compatible(layout1.parameters, layout2.parameters)
        return false
    end
    for k in keys(layout1.contents)   # same keys because same CONTENTS type
        if layout1[k] != layout2[k]   # compare whole arrays
            return false
        end
    end
    return true
end

function Base.:(==)(
    layout1::Record{ARRAY},
    layout2::Record{ARRAY},
) where {CONTENTS<:NamedTuple,ARRAY<:RecordArray{CONTENTS}}
    if !compatible(layout1.array.parameters, layout2.array.parameters)
        return false
    end
    for k in keys(layout1.array.contents)   # same keys because same CONTENTS type
        if layout1[k] != layout2[k]         # compare record items
            return false
        end
    end
    return true
end

function end_record!(layout::RecordArray)
    layout.length += 1
    @assert all(length(x) >= layout.length for x in layout.contents)
    layout
end

end
