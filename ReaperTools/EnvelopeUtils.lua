-- EnvelopeUtils.lua

EnvelopeUtils = {}

-- csv_to_env関数の定義
function EnvelopeUtils.csv_to_env(envFunc, azimuth, elevation, distance)
    if envFunc == "azimuth" then
        return azimuth
    elseif envFunc == "elevation" then
        return elevation
    elseif envFunc == "dist2verb" then
        return 0.02 + math.min(1.0 , 0.8 * distance)
    elseif envFunc == "dist2gain" then
        return 0.5 * math.min(1.0, 1.1 - 0.9 * distance)
    elseif envFunc == "dist2gain2Mix" then
        return 0.5 * math.min(1.0, 1.0 - 1.0 * distance)
    end
    return nil
end 

-- エンベロープのクリア関数
function EnvelopeUtils.clear_envelope(envelope)
    local num_points = reaper.CountEnvelopePoints(envelope)
    for i = num_points - 1, 0, -1 do
        reaper.DeleteEnvelopePointEx(envelope, -1, i)
    end
end

-- エンベロープのポイント取得関数
function EnvelopeUtils.get_envelope_points(envelope)
    local points = {}
    local num_points = reaper.CountEnvelopePoints(envelope)
    for i = 0, num_points - 1 do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
        table.insert(points, {time = time, value = value})
    end
    return points
end

-- エンベロープにCSVからポイントを挿入する関数
function EnvelopeUtils.insert_points_from_csv(envelope, csv_points, envFunc)
    for _, point in ipairs(csv_points) do
        local value = EnvelopeUtils.csv_to_env(envFunc, point.azimuth, point.elevation, point.distance)
        if value then
            reaper.InsertEnvelopePoint(envelope, point.time, value, 0, 0, false, true)
        end
    end
    reaper.Envelope_SortPoints(envelope)
end

-- 差分が0.8を超える場合にポイントを追加する関数
function EnvelopeUtils.add_discrete_points(envelope, points)
    table.sort(points, function(a, b) return a.time < b.time end)
    for i = 1, #points - 1 do
        local current_point = points[i]
        local next_point = points[i + 1]
        local value_diff = math.abs(next_point.value - current_point.value)
        if value_diff > 0.8 then
            local new_time = current_point.time
            local new_value = 1 - current_point.value
            reaper.InsertEnvelopePoint(envelope, new_time, new_value, 0, 0, false, true)
        end
    end
    reaper.Envelope_SortPoints(envelope)
end

-- トラックを名前で取得する関数
function EnvelopeUtils.get_track_by_name(track_name)
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local retval, name = reaper.GetTrackName(track, "")
        if name == track_name then
            return track
        end
    end
    return nil
end

return EnvelopeUtils
