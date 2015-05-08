num_cuts = int(input())

list_input = raw_input()

stick_list = map(int, list_input.split(' '))

cuts = []

for i in range(num_cuts):
	if not stick_list:
		break
	smallest_value = min(stick_list)
	cuts.append(len(stick_list))
	#do cuts
	new_list = [(x - smallest_value) for x in stick_list]
	# remove zeros
	stick_list = [y for y in new_list if y > 0]

for cut in cuts:
	print cut