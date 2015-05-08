num_tests = int(input())

for x in range(num_tests):
	num_stones = int(input())
	ab = int(input()), int(input())
	if ab[0] == ab[1]:
		vals = set([ab[0] * (num_stones - 1)])
	else:
		a, b = min(ab), max(ab)

		stonegen = [(num_stones - i - 1) * a + i * b for i in range(num_stones)]
		vals = sorted(set(stonegen))

	print ' '.join([str(item) for item in vals])