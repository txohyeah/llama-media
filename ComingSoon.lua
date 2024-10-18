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

TIMESTAMP_LAST_MESSAGE_MS = TIMESTAMP_LAST_MESSAGE_MS or 0

-- Limit sending a message to every so often
COOLDOWN_MS = 10000 -- 10 seconds

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
            Position = { 5, -5 },
            Metadata = {
                DisplayName = "Llama Media",
                SkinNumber = 1,
                Interaction = {
                    Type = 'Default'
                },
            }
        })
    })
end

Register()



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
  'DefaultInteraction',
  Handlers.utils.hasMatchingTag('Action', 'DefaultInteraction'),
  function(msg)
    if ((msg.Timestamp - TIMESTAMP_LAST_MESSAGE_MS) < COOLDOWN_MS) then
        return print("Message on cooldown")
    end

    ChatToWorld("Llama Media is coming soon. Llama Media will help promote your business to people who come to Llama Land.")
  end
)



Handlers.add(
  "CronTick",
  Handlers.utils.hasMatchingTag("Action", "Cron"),
  function(msg)
    print("CronTick: " .. TimestampToDateTime(msg.Timestamp))
    -- chat with user
    if msg.Timestamp > NEXT_ROUND_TIME + CALM_DOWN_TIME then
        print("Next round time: " .. NEXT_ROUND_TIME)
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
        },
    })
  end
)