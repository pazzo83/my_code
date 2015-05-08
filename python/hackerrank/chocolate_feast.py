T = int(raw_input())
for i in range (0,T):
	A,B,C1 = [int(x) for x in raw_input().split(' ')]

	initial_num_choc = A/B

	#calc from wrappers
	addl_choc = initial_num_choc/C1
	even_more_choc = 0
	if addl_choc + (initial_num_choc % C1) >= C1:
		even_more_choc = (addl_choc + (initial_num_choc % C1)) / C1
		choc_ctr = even_more_choc
		while ((choc_ctr + (choc_ctr % C1)) / C1) > 0 and choc_ctr > 1:
			choc_ctr = (choc_ctr + (choc_ctr % C1)) / C1
			even_more_choc += choc_ctr

	answer = initial_num_choc + addl_choc + even_more_choc
	# write code to compute answer
	print answer