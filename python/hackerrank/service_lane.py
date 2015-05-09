__author__ = 'christopheralexander_nmp'

freeway_inp = input()

freeway_len, num_tests = [int(x) for x  in freeway_inp.split(' ')]

freeway_segs = input()

freeway_segs_list = [int(x) for x in freeway_segs.split()]

max_allowed_list = []
def get_max_allowed(inputs):
    enter, exit = inputs
    freeway_range = freeway_segs_list[enter:exit+1]
    max_allowed = min(freeway_range)

    return max_allowed

for i in range(num_tests):
    test_input = input()
    enter_exit = [int(x) for x in test_input.split(' ')]
    max_allowed = get_max_allowed(enter_exit)
    max_allowed_list.append(max_allowed)

for max_allwd in max_allowed_list:
    print(max_allwd)