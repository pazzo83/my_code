num_rocks = int(input())

gem_list = []

for x in range(num_rocks):
	new_str = raw_input()
	if x == 0:
		#we're on the first one
		gem_list = list(new_str)
	else:
		gem_list = list(set(list(new_str)).intersection(gem_list))

print len(gem_list)