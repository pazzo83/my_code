test_cases = int(input())
assert 1 <= test_cases <= 10

for i in range(test_cases):
	my_word = str(raw_input())
	assert len(my_word) <= 10**4
	steps = 0
	if my_word == my_word[::-1]:
		print steps
		continue
	else:
		f_index = 0
		e_index = len(my_word) -1
		while f_index != e_index:
			if my_word[f_index] == my_word[e_index]:
				f_index += 1
				e_index -= 1
			else:
				temp_list = list(my_word)
				if temp_list[f_index] > temp_list[e_index]:
					temp_list[f_index] = chr(ord(temp_list[f_index]) - 1)
				else:
					temp_list[e_index] = chr(ord(temp_list[e_index]) - 1)
				steps += 1
				my_word = ''.join(temp_list)
			if my_word == my_word[::-1]:
				print steps
				break