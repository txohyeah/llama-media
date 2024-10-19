-- llama land
TARGET_WORLD_PID = TARGET_WORLD_PID or "9a_YP6M7iN7b6QUoSvpoV3oe3CqxosyuJnraCucy5ss"

-- test world
-- TARGET_WORLD_PID = TARGET_WORLD_PID or "otsJFxhaG-HA0H1NEbIziyha8rNAdS8SxbGbGpni2rk"

LlamaMediaProcessId = LlamaMediaProcessId or "taXo_TeXsRKwNr6WDS3qV63fNu6HKGr919MSV5-F9c4"

TokenProcessId = TokenProcessId or "pazXumQI-HPH7iFGfTC-4_7biSnqz_U67oFAGry5zUY"
-- llama denomination: 12
TokenDenomination = TokenDenomination or 12
OneCoin = math.floor(10 ^ TokenDenomination)

-- npc variable
NpcDisplayName = NpcDisplayName or "Llama Media Worker"
SchemaTitle = SchemaTitle or "Sponsored by someone"
SchemaContent = SchemaContent or ""

TokenName = TokenName or "Llama" 
SponsorName = SponsorName or "someone"
MaxClaim = MaxClaim or 10
MinClaim = MinClaim or 1
Quantity = Quantity or 0
ClaimQuantity = ClaimQuantity or 0
WorkStatus = WorkStatus or "idle"
WorkRound = WorkRound or 0

Position = Position or { 0, 0 }
PositionRandomX1 = PositionRandomX1 or -2
PositionRandomX2 = PositionRandomX2 or 2
PositionRandomY1 = PositionRandomY1 or -2
PositionRandomY2 = PositionRandomY2 or 2

-- npc variable end

local json = require("json")
local sqlite3 = require("lsqlite3")
local dbAdmin = require("DbAdmin")
if DbAdmin == nil then
  local db = sqlite3.open_memory()
  DbAdmin = dbAdmin.new(db)
end


function InitDb()
    DbAdmin:execSql([[
        CREATE TABLE IF NOT EXISTS claim_record (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            work_round INTEGER,
            claim_address TEXT,
            claim_quantity INTEGER,
            vouch_point FLOAT,
            created_at INTEGER
        );
    ]])
end

-- vouch function
VOUCH_PROCESS = "ZTTO02BL2P-lseTLUgiIPD9d0CF1sc4LbMA2AQ7e9jo"
VOUCHER_WHITELIST = {
  ["Ax_uXyLQBPZSQ15movzv9-O1mDo30khslqN64qD27Z8"] = true,
  ["k6p1MtqYhQQOuTSfN8gH7sQ78zlHavt8dCDL88btn9s"] = true,
  ["QeXDjjxcui7W2xU08zOlnFwBlbiID4sACpi0tSS3VgY"] = true,
  ["3y0YE11i21hpP8UY0Z1AVhtPoJD4V_AbEBx-g0j9wRc"] = true,
}
-- vouch function end

function GetVouchScoreUsd(walletId)
    ao.send({
      Target = VOUCH_PROCESS,
      Tags = {
        Action = "Get-Vouches",
        ID = walletId,
      }
    })
  
    local resp = Handlers.receive({
      From = VOUCH_PROCESS,
      Action = "VouchDAO.Vouches",
    })
  
    local data = json.decode(resp.Data)
    if type(data) ~= 'table' or data['Vouchers'] == nil then
      return 0
    end
  
    local vouches = data['Vouchers']
    local score = 0
  
    for voucher, vouch in pairs(vouches) do
      if VOUCHER_WHITELIST[voucher] then
        -- 1.34-USD -> 1.34
        local valueStr = string.match(vouch.Value, "([%d%.]+)-USD")
        if valueStr ~= nil then
          score = score + tonumber(valueStr)
        end
      end
    end
  
    return score
end

function ChatToWorld(data)
    ao.send({
      Target = TARGET_WORLD_PID,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = "Llama Media Worker",
      },
      Data = data
    })
end

