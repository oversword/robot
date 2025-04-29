local api = robot.internal_api

api.translator = core.get_translator(api.modname)
local S = api.translator

api.translations = {
	cant = S("Can't"),
	onlyone = S("can only perform one action at a time"),
	noability = S("robot does not have this ability")
}