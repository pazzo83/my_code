from collections import deque, Counter

def palindrome_from(letters):
	counter = Counter(letters)
	#print counter
	sides_of_pal = []
	center_of_pal = deque()
	for letter, occurrences in counter.items():
		repetitions, remainder_if_odd = divmod(occurrences, 2)
		if not remainder_if_odd:
			sides_of_pal.append(letter * repetitions)
		else:
			if center_of_pal:
				return False
			center_of_pal.append(letter * occurrences)
	#center_of_pal.extendleft(sides_of_pal)
	#center_of_pal.extend(sides_of_pal)
	return True

input_str = str(raw_input())

print palindrome_from(input_str)