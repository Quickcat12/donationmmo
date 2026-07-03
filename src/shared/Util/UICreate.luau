--!strict
-- Small declarative helper for building UI trees from code, e.g.:
--   UICreate("Frame", { Size = UDim2.fromOffset(200, 50), BackgroundColor3 = c }, {
--       UICreate("TextLabel", { Text = "Hello" }),
--   })

local function UICreate(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)

	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if props and props.Parent then
		instance.Parent = props.Parent
	end

	return instance
end

return UICreate
