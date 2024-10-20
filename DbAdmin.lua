local dbAdmin = {}
dbAdmin.__index = dbAdmin

-- Function to create a new database explorer instance
function dbAdmin.new(db)
    local self = setmetatable({}, dbAdmin)
    self.db = db
    return self
end

-- Function to list all tables in the database
function dbAdmin:tables()
    local tables = {}
    for row in self.db:nrows("SELECT name FROM sqlite_master WHERE type='table';") do
        table.insert(tables, row.name)
    end
    return tables
end

-- Function to get the record count of a table
function dbAdmin:count(count_query)
    for row in self.db:nrows(count_query) do
        return row.count
    end
end

-- Function to execute a given SQL query
function dbAdmin:execQuery(sql)
    local results = {}
    for row in self.db:nrows(sql) do
        table.insert(results, row)
    end
    return results
end

function dbAdmin:execQueryOne(sql)
    local stmt = self.db:prepare(sql)
    stmt:step()
    local value = stmt:get_value(0)
    stmt:finalize()
    return value
end

function dbAdmin:execSql(sql)
    self.db:exec(sql)
end


-- 执行SQL语句的方法，支持参数化查询
function dbAdmin:insert(sql, params)
    -- 检查参数是否为空
    if params == nil then
        params = {}
    end

    -- 准备SQL语句
    local cursor, err = self.conn:prepare(sql)
    if not cursor then
        return false, "Failed to prepare SQL statement: " .. tostring(err)
    end

    -- 绑定参数
    for i, param in ipairs(params) do
        cursor:bind(i, param)
    end

    -- 执行SQL语句
    local res, err = cursor:execute()
    if not res then
        return false, "Failed to execute SQL statement: " .. tostring(err)
    end

    -- 关闭游标
    cursor:close()

    return true, nil
end

return dbAdmin