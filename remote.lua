local m = peripheral.find("modem")

if m == nil then
	exit()
end

local SEND_PORT = 69
local RECV_PORT = 71

m.open(SEND_PORT)
m.open(RECV_PORT)

local function listener()
	while true do
		local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
		if channel == SEND_PORT then
			local oldOut = term.current()
			local customTerm = {}
			for k, v in pairs(oldOut) do
				customTerm[k] = v
			end
			customTerm["write"] = function(text)
				m.transmit(replyChannel, channel, text)
			end
			term.redirect(customTerm)
			shell.run(message)
			term.redirect(oldOut)
		elseif channel == RECV_PORT then
			term.native().write(tostring(message))
		end
	end
end

local function input()
	local history = {}
	while true do
		write("$ ")
		local c = read(nil, history, shell.complete)
		table.insert(history, c)
		m.transmit(SEND_PORT, RECV_PORT, c)
	end
end

parallel.waitForAll(listener, input)
