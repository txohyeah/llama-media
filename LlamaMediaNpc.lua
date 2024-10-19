-- llama land
TARGET_WORLD_PID = TARGET_WORLD_PID or "9a_YP6M7iN7b6QUoSvpoV3oe3CqxosyuJnraCucy5ss"

-- test world
-- TARGET_WORLD_PID = TARGET_WORLD_PID or "otsJFxhaG-HA0H1NEbIziyha8rNAdS8SxbGbGpni2rk"

LlamaMediaProcessId = LlamaMediaProcessId or "taXo_TeXsRKwNr6WDS3qV63fNu6HKGr919MSV5-F9c4"

LlamaCoinProcessId = LlamaCoinProcessId or "pazXumQI-HPH7iFGfTC-4_7biSnqz_U67oFAGry5zUY"
LlamaCoinDenomination = 12
OneLlamaCoin = 10 ^ LlamaCoinDenomination


-- CONSTANTS for chat
-- 8 hours
CALM_DOWN_TIME = 1000 * 60 * 60 * 2
NEXT_ROUND_TIME = NEXT_ROUND_TIME or 0
QUOTES = {
    "The future of media is here. We are the best media in the world.",
    "Welcome to Llama Media, where we advertise for your business.",
    "For Llama Media, I have a grand vision, even though I don't have an office yet.",
    "Please feel free to let me know if you have any suggestions about then Llama Media.",
    "Work hard, play hard, and make money.",
    "When I make money, I want to build a building for Llama Media to use as an office."
}



local json = require("json")

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


function Register()
    ao.send({
        Target = TARGET_WORLD_PID,
        Tags = {
            Action = 'Reality.EntityCreate',
        },
        Data = json.encode({
            Type = "Avatar",
            -- Position = { 42, 47 },
            Position = { 5, -5 },
            Metadata = {
                DisplayName = "Llama Media",
                SkinNumber = 1,
                Interaction = {
                    Type = 'SchemaExternalForm',
                    Id = 'Sponsor'
                },
            }
        })
    })
end

Register()


function SponsorLlamaCoinsSchemaTags()
    return [[
        {
            "type": "object",
            "required": [
                "Action",
                "Recipient",
                "Quantity",
                "X-Period",
                "X-Content",
                "X-Min-Claim",
                "X-Max-Claim",
                "X-Transfer-Purpose"
            ],
            "properties": {
                "Action": {
                    "type": "string",
                    "const": "Transfer"
                },
                "Recipient": {
                    "type": "string",
                    "const": "]] .. LlamaMediaProcessId .. [["
                },
                "Quantity": {
                    "type": "number",
                    "minimum": 10,
                    "maximum": 2000,
                    "$comment": "]] .. OneLlamaCoin .. [[",
                    "title": "Llama coins to sponsor"
                },
                "X-Period": {
                    "type": "number",
                    "minimum": 1,
                    "maximum": 7,
                    "title": "Advertising period(day)"
                },
                "X-Content": {
                    "type": "string",
                    "title": "Advertisement content",
                    "maxLength": 5000
                },
                "X-Min-Claim": {
                    "type": "number",
                    "minimum": 1,
                    "maximum": 100,
                    "$comment": "]] .. OneLlamaCoin .. [[",
                    "title": "Minimum amount for claim"
                },
                "X-Max-Claim": {
                    "type": "number",
                    "minimum": 1,
                    "maximum": 100,
                    "$comment": "]] .. OneLlamaCoin .. [[",
                    "title": "Maximum amount for claim"
                },
                "X-Sponsor-Name": {
                    "type": "string",
                    "title": "Sponsor name",
                    "maxLength": 50
                },
                "X-Transfer-Purpose":  {
                    "type": "string",
                    "const": "Sponsor"
                }
            }
        }
    ]]
end 



function ChatToWorld(data)
    ao.send({
        Target = TARGET_WORLD_PID,
        Tags = {
            Action = 'ChatMessage',
            ['Author-Name'] = 'Llama Media',
        },
        Data = data
    })
end


Handlers.add(
  'SchemaExternal',
  Handlers.utils.hasMatchingTag('Action', 'SchemaExternal'),
  function(msg)
    local dataStr = [[
  {
    "Sponsor": {
        "Target": "]] .. LlamaCoinProcessId .. [[",
        "Title": "Make an advertisement?",
        "Description": "Welcome to Llama Media. You can place advertisements here to promote your brand activities. We will charge 10 Llama Coins per day as a handling fee.",
        "Schema": {
            "Tags": ]] .. SponsorLlamaCoinsSchemaTags() .. [[
        }
    }
  }
    ]]

    ao.send({
        Target = msg.From,
        Tags = { Type = 'SchemaExternal' },
        Data = dataStr
    })

    -- ao.send({
    --     Target = msg.From,
    --     Tags = { Type = 'SchemaExternal' },
    --     Data = json.encode({
    --         Sponsor = {
    --             Target = LlamaCoinProcessId,
    --             Title = "Make an advertisement?",
    --             Description = [[
    --             Welcome to Llama Media. You can place advertisements here to promote your brand activities. We will charge 10 Llama Coins per day as a handling fee. 
    --             ]],
    --             Schema = {
    --                 Tags = SponsorLlamaCoinsSchemaTags(),
    --             --   Tags = json.decode(SponsorLlamaCoinsSchemaTags()),
    --             },
    --         },
    --     })
    -- })
  end
)

Handlers.add(
    "Chat",
    function(msg)
        if msg.From == LlamaMediaProcessId and msg.Tags.Action == "Chat" then
            return true
        end
        return false
    end,
    function(msg)
        ChatToWorld(msg.Data)
    end
)


Handlers.add(
  "CronTick",
  Handlers.utils.hasMatchingTag("Action", "Cron"),
  function(msg)
    print("CronTick: " .. TimestampToDateTime(msg.Timestamp))
    -- chat with user
    if msg.Timestamp > NEXT_ROUND_TIME + CALM_DOWN_TIME then
        local randomEnough = msg.Timestamp % #QUOTES + 1
        local quote = QUOTES[randomEnough]

        ChatToWorld(quote)
        NEXT_ROUND_TIME = msg.Timestamp
    end

    -- fix position
    Send({
        Target = TARGET_WORLD_PID,
        Tags = {
            Action = 'Reality.EntityFix',
            EntityId = ao.id
        },
    })
  end
)