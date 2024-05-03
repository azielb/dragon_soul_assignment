-- Configuration
-- The suffixes for abbreviation in every power of thousands.
local COMPACT_SUFFIX = {
    "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "De", "UDe", "DDe", "TDe",
    "QdDe", "QnDe", "SxDe", "SpDe", "OcDe", "NoDe", "Vg", "UVg", "DVg", "TVg", "QdVg",
    "QnVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg", "UTg", "DTg", "TTg", "QdTg", "QnTg",
    "SxTg", "SpTg", "OcTg", "NoTg", "Qdg", "UQdg", "DQdg", "TQdg", "QdQdg", "QnQdg",
    "SxQdg", "SpQdg", "OcQdg", "NoQdg", "Qig", "UQig", "DQig", "TQig", "QgQig",
    "QnQig", "SxQig", "SpQig", "OcQig", "NoQig", "Sxg", "USxg", "DSxg",
    "TSxg", "QdSxg", "QnSxg", "SxSxg", "SpSxg", "OcSxg", "NoSxg",
    "Spg", "USpg", "DSpgL", "TSpg", "QdSpg", "QnSpg", "SxSpg",
    "SpSpg", "OcSpg", "NoSpg", "Ocg", "UOcg", "DOcg", "TOcg", "QdOcg",
    "QnOcg", "SxOcg", "SpOcg", "OcOcg", "NoOcg", "Nog", "UNog", "DNog",
    "TNog", "QdNog", "QnNog", "SxNog", "SpNog", "OcNog", "NoNog", "CNT", "UCNT",
}
local CACHED_SKELETON_SETTINGS = true
--

local MainAPI = require(script.Parent.Main)
local FormatNumberSimpleAPI = { }

local SKELETON_CACHE = if CACHED_SKELETON_SETTINGS then { } else nil
local COMPACT_SKELETON_CACHE = if CACHED_SKELETON_SETTINGS then { } else nil

function FormatNumberSimpleAPI.Format(value: number, skeleton: string?): string
    local success
    local formatter = nil

    assert(type(value) == "number", "Value provided must be a number")

    if skeleton == nil then
        skeleton = ""
    end
    assert(type(skeleton) == "string", "Skeleton provided must be a string")

    if CACHED_SKELETON_SETTINGS then
        formatter = SKELETON_CACHE[skeleton]
    end

    if not formatter then
        success, formatter =
            MainAPI.NumberFormatter.forSkeleton(skeleton)
        assert(success, formatter :: string)

        if CACHED_SKELETON_SETTINGS then
            SKELETON_CACHE[skeleton] = formatter
        end
    end

    return (formatter :: MainAPI.NumberFormatter):Format(value)
end

function FormatNumberSimpleAPI.FormatCompact(value: number, skeleton: string?): string
    local success
    local formatter = nil

    assert(type(value) == "number", "Value provided must be a number")

    if skeleton == nil then
        skeleton = ""
    end
    assert(type(skeleton) == "string", "Skeleton provided must be a string")

    if CACHED_SKELETON_SETTINGS then
        formatter = COMPACT_SKELETON_CACHE[skeleton]
    end

    if not formatter then
        success, formatter =
            MainAPI.NumberFormatter.forSkeleton(skeleton)
        assert(success, formatter :: string)

        formatter = (formatter :: MainAPI.NumberFormatter)
            :Notation(MainAPI.Notation.compactWithSuffixThousands(COMPACT_SUFFIX))

        if CACHED_SKELETON_SETTINGS then
            COMPACT_SKELETON_CACHE[skeleton] = formatter
        end
    end

    assert(#COMPACT_SUFFIX ~= 0, "Please provide the suffix abbreviations for FormatCompact at the top of the Simple ModuleScript")

    return formatter:Format(value)
end

return table.freeze(FormatNumberSimpleAPI)