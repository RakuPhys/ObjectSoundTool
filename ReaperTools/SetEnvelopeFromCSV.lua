-- csvdirの定義
local csvdir = "C:\\your path CSV files\\"
local clipdir = "C:\\your path to clip files (if you use use_score=True)\\"
-- EnvelopeUtils.luaのインポート
package.path = package.path .. ";C:\\your path to ReaScript Files\\?.lua"
local EnvelopeUtils = require("EnvelopeUtils")
-- スコア関連の変数を定義
local useScore = false
local sourceNum = 1

-- テンプレートトラックをコピーする関数
function copy_template_if_needed(objectName, trackType)
    local track_name = trackType .. "_" .. objectName
    local track = EnvelopeUtils.get_track_by_name(track_name)
    if not track then
        -- テンプレートからトラックをコピー
        copy_template_track(objectName)
    end
end

-- テンプレートトラックをコピーする関数
function copy_template_track(objectName)
    -- テンプレートフォルダを取得
    local template_folder = EnvelopeUtils.get_track_by_name("Template")
    if not template_folder then
        reaper.ShowMessageBox("テンプレートフォルダが見つかりません。", "エラー", 0)
        return
    end

    -- テンプレートフォルダをコピー
    reaper.SetOnlyTrackSelected(template_folder)
    reaper.Main_OnCommand(40062, 0) -- Copy tracks
    reaper.Main_OnCommand(40058, 0) -- Paste tracks
    local new_template_folder = reaper.GetSelectedTrack(0, 0)
    reaper.GetSetMediaTrackInfo_String(new_template_folder, "P_NAME", objectName, true)

    -- フォルダ内のトラック数を取得
    local track_index = reaper.GetMediaTrackInfo_Value(new_template_folder, "IP_TRACKNUMBER") - 1
    -- フォルダ内のトラック名を置換
    for i = 0, 2 do
        local child_track = reaper.GetTrack(0, track_index + 1 + i)
        local retval, child_name = reaper.GetTrackName(child_track, "")
        local new_child_name = string.gsub(child_name, "Template", objectName)
        reaper.GetSetMediaTrackInfo_String(child_track, "P_NAME", new_child_name, true)
    end
end

-- 指定のトラックの指定の秒数に指定のパスのオーディオファイル（wav）を配置する関数
function place_audio_file(track, start_time, file_path, volume)
    reaper.ShowConsoleMsg(file_path)
    -- メディアアイテムをトラックに追加
    local item = reaper.AddMediaItemToTrack(track)
    if not item then
        reaper.ShowMessageBox("メディアアイテムをトラックに追加できませんでした。", "エラー", 0)
        return
    end

    -- メディアアイテムの位置を設定
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", start_time)

    -- テイクを追加し、オーディオファイルを設定
    local take = reaper.AddTakeToMediaItem(item)
    if not take then
        reaper.ShowMessageBox("メディアアイテムにテイクを追加できませんでした。", "エラー", 0)
        return
    end
    
    local pcm_source = reaper.PCM_Source_CreateFromFile(file_path)
    if not pcm_source then
        reaper.ShowMessageBox("オーディオファイルを開けませんでした: " .. file_path, "エラー", 0)
        return
    end

    reaper.SetMediaItemTake_Source(take, pcm_source)

    -- クリップの長さを設定
    local length = reaper.GetMediaSourceLength(pcm_source)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
    reaper.UpdateItemInProject(item)

    -- 音量をdBで設定
    local volume_linear = 10^(volume / 20)
    reaper.SetMediaItemTakeInfo_Value(take, "D_VOL", volume_linear)
end


function process_sourcepos_csv_line(objectName, trackType, envName, envFunc, loadScore)
    -- CSVファイルのパスを取得
    local csv_file_path = csvdir .. "SourcePos\\" .. objectName .. ".csv"
    
    -- トラックを取得
    local track_name = trackType .. "_" .. objectName
    local track = EnvelopeUtils.get_track_by_name(track_name)
    if not track then
        reaper.ShowMessageBox("トラック " .. track_name .. " が見つかりません。", "エラー", 0)
        return
    end

    -- エンベロープを取得
    local envelope = nil
    for i = 0, reaper.CountTrackEnvelopes(track) - 1 do
        local env = reaper.GetTrackEnvelope(track, i)
        local retval, env_name = reaper.GetEnvelopeName(env, "")
        if env_name == envName then
            envelope = env
            break
        end
    end

    if not envelope then
        reaper.ShowMessageBox("エンベロープ " .. envName .. " が見つかりません。", "エラー", 0)
        return
    end

    -- 既存のエンベロープをクリア
    EnvelopeUtils.clear_envelope(envelope)

    -- CSVファイルを読み込む
    local csv_file = io.open(csv_file_path, "r")
    if not csv_file then
        reaper.ShowMessageBox(csv_file_path .. " が開けません。", "エラー", 0)
        return
    end

    -- CSVのデータを読み込み、キーフレームに沿って値を適用
    local csv_points = {}
    for line in csv_file:lines() do
        local time, x, y, z, azimuth, elevation, distance = line:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
        time = tonumber(time)
        azimuth = tonumber(azimuth)
        elevation = tonumber(elevation)
        distance = tonumber(distance)
        if time and azimuth and elevation and distance then
            table.insert(csv_points, {time = time, azimuth = azimuth, elevation = elevation, distance = distance})
        end
    end
    csv_file:close()

    -- CSVデータをエンベロープに挿入
    EnvelopeUtils.insert_points_from_csv(envelope, csv_points, envFunc)

    -- 既存のポイントを取得
    local points = EnvelopeUtils.get_envelope_points(envelope)

    -- 差分チェックとポイントの追加
    EnvelopeUtils.add_discrete_points(envelope, points)
