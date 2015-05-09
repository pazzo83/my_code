__author__ = 'christopheralexander_nmp'

def find_digits(num_list, full_num):
    matches = []
    for x in num_list:
        if x is not 0:
            if full_num % x == 0:
                matches.append(x)
    return matches

num_tests = int(input())

for x in range(num_tests):
    str_num = input()
    my_num = map(int, str_num)

    matches = find_digits(my_num, int(str_num))
    print(len(matches))