function Register()
    ao.send({
      Target = TARGET_WORLD_PID,
      Tags = {
        Action = "Reality.EntityCreate",
      },
      Data = json.encode({
        Type = "Avatar",
        Position = Position,
        Metadata = {
          DisplayName = NpcDisplayName,
          SkinNumber = 8,
          Interaction = {
              Type = 'SchemaForm',
              Id = 'Claim'
          },
        },
      }),
    })
end


function Move()
    print("Move")
    -- llama land location
    -- local x = math.random(-3, 3)
    -- local y = math.random(12, 15)
  
    -- test world location
    local x = math.random(PositionRandomX1, PositionRandomX2)
    local y = math.random(PositionRandomY1, PositionRandomY2)
    
    ao.send({
      Target = TARGET_WORLD_PID,
      Tags = {
        Action = "Reality.EntityUpdatePosition",
      },
      Data = json.encode({
        Position = {
          x,
          y,
        },
      }),
    })
end

function Hide()
    ao.send({
        Target = TARGET_WORLD_PID,
        Tags = {
          Action = 'Reality.EntityHide',
          EntityId = ao.id
        },
      })
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


function ClaimSchemaTags()
    return [[
    {
        "type": "object",
        "required": [
            "Action"
        ],
        "properties": {
            "Action": {
                "type": "string",
                "const": "Claim"
            }
        }
    }
    ]]
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



function HasClaimed(walletId)
    local sql = string.format([[
            SELECT * FROM claim_record WHERE claim_address = '%s'
    ]], walletId)
    local results = DbAdmin:execQuery(sql)
    return results ~= nil and #results > 0
end



Handlers.add(
  "Start-Work",
  function (msg)
    if msg.From == TokenProcessId and msg.Tags.Action == "Credit-Notice" and msg.Tags.Sender == LlamaMediaProcessId then
        print("WorkStatus: " .. WorkStatus)
        if WorkStatus == "idle" then
            print("Npc worker is idle. start work.")
            return true
        else
            print("Npc worker is already working.")
            return false
        end
    else
        return false
    end
  end,
  function(msg)
    -- 更新本次赞助活动的变量
    TokenName = msg.Tags["X-TokenName"]
    SponsorName = msg.Tags["X-Sponsor-Name"]
    SchemaContent = msg.Tags["X-Content"]
    MaxClaim = msg.Tags["X-Max-Claim"] / OneCoin
    MinClaim = msg.Tags["X-Min-Claim"] / OneCoin
    Quantity = msg.Tags.Quantity
    ClaimQuantity = 0
    WorkStatus = "working"
    WorkRound = WorkRound + 1

    if SponsorName == nil or SponsorName == "" then
        SponsorName = "someone"
    end

    local quantityStr =  tostring(math.floor(Quantity / OneCoin))
    NpcDisplayName = "Claim to share " .. quantityStr .. " " .. TokenName

    -- 注册 npc worker
    Register()

    ChatToWorld("I'm ready to start working. You can claim to share " .. quantityStr .. " " .. TokenName .. " now.")
    Move()
  end
)


Handlers.add(
  'Schema',
  Handlers.utils.hasMatchingTag('Action', 'Schema'),
  function(msg)
    if WorkStatus == "idle" then
        print("I am out of working.")
        ao.send({
            Target = msg.From,
            Tags = { Type = 'Schema' },
            Data = json.encode({
              Claim = {
                Title = "I am out of working now.",
                Description = "You can claim when I am working. And claim only for vouched citizens.",
                Schema = nil,
              },
            })
        })
        return
    end

    ao.send({
        Target = msg.From,
        Tags = { Type = 'Schema' },
        Data = json.encode({
          Claim = {
            Title = "Sponsored by " .. SponsorName,
            Description = SchemaContent .. " Claim only for vouched citizens.",
            Schema = {
              Tags = json.decode(ClaimSchemaTags()),
            },
          },
        })
    })
  end
)

