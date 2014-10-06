local hamming = {}

function hamming.compute(base_str, compare_str)
	hamming_counter = 0
	for i = 1, base_str:len() do
		base_letter = base_str:sub(i, i)
		compare_letter = compare_str:sub(i, i)

		if base_letter~="" and compare_letter~="" then
			if base_letter ~= compare_letter then
				hamming_counter = hamming_counter + 1
			end
		end
	end

	return hamming_counter
end

return hamming