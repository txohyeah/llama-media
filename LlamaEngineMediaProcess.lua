-- llama
TokenName = TokenName or "Llama"
-- llama: pazXumQI-HPH7iFGfTC-4_7biSnqz_U67oFAGry5zUY
TokenProcessId = TokenProcessId or "pazXumQI-HPH7iFGfTC-4_7biSnqz_U67oFAGry5zUY"
-- llama denomination: 12
TokenDenomination = TokenDenomination or 12
OneCoin = 10 ^ TokenDenomination
-- llama media npc: 
LlamaMediaNpc = LlamaMediaNpc or "vUfy5nhqxmYSE8foKQfJzymKKyfPGxsh96XV8DcR1W4"

FeePerDay = FeePerDay or 10

LlamaMediaWorker = LlamaMediaWorker or {
    ["Worker1"] = "KCOyOszXkRNg_A6uIl6QxRZ6cC5V_LQ245eJrwD6sXY",
    ["Worker2"] = "NoJborT2qSptd02e54FPuD20LjXgH7TpTyWENatfoNI",
}


local json = require("json")

local sqlite3 = require("lsqlite3")
local dbAdmin = require("DbAdmin")
if DbAdmin == nil then
  local db = sqlite3.open_memory()
  DbAdmin = dbAdmin.new(db)
end


function InitDb()
    DbAdmin:execSql([[
        CREATE TABLE IF NOT EXISTS sponsor_record (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sponsor_address TEXT,
            sponsor_name TEXT,
            media_worker_address TEXT,
            content TEXT,
            quantity INTEGER,
            period INTEGER,
            min_claim INTEGER,
            max_claim INTEGER,
            created_at INTEGER,
            ended_at INTEGER,
            end_flag INTEGER
        );
    ]])
end

-- local function


local function rejectToken(msg, reason)
    assert(msg.Sender ~= nil, "Missed Sender.")
    assert(msg.Quantity ~= nil and tonumber(msg.Quantity) > 0, "Missed Quantity.")
    local message = {
      Target = msg.From,
      Action = "Transfer",
      Recipient = msg.Sender,
      Quantity = msg.Quantity,
      Tags = {["X-Transfer-Purpose"] = reason }
    }
    ao.send(message)
end

local function formatPid(pid)
    -- 移除字符串两端的空白字符
    local pid = pid:match("^%s*(.-)%s*$")
    -- 取前三位
    local start = string.sub(pid, 1, 3)
    -- 取后三位
    local end_part = string.sub(pid, -3)
    -- 拼接
    local formatted_id = start .. "..." .. end_part
    return formatted_id
end

-- local function end

-- public function
function QueryFreeMediaWorker()
    local sql = "SELECT media_worker_address FROM sponsor_record WHERE end_flag = 0"
    local results = DbAdmin:execQuery(sql)
    -- 找到 LlamaMediaWorker 中的一个地址，并且不在 results 中的地址
    local freeWorker = nil
    for _, worker in pairs(LlamaMediaWorker) do
        freeWorker = worker
        for _, result in ipairs(results) do
            if worker == result.media_worker_address then
                freeWorker = nil
                break
            end
        end

        if freeWorker ~= nil then
            break
        end
    end
    return freeWorker
end

function QueryNextFreeMediaTime()
    local sql = "SELECT ended_at FROM sponsor_record WHERE end_flag = 0 ORDER BY ended_at ASC LIMIT 1"
    local results = DbAdmin:execQuery(sql)
    if results == nil or #results == 0 then
        return nil
    end
    return results[1].ended_at
end

function FormatTimeLeftHoursMinutes(timestamp, now)
    local timeLeft = math.floor((timestamp - now) / 1000)
    local hoursLeft = math.floor(timeLeft / 3600)
    local minutesLeft = math.floor((timeLeft - hoursLeft * 3600) / 60)
    return hoursLeft .. " hours " .. minutesLeft .. " minutes"
end

function MediaNpcChat(chatMsg)
    ao.send({
        Target = LlamaMediaNpc,
        Tags = {
            Action = "Chat",
        },
        Data = chatMsg
    })
end

-- 检查赞助费是否足够
function CheckSponsorFee(sponsorFee, quantity)
    if quantity < sponsorFee then
        return false
    end
    return true
end

function TimestampToDateTime(timestamp)
    -- 将毫秒时间戳转换为秒，并分离出毫秒部分
    local seconds = math.floor(timestamp / 1000)
    local milliseconds = timestamp % 1000

    -- 使用 os.date 将秒级时间戳转换为日期时间
    local datetime = os.date("*t", seconds)

    -- 格式化日期时间字符串
    return string.format("%04d-%02d-%02d %02d:%02d:%02d.%03d",
        datetime.year, datetime.month, datetime.day,
        datetime.hour + 8, datetime.min, datetime.sec, milliseconds)
