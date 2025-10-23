function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:WellDef})
    @assert x.keyword == "WellDef"
    wname = x.value
    well = Dict{String, Any}(
        "WellName" => wname,
        "WellToCellConnections" => Dict{String, Any}(),
        "Functions" => Any[]
    )
    for rec in x.body
        kw = rec.keyword
        if kw == "WellToCellConnections"
            set_ix_array_values!(well[kw], rec)
        elseif rec isa IXFunctionCall
            push!(well["Functions"], rec)
        elseif rec isa IXEqualRecord
            well[kw] = rec.value
        else
            # No idea...
            well[kw] = rec
        end
    end
    for (k, v) in pairs(well)
        if k == "WellToCellConnections"
            well[k] = convert_ix_values!(v, k, unit_systems; throw = false)
        elseif k in ("WellName", "Undefined", "ResVolConditions", "Functions", "PseudoPressureModel", "AllowCrossFlow", "HeadDensityCalculation")
            # Do nothing
        else
            log_unhandled!(meta, k)
        end
    end
    return well
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:Separator})
    return convert_ix_record_and_subrecords(x, unit_systems, meta)
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:SeparatorStage})
    out = convert_ix_record_to_dict(x, unit_systems)
    return out
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Union{Val{:Group}, Val{:StaticList}})
    group_name = x.value
    members = Tuple{String, String}[]
    mem_type = "Group"
    for rec in x.body
        mem_type = rec.keyword
        length(rec.value) % 2 == 0 || error("Expected even number of elements in Group/StaticList record, got $(length(rec.value))")
        recvals = reshape(rec.value, 2, :)
        for i in axes(recvals, 2)
            group_type, group_members = recvals[:, i]
            for v in group_members
                push!(members, (group_type, v))
            end
        end
    end
    return (group = group_name, members = members, type = mem_type)
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:Well})
    out = Dict{String, Any}(
        "name" => x.value,
    )
    for rec in x.body
        kw = rec.keyword
        if rec isa IXEqualRecord
            val = rec.value
            if val isa IXKeyword
                val = String(val)
            elseif val isa AbstractIXRecord || val isa AbstractArray
                val = convert_ix_record(val, unit_systems, meta, kw)
            elseif val isa Number
                val = convert_ix_value(val, kw, unit_systems; throw = false)
            end
        elseif rec isa IXFunctionCall
            val = convert_function_call(rec, unit_systems, "Well")
        elseif rec isa IXStandardRecord
            val = convert_ix_record(rec, unit_systems, meta, kw)
        elseif rec isa IXAssignmentRecord
            asgn = rec.value
            asgn = convert_ix_value(asgn, rec.index, unit_systems; throw = false)
            val = IXAssignmentRecord(rec.keyword, rec.index, asgn)
        else
            error("Expected IXEqualRecord in Well record body, got $(typeof(rec))")
        end
        out[kw] = val
    end
    return out
end

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:Well})
    header, mat = reshape_ix_matrix(x.value)
    name_ix = findfirst(x -> isequal("name", lowercase(x)), header)
    if isnothing(name_ix)
        error("Expected 'Name' column in Well record, got: $(header)")
    end
    eachunit = Symbol[]
    for h in header
        u = get_unit_type_ix_keyword(unit_systems, h; throw = false)
        push!(eachunit, u)
    end
    swap_unit_system_axes!(mat, unit_systems, eachunit)
    out = Dict{String, Any}()
    for rowno in axes(mat, 1)
        name = mat[rowno, name_ix]
        if !haskey(out, name)
            out[name] = Dict{String, Any}()
        end
        for (colno, colname) in enumerate(header)
            if colno == name_ix
                continue
            end
            if haskey(out[name], colname)
                println("Well '$name' column '$colname':\n   Duplicate entry in Well record, overwriting previous value: $(out[name][colname]) with $(mat[rowno, colno])")
            end
            out[name][colname] = mat[rowno, colno]
        end
    end
    return out
end

# function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Union{Val{:Constraints}, Val{:HistoricalData}})
#     constraints = Dict{String, Any}()
#     # @info "???" x.value
#     return x
#     if length(x.value) > 0
#         verb = String(x.value[1])
#         for k in x.value[2:end]
#             constraint_value, constraint_name = k
#             constraint_name = String(constraint_name)
#             u = get_unit_type_ix_keyword(unit_systems, constraint_name; throw = false)
#             constraints[constraint_name] = swap_unit_system(constraint_value, unit_systems, u)
#         end
#         out = (verb = verb, constraints = constraints)
#     else
#         out = missing
#     end
#     return out
# end

function convert_ix_record(x::AbstractArray, unit_systems, meta, ::Union{Val{:Constraints}, Val{:HistoricalData}})
    constraints = OrderedDict{String, Any}()
    function set_constraint!(constraint_name, constraint_value)
        u = get_unit_type_ix_keyword(unit_systems, constraint_name; throw = false)
        constraints[constraint_name] = swap_unit_system(constraint_value, unit_systems, u)
    end
    if length(x) > 0
        if any(x -> x isa IXArrayEndline, x)
            verb  = "ADD"
            header, data = reshape_ix_matrix(x)
            is_data = findfirst(x -> isequal("data", lowercase(x)), header)
            is_prop = findfirst(x -> isequal("property", lowercase(x)), header)
            if isnothing(is_data) || isnothing(is_prop)
                error("Expected 'data' and 'property' columns in Constraints/HistoricalData record, found: $(header)")
            end
            for row in axes(data, 1)
                constraint_value = data[row, is_data]
                constraint_name = String(data[row, is_prop])
                set_constraint!(constraint_name, constraint_value)
            end
        else
            if x[1] isa IXKeyword
                verb = String(x[1])
                remainder = x[2:end]
            else
                verb = "ADD"
                remainder = x
            end
            for k in remainder
                constraint_value, constraint_name = k
                constraint_name = String(constraint_name)
                set_constraint!(constraint_name, constraint_value)
            end
        end
        out = (verb = verb, constraints = constraints)
    else
        out = missing
    end
    return out
end