Handlers.add(
    "claim",
    function(msg)
        -- msg 的 msg.From 是 media worker 的地址 并且 Action 是 Claim
        if msg.Tags["Action"] == "Claim" then
            return true
        else
            return false
        end
    end,
    function(msg)

        if WorkStatus == "idle" then
            print("I am out of working.")
            return
        end

        -- 检查当前用户是否已经 claim
        if HasClaimed(msg.From) then
            local chatMsg = formatPid(msg.From) .. ", You have claimed already."
            print(msg.From .. " duplicate claim.")
            ChatToWorld(chatMsg)
            return
        end

        -- 检查用户是否满足 vouch point
        local vouchScore = GetVouchScoreUsd(msg.From)
        if vouchScore < 2 then
            local chatMsg = formatPid(msg.From) .. " don't have enough vouch point to claim. Please visit https://vouch-portal.arweave.net/ to improve your score."
            print(chatMsg)
            ChatToWorld(chatMsg)
            return
        end

        print("vouchScore: " .. vouchScore)

        -- 创建 claim 记录
        local randomNumber = math.random(MinClaim, MaxClaim)
        local claimNumber = math.floor(randomNumber) * OneCoin

        local leftQuantity = Quantity - ClaimQuantity
        if leftQuantity < claimNumber then
            claimNumber = leftQuantity
        end

        local sql = string.format([[
            INSERT INTO claim_record (
            work_round, 
            claim_address, 
            claim_quantity, 
            vouch_point, 
            created_at) VALUES (%d, '%s', %d, %f, %d)
        ]], 
        WorkRound, 
        msg.From, 
        math.floor(claimNumber), 
        vouchScore, 
        msg.Timestamp)

        DbAdmin:execSql(sql)

        -- 更新 ClaimQuantity
        ClaimQuantity = math.floor(ClaimQuantity + claimNumber)

        print("ClaimQuantity: " .. ClaimQuantity / OneCoin)

        -- 发送 token 到 claim 地址
        if claimNumber > 0 then
            local message = {
                Target = TokenProcessId,
                Tags = {
                    Action = "Transfer",
                    Quantity = tostring(math.floor(claimNumber)),
                    Recipient = msg.From,
                }
            }
            print(message)
            ao.send(message)

            -- 发送 claim 成功消息
            local chatMsg = formatPid(msg.From) .. ", You have claimed " .. tostring(math.floor(claimNumber / OneCoin)) .. " " .. TokenName .. " coins which sponsored by " .. SponsorName .. "."
            print(msg.From .. " claim successfully.")
            ChatToWorld(chatMsg)
        else
            -- 没有多余的币了，只能干看广告
            local chatMsg = formatPid(msg.From) .. ", all coins have been claimed. Please wait for the next sponsor."
            print(msg.From .. ", all coins have been claimed.")
            ChatToWorld(chatMsg)
        end
 
    end
)

Handlers.add(
  "Stop-Work",
  function(msg)
    if msg.From == LlamaMediaProcessId and msg.Tags.Action == "Stop-Work" then
        return true
    else
        return false
    end
  end,
  function(msg)
    ChatToWorld("This activity which sponsored by " .. SponsorName .. " is over. I will be back next time.")

    DbAdmin:execSql("DELETE FROM claim_record")

    -- 如果有余额，则返回给赞助者
    local leftQuantity = Quantity - ClaimQuantity
    if leftQuantity > 0 then
        ao.send({
            Target = TokenProcessId,
            Tags = {
                Action = "Transfer",
                Quantity = tostring(math.floor(leftQuantity)),
                Recipient = msg.Tags.Sponsor,
            }
        })
    end

    -- 更新本次赞助活动的变量
    WorkStatus = "idle"
    ClaimQuantity = 0
    NpcDisplayName = "Llama Media Worker"
    Register()
  end
)


Handlers.add(
  "CronTick",
  function(msg)
    if msg.Tags["Action"] == "Cron" then
        return true
    else
        return false
    end
  end,
  function(msg)
    -- 打印时间（时间戳转化为时间）
    print("CronTick: " .. TimestampToDateTime(msg.Timestamp))

    if WorkStatus ~= "idle" then
        Move()
    else
        print("Hide")
        Hide()
    end
  end
)