# Enter your code here. Read input from STDIN. Print output to STDOUT

def findTreeHeight(num_cycles):
    tree_height = 1
    for cycle in range(1,(num_cycles + 1)):
        if (cycle == 1) or (cycle % 2 != 0):
            tree_height *= 2
        else:
            tree_height += 1
    return tree_height

test_cases = int(input())
result_list = []
if test_cases == 0:
    print "Please enter a number greater than 0"
else:
    for test in range(test_cases):
        num_cycles = int(input())
        result_list.append(findTreeHeight(num_cycles))

for result in result_list:
    print result