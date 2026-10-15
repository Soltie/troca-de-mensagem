--!strict
--[[
	Utilitários puros de tabela (sem APIs do Roblox; testáveis no Lune).
]]

local TableUtil = {}

-- Cópia profunda. Não copia metatables; referências cíclicas não são suportadas.
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[key] = TableUtil.deepCopy(item)
	end
	return copy :: any
end

-- Retorna uma cópia de `target` com as chaves ausentes preenchidas a partir de `template`
-- (recursivo). Valores existentes em `target` são preservados, mesmo que o tipo difira.
function TableUtil.reconcile<T>(target: any, template: T): T
	if type(target) ~= "table" then
		return TableUtil.deepCopy(template)
	end
	local result = TableUtil.deepCopy(target)
	for key, templateValue in template :: any do
		local current = result[key]
		if current == nil then
			result[key] = TableUtil.deepCopy(templateValue)
		elseif type(templateValue) == "table" and type(current) == "table" then
			result[key] = TableUtil.reconcile(current, templateValue)
		end
	end
	return result
end

-- Congela a tabela e todas as subtabelas (table.freeze é raso por padrão).
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, item in value :: any do
			TableUtil.deepFreeze(item)
		end
		table.freeze(value :: any)
	end
	return value
end

-- Igualdade estrutural (usada pelos testes).
function TableUtil.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not TableUtil.deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

return TableUtil
