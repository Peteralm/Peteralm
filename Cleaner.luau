--!strict

local function destroy(item: any)
	local t = typeof(item)
	if t == "Instance" then
		item:Destroy()
	elseif t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "thread" then
		task.cancel(item)
	elseif t == "Tween" then
		item:Cancel()
	elseif t == "table" then
		if typeof(item.Disconnect) == "function" then
			item:Disconnect()
		elseif typeof(item.clean) == "function" then
			item:clean()
		else
			table.clear(item)
		end
	end
end

local Cleaner = {}
Cleaner.__index = Cleaner

export type Cleaner = typeof(setmetatable(
	{} :: {
		_items: { any },
		_groups: { [string]: any },
	},
	Cleaner
))

function Cleaner.new(): Cleaner
	return setmetatable({ _items = {}, _groups = {} }, Cleaner)
end

--[[
	Tracks items for cleanup. Accepts connections, tweens, threads, instances, and tables.
	Functions are spawned immediately as tracked tasks — use this instead of nesting task.delay:

	cleaner:add(function()
		task.wait(0.5)
		tween:Play()
		task.wait(0.3)
		tween2:Play()
	end)

	Returns all passed values so you can chain:
	cleaner:add(TweenService:Create(...)):Play()
]]
function Cleaner.add(self: Cleaner, ...: any): ...any
	for _, item in { ... } do
		if typeof(item) == "function" then
			table.insert(self._items, task.spawn(item))
		else
			table.insert(self._items, item)
		end
	end
	return ...
end

--[[
	Creates a scoped sub-cleaner. Named groups can be partially cleaned:

	local anim = cleaner:group("anim")
	anim:add(tween1, tween2)
	cleaner:clean("anim") -- only cleans anim group
	cleaner:clean()       -- cleans everything
]]
function Cleaner.group(self: Cleaner, name: string?): Cleaner
	local sub = Cleaner.new()
	if name then
		self._groups[name] = sub
	else
		table.insert(self._items, sub)
	end
	return sub
end

--[[
	Cleans all tracked items and groups, or only specific named groups:

	cleaner:clean()           -- cleans everything
	cleaner:clean("anim")     -- cleans only "anim" group
	cleaner:clean("a", "b")   -- cleans "a" and "b" groups
]]
function Cleaner.clean(self: Cleaner, ...: string)
	if select("#", ...) > 0 then
		for _, name in { ... } do
			local group = self._groups[name]
			if group then
				pcall(destroy, group)
				self._groups[name] = nil
			end
		end
		return
	end

	for _, item in self._items do
		pcall(destroy, item)
	end
	table.clear(self._items)

	for _, group in self._groups do
		pcall(destroy, group)
	end
	table.clear(self._groups)
end

return Cleaner :: {
	new: () -> Cleaner,
}