end

function convert_bar_step_to_time(bar, step)
    return ((bar - 1.0)* 4.0 + step / 4.0) * 60.0 / 120.0
end

function process_score_file(objectName)
    local scoredir = csvdir .. "Score"
    local score_file_path = scoredir .. "\\" .. objectName .. "_Score.csv"
    
    -- スコアファイルを読み込む
    local score_file = io.open(score_file_path, "r")
    if not score_file then
        reaper.ShowMessageBox(score_file_path .. " が開けません。", "エラー", 0)
        return
    end

    -- 1行目をヘッダーとして読み飛ばす
    score_file:read("*l")

    -- スコアデータを格納する2次元リストを初期化
    local score_data = {}
    local max_obj_num = 1
    for line in score_file:lines() do
        local bar, step, clipSuffix, objNum, vol, vol3D = line:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]*)")
        if bar and step and clipSuffix and objNum then
            objNum = tonumber(objNum)
            table.insert(score_data, {bar, step, clipSuffix, objNum, vol})
            if objNum and objNum > max_obj_num then
                max_obj_num = objNum
            end
        end
    end
    score_file:close()

    return max_obj_num, score_data
end

-- メイン関数
function import_envelopes_from_csv()
    -- SourceInfo.csvのパスを取得
    local source_info_path = csvdir .. "SourceInfo.csv"
    -- SourceInfo.csvを読み込む
    local file = io.open(source_info_path, "r")
    if not file then
        reaper.ShowMessageBox("SourceInfo.csvが開けません。", "エラー", 0)
        return
    end

    -- 1行目をヘッダーとして読み飛ばす
    file:read("*l")

    for line in file:lines() do
        local objectName, trackType, envName, envFunc, loadScore, useScoreVal = line:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
        -- useScoreの値を設定
        useScore = tonumber(useScoreVal) ~= 0

        -- clipの文字列に"Score"が含まれているかをチェック
        local score_data = {}
        local volume = 0.0
        if useScore then
            sourceNum, score_data = process_score_file(objectName)
        else
            sourceNum = 1
        end

        -- sourceNum回ループを先に回す
        for num = 1, sourceNum do
            local current_objectName = objectName
            if useScore then
                current_objectName = objectName .. num
            end

            -- テンプレートトラックをコピーする必要があるかチェック
            copy_template_if_needed(current_objectName, trackType)
        end

        -- スコアデータの各行を読み込んで処理するループ
        if useScore and tonumber(loadScore) == 1 then
            for _, row in ipairs(score_data) do
                local bar = tonumber(row[1])
                local step = tonumber(row[2])
                local clipSuffix = row[3]
                local objNum = tonumber(row[4])
                local volume = tonumber(row[5])

                local start_time =  convert_bar_step_to_time(bar, step)
                local file_path = clipdir .. objectName .. "\\" .. objectName .. "_" .. clipSuffix .. ".wav"
                reaper.ShowConsoleMsg(file_path)

                local track_name = trackType .. "_" .. objectName .. objNum
                local track = EnvelopeUtils.get_track_by_name(track_name)
                if track then
                    place_audio_file(track, start_time, file_path, volume)
                else
                    reaper.ShowMessageBox("トラック " .. track_name .. " が見つかりません。", "エラー", 0)
                end
            end
        end

        -- 各トラックに対して処理を行うループ
        for num = 1, sourceNum do
            local current_objectName = objectName
            if useScore then
                current_objectName = objectName .. num
            end

            if current_objectName and trackType and envName and envFunc then
                process_sourcepos_csv_line(current_objectName, trackType, envName, envFunc, loadScore)
            end
        end
    end

    file:close()
    reaper.UpdateTimeline()
end

-- スクリプトを実行
import_envelopes_from_csv()

