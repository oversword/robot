local api = robot.internal_api
-- local S = api.translator

function api.set_connected(nodeinfo, connected)
	local meta = nodeinfo.meta()
	local current = meta:get_int('connected')
	local new_val = connected and 1 or 0
	if new_val ~= current then
		meta:set_int('connected', new_val)
		api.update_formspec(nodeinfo)
	end
end
function api.is_connected(nodeinfo)
	local meta = nodeinfo.meta()
	local current = meta:get_int('connected')
	return current == 1
end
function api.is_connective(nodeinfo, to_part)
	local info = nodeinfo.info()
	if not info.part then return end
	local connects_above = api.part(info.part).connects_above
	if not connects_above then return end
	if not api.has_ability(nodeinfo, 'connectivity') then return end
	if not to_part then return true end
	return connects_above[to_part]
end
function api.is_above_connective(nodeinfo)
	local pos = nodeinfo.pos()
	local uppos = vector.add(pos, {x=0,y=1,z=0})
	local upinfo = api.nodeinfo(uppos)
	if nodeinfo.node().param2 ~= upinfo.node().param2 then return end
	local info = upinfo.info()
	if not info.part or not api.is_connective(nodeinfo, info.part) then return end
	return upinfo
end
function api.is_below_connective(nodeinfo)
	local pos = nodeinfo.pos()
	local downpos = vector.subtract(pos, {x=0,y=1,z=0})
	local downinfo = api.nodeinfo(downpos)
	if nodeinfo.node().param2 ~= downinfo.node().param2 then return end
	local info = nodeinfo.info()
	if not info.part or not api.is_connective(downinfo, info.part) then return end
	return downinfo
end
function api.correct_connection(nodeinfo)
	if api.is_connective(nodeinfo) then
		if api.is_connected(nodeinfo) then
			if not api.is_above_connective(nodeinfo) then
				api.set_connected(nodeinfo, false)
			end
		else
			if api.is_above_connective(nodeinfo) then
				api.set_connected(nodeinfo, true)
			end
		end
	end
end