end


-- public function end

Handlers.add(
    "sponsor",
    function(msg)
        if msg.From == TokenProcessId and msg.Tags.Action == "Credit-Notice" then
            return true
        else
            return false
        end
    end,
    function(msg)
        local period = tonumber(msg.Tags["X-Period"])
        local sponsorFee = math.floor(FeePerDay * period * OneCoin)
        local quantity = tonumber(msg.Tags["Quantity"])
        local claimQuantity = quantity - sponsorFee

        if not CheckSponsorFee(sponsorFee, quantity) then
            print("Not enough sponsor fee.")
            rejectToken(msg, "Not enough sponsor fee.")
            local chatMsg = {
                "At least " .. sponsorFee .. " " .. TokenName .." coins as sponsor fee. But you sent " 
                .. math.floor(quantity / OneCoin)
                .. ", it will be transfer back to " .. formatPid(msg.Tags["Sender"]) .. "."
            }
            MediaNpcChat(chatMsg)
            print("Chat to media npc: " .. chatMsg)
            return
        end

        -- 检查是否有空闲的媒体工作者
        local freeWorker = QueryFreeMediaWorker()

        if freeWorker == nil then
            rejectToken(msg, "No free media worker found.")
            print("No free media worker found.")
            local nextFreeTime = QueryNextFreeMediaTime()
            local timeLeft = FormatTimeLeftHoursMinutes(nextFreeTime, os.time())
            MediaNpcChat("No free media worker found. Token will be transfer back to " 
                    .. formatPid(msg.Tags["Sender"]) .. ". You can try again after " .. timeLeft .. ".")
            return
        end
        
        -- 创建赞助记录
        local created_at = msg.Timestamp
        local ended_at = created_at + period * 24 * 3600 * 1000
        local end_flag = 0
        local sponsor_content = string.gsub(msg.Tags["X-Content"], "'", " ")

        local sql = string.format([[
            INSERT INTO sponsor_record (
            sponsor_address, 
            sponsor_name, 
            media_worker_address, 
            content,
            quantity, 
            period, 
            min_claim, 
            max_claim, 
            created_at, 
            ended_at, 
            end_flag) VALUES ('%s', '%s', '%s', '%s', %d, %d, %d, %d, %d, %d, %d)
        ]], 
        msg.Tags['Sender'], 
        msg.Tags["X-Sponsor-Name"], 
        freeWorker, 
        sponsor_content,
        tonumber(msg.Quantity), 
        msg.Tags["X-Period"], 
        tonumber(msg.Tags["X-Min-Claim"]), 
        tonumber(msg.Tags["X-Max-Claim"]), 
        created_at, 
        ended_at, 
        end_flag)
        
        DbAdmin:execSql(sql)

        -- 激活 Media Worker, 并把赞助费给 Media Worker
        ao.send({
            Target = TokenProcessId,
            Tags = {
                Action = "Transfer",
                Recipient = freeWorker,
                ["X-TokenName"] = TokenName,
                ["X-Sponsor-Name"] = msg.Tags["X-Sponsor-Name"],
                ["X-Content"] = msg.Tags["X-Content"],
                ["X-Max-Claim"] = msg.Tags["X-Max-Claim"],
                ["X-Min-Claim"] = msg.Tags["X-Min-Claim"],
                ["Quantity"] = tostring(claimQuantity)
            }
        })

        ao.send({
            Target = TokenProcessId,
            Tags = {
                Action = "Transfer",
                Recipient = Owner,
                Quantity = tostring(sponsorFee)
            }
        })

        print("sponsor success.")
    end
)



Handlers.add(
    "endWork",
    function(msg)
        if msg.Tags["Action"] == "Cron" then
            return true
        else
            return false
        end
    end,
    function(msg)
        print("check end work: " .. TimestampToDateTime(msg.Timestamp))
        -- 检查所有未结束的赞助记录
        local sql = string.format([[
            SELECT * FROM sponsor_record WHERE end_flag = 0
        ]])
        local recordList = DbAdmin:execQuery(sql)
        for _, record in ipairs(recordList) do
            local ended_at = record.ended_at
            local now = os.time()
            if ended_at < now then
                -- 如果已经结束，更新 end_flag 为 1
                local sql = string.format([[
                    UPDATE sponsor_record SET end_flag = 1 WHERE id = %s
                ]], record.id)
                DbAdmin:execSql(sql)

                -- 关闭 Media Worker
                ao.send({
                    Target = record.media_worker_address,
                    Tags = {
                        Action = "Stop-Work",
                        Sponsor = record.sponsor_address,
                    }
                })
            end
        end
    end
)